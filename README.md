# dbt Snowflake Analytics

dbt project on Snowflake with isolated dev/prod environments, pull-request
builds in throwaway schemas and a gated production deployment.

## Layout

```
data/order_details.json        Original semi-structured source (JSON array)
scripts/
  snowflake-setup.sql          One-time, idempotent Snowflake provisioning
src/dbt/
  profiles.yml                 Connection profile: env_var() lookups only
  seeds/                       Source data landed into RAW (all columns as text)
  models/staging|intermediate|mart  Model layers -> STAGING / INTERMEDIATE / MART
  tests/                       Singular data tests
  macros/                      Schema naming, PR schema cleanup, JSON load
.github/
  actions/setup-dbt/           Shared CI setup (Python, dbt, key file)
  workflows/ci.yml             PR + dev builds
  workflows/cd.yml             Production build
  workflows/cleanup-pr.yml     Drops PR schemas when a PR closes
```

### Source data

The CSV seeds are the original source files. The JSON is loaded natively by
Snowflake, without conversion: [`load_order_details`](src/dbt/macros/load_order_details.sql)
uploads `data/order_details.json` to an internal stage (`PUT`) and copies it
into `RAW.ORDER_DETAILS` as `VARIANT` (`COPY INTO`, one row per array element
via `STRIP_OUTER_ARRAY`), with `_file`, `_file_row` and `_loaded_at` metadata.
It is declared as a dbt source and is idempotent: `COPY` skips files it has
already loaded, so reruns never duplicate rows.

```sh
cd src/dbt
dbt run-operation load_order_details   # load the JSON (CI/CD do this before dbt build)
```

All seed columns are loaded as `VARCHAR` on purpose: the RAW layer keeps what
the source sent, and casting/validation is done in the models.

### Layers

| Schema | Contents |
|---|---|
| `RAW` | Seeds and the natively loaded JSON: source data exactly as received |
| `STAGING` | `stg_*` models: typed and standardized, 1:1 with the source |
| `INTERMEDIATE` | `int_*` models: business rules, deduplication, joins |
| `MART` | Final, consumer-facing tables |

## Environments

| | dev | prod |
|---|---|---|
| Database | `ANALYTICS_DEV` | `ANALYTICS_PROD` |
| Warehouse | `DBT_DEV_WH` | `DBT_PROD_WH` |
| Role / user | `DBT_DEV_ROLE` / `DBT_DEV_USER` | `DBT_PROD_ROLE` / `DBT_PROD_USER` |
| Key pair | dev key | separate prod key |
| Schemas | `RAW`, `STAGING`, `INTERMEDIATE`, `MART`, plus `PR_<n>_*` | `RAW`, `STAGING`, `INTERMEDIATE`, `MART` only |
| Written by | local dev, PR builds, pushes to `dev` | pushes to `master` |

Separation is enforced by Snowflake, not only by convention: the dev role has
no privileges on the prod database, the prod role cannot create schemas, and
each user has its own key. `ANALYTICS_READER` is a read-only role on the prod
`MART` for BI tools or applications.

Schema names come from [`generate_schema_name`](src/dbt/macros/generate_schema_name.sql):
the layer name, optionally prefixed by `DBT_SCHEMA_PREFIX` (e.g. `PR_12_RAW`).
The prefix is rejected on the prod target.

## Snowflake setup (one time)

1. Review and run [`scripts/snowflake-setup.sql`](scripts/snowflake-setup.sql)
   as an administrator. It only creates/grants; it never drops anything.
2. Generate **two** encrypted key pairs, one per service user, outside the
   repository:

   ```sh
   mkdir -p ~/.snowflake-keys && cd ~/.snowflake-keys
   openssl genrsa 2048 | openssl pkcs8 -topk8 -v2 aes-256-cbc -inform PEM -out snowflake_key.p8
   openssl rsa -in snowflake_key.p8 -pubout -out snowflake_key.pub
   # repeat in a different directory for the prod key
   ```

3. Register each public key (body without the PEM header/footer):
   `ALTER USER DBT_DEV_USER SET RSA_PUBLIC_KEY = '...';` and the same for
   `DBT_PROD_USER` with the prod key.

The prod private key only needs to exist as a GitHub secret. Keep it off
development machines.

## Local development

### Dev Container (recommended)

1. On the host, put the **dev** key at `~/.snowflake-keys/snowflake_key.p8`
   (Windows: `%USERPROFILE%\.snowflake-keys\snowflake_key.p8`). The folder
   must exist, or the container will not start.
2. Set `SNOWFLAKE_ACCOUNT` and `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` (and
   optionally `DBT_SCHEMA_PREFIX`) in the environment that launches VS Code.
3. Reopen in container. The key is mounted read-only at
   `/run/secrets/snowflake/snowflake_key.p8`; the remaining connection
   variables point at the dev environment.

### Without the container

```sh
python -m pip install -r requirements.txt
cp .env.example .env        # fill in; .env is git-ignored
set -a; . ./.env; set +a
```

### Running dbt

```sh
cd src/dbt
dbt debug                  # check the connection
dbt seed                   # load the CSV sources into RAW
dbt run-operation load_order_details   # load the JSON into RAW
dbt build                  # seeds + models + tests
dbt build -s +my_model     # one model and its parents
```

By default local runs write to the shared dev schemas, which the `dev` branch
CI also rebuilds. To keep your own copy, set e.g. `DBT_SCHEMA_PREFIX=DEV_<NAME>_`.

Never run `--target prod` locally; production is built only by CD.

## Branching and CI/CD

```
feature/* --PR--> dev --PR--> master
```

| Event | Workflow | Writes to |
|---|---|---|
| PR into `dev` or `master` | `ci.yml` | `ANALYTICS_DEV.PR_<n>_*` |
| Push to `dev` (merged PR) | `ci.yml` | `ANALYTICS_DEV` shared schemas |
| PR closed | `cleanup-pr.yml` | drops `ANALYTICS_DEV.PR_<n>_*` |
| Push to `master` / manual | `cd.yml` | `ANALYTICS_PROD` (after approval) |

Every CI run first does offline checks (`dbt parse`) without credentials,
then loads the JSON and runs `dbt build`. dbt artifacts (`manifest.json`,
`run_results.json`, log) are uploaded for each build.

### GitHub configuration

Create two **environments** (Settings → Environments) with the same names
for secrets and variables, so workflows are identical across environments.
Do **not** create repository-level Snowflake secrets/variables: an environment
value that is missing would silently fall back to them.

| Name | Kind | `development` | `production` |
|---|---|---|---|
| `SNOWFLAKE_ACCOUNT` | secret | account identifier | account identifier |
| `SNOWFLAKE_PRIVATE_KEY` | secret | dev private key (full PEM) | prod private key (full PEM) |
| `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` | secret | dev passphrase | prod passphrase |
| `SNOWFLAKE_USER` | variable (or secret) | `DBT_DEV_USER` | `DBT_PROD_USER` |
| `SNOWFLAKE_ROLE` | variable (or secret) | `DBT_DEV_ROLE` | `DBT_PROD_ROLE` |
| `SNOWFLAKE_DATABASE` | variable (or secret) | `ANALYTICS_DEV` | `ANALYTICS_PROD` |
| `SNOWFLAKE_WAREHOUSE` | variable (or secret) | `DBT_DEV_WH` | `DBT_PROD_WH` |

Protect `production`:
- **Deployment branches:** selected branches → `master` only. Without this, a
  workflow edited in a PR could request the production environment.
- **Required reviewers:** at least one.

Protect the `master` and `dev` branches (require PRs and the `CI` checks).

Notes:
- PRs from forks do not receive environment secrets, so
  their `dbt build` job fails at the variable check; the offline checks still run.
- `cleanup-pr.yml` can also be run manually with a PR number to remove
  leftover `PR_<n>_*` schemas.
