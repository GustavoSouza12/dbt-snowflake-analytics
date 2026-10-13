-- =============================================================================
-- Snowflake provisioning for the dbt project.
--
-- Idempotent (IF NOT EXISTS everywhere) and additive: it never drops or
-- replaces anything. Review it, then run it as a user that holds SYSADMIN,
-- USERADMIN and SECURITYADMIN (e.g. ACCOUNTADMIN in a personal account).
--
-- Environment separation
--   dev  : DBT_DEV_USER  -> DBT_DEV_ROLE  -> DBT_DEV_DB  on DBT_DEV_WH
--   prod : DBT_PROD_USER -> DBT_PROD_ROLE -> DBT_PROD_DB on DBT_PROD_WH
--   The dev role has no privileges on the prod database and vice versa, and
--   each user has its own key pair, so a dev credential cannot write to prod.
--   ANALYTICS_READER is read-only on the prod MART schema, for BI/app consumers.
--
-- If you rename anything, update README.md, .devcontainer/devcontainer.json,
-- .env.example and the GitHub environment variables to match.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Compute and storage (owned by SYSADMIN)
-- -----------------------------------------------------------------------------
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS DBT_DEV_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 1800
  COMMENT = 'dbt development and pull request builds';

CREATE WAREHOUSE IF NOT EXISTS DBT_PROD_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 3600
  COMMENT = 'dbt production builds';

CREATE DATABASE IF NOT EXISTS DBT_DEV_DB  COMMENT = 'dbt development: shared dev schemas and PR_<n>_* schemas';
CREATE DATABASE IF NOT EXISTS DBT_PROD_DB COMMENT = 'dbt production';

CREATE SCHEMA IF NOT EXISTS DBT_DEV_DB.RAW;
CREATE SCHEMA IF NOT EXISTS DBT_DEV_DB.INTERMEDIATE;
CREATE SCHEMA IF NOT EXISTS DBT_DEV_DB.MART;
CREATE SCHEMA IF NOT EXISTS DBT_PROD_DB.RAW;
CREATE SCHEMA IF NOT EXISTS DBT_PROD_DB.INTERMEDIATE;
CREATE SCHEMA IF NOT EXISTS DBT_PROD_DB.MART;


-- -----------------------------------------------------------------------------
-- 2. Roles and service users (USERADMIN)
-- -----------------------------------------------------------------------------
USE ROLE USERADMIN;

CREATE ROLE IF NOT EXISTS DBT_DEV_ROLE     COMMENT = 'dbt builds in DBT_DEV_DB';
CREATE ROLE IF NOT EXISTS DBT_PROD_ROLE    COMMENT = 'dbt builds in DBT_PROD_DB';
CREATE ROLE IF NOT EXISTS ANALYTICS_READER COMMENT = 'Read-only access to DBT_PROD_DB.MART';

-- Service users authenticate only with key pairs (no password).
CREATE USER IF NOT EXISTS DBT_DEV_USER
  TYPE = SERVICE
  DEFAULT_ROLE = DBT_DEV_ROLE
  DEFAULT_WAREHOUSE = DBT_DEV_WH
  DEFAULT_NAMESPACE = DBT_DEV_DB.INTERMEDIATE
  COMMENT = 'dbt dev / CI service user';

CREATE USER IF NOT EXISTS DBT_PROD_USER
  TYPE = SERVICE
  DEFAULT_ROLE = DBT_PROD_ROLE
  DEFAULT_WAREHOUSE = DBT_PROD_WH
  DEFAULT_NAMESPACE = DBT_PROD_DB.INTERMEDIATE
  COMMENT = 'dbt production service user';

-- Register each public key out of band. Use a DIFFERENT key pair per user and
-- never put private key material in this file or anywhere in the repository.
-- ALTER USER DBT_DEV_USER  SET RSA_PUBLIC_KEY = '<dev public key, no PEM header/footer>';
-- ALTER USER DBT_PROD_USER SET RSA_PUBLIC_KEY = '<prod public key, no PEM header/footer>';


-- -----------------------------------------------------------------------------
-- 3. Grants (SECURITYADMIN)
-- -----------------------------------------------------------------------------
USE ROLE SECURITYADMIN;

-- Custom roles roll up to SYSADMIN so administrators can manage what dbt creates.
GRANT ROLE DBT_DEV_ROLE     TO ROLE SYSADMIN;
GRANT ROLE DBT_PROD_ROLE    TO ROLE SYSADMIN;
GRANT ROLE ANALYTICS_READER TO ROLE SYSADMIN;

GRANT ROLE DBT_DEV_ROLE  TO USER DBT_DEV_USER;
GRANT ROLE DBT_PROD_ROLE TO USER DBT_PROD_USER;

-- dev: build in the shared schemas and create isolated PR_<n>_* schemas.
-- Schemas the dev role creates are owned by it, so it can also drop them.
GRANT USAGE ON WAREHOUSE DBT_DEV_WH TO ROLE DBT_DEV_ROLE;
GRANT USAGE, CREATE SCHEMA ON DATABASE DBT_DEV_DB TO ROLE DBT_DEV_ROLE;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA DBT_DEV_DB.RAW          TO ROLE DBT_DEV_ROLE;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA DBT_DEV_DB.INTERMEDIATE TO ROLE DBT_DEV_ROLE;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA DBT_DEV_DB.MART         TO ROLE DBT_DEV_ROLE;

-- prod: build only in the pre-created schemas; no CREATE SCHEMA, so a stray
-- schema prefix or misconfiguration fails instead of creating new schemas.
GRANT USAGE ON WAREHOUSE DBT_PROD_WH TO ROLE DBT_PROD_ROLE;
GRANT USAGE ON DATABASE DBT_PROD_DB TO ROLE DBT_PROD_ROLE;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA DBT_PROD_DB.RAW          TO ROLE DBT_PROD_ROLE;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA DBT_PROD_DB.INTERMEDIATE TO ROLE DBT_PROD_ROLE;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA DBT_PROD_DB.MART         TO ROLE DBT_PROD_ROLE;

-- Consumers read the prod MART only. Future grants cover the tables dbt
-- recreates on every run. Grant ANALYTICS_READER to BI/app users as needed.
GRANT USAGE ON WAREHOUSE DBT_PROD_WH TO ROLE ANALYTICS_READER;
GRANT USAGE ON DATABASE DBT_PROD_DB TO ROLE ANALYTICS_READER;
GRANT USAGE ON SCHEMA DBT_PROD_DB.MART TO ROLE ANALYTICS_READER;
GRANT SELECT ON ALL TABLES    IN SCHEMA DBT_PROD_DB.MART TO ROLE ANALYTICS_READER;
GRANT SELECT ON ALL VIEWS     IN SCHEMA DBT_PROD_DB.MART TO ROLE ANALYTICS_READER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA DBT_PROD_DB.MART TO ROLE ANALYTICS_READER;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA DBT_PROD_DB.MART TO ROLE ANALYTICS_READER;


-- -----------------------------------------------------------------------------
-- 4. Verification (read-only)
-- -----------------------------------------------------------------------------
SHOW GRANTS TO ROLE DBT_DEV_ROLE;
SHOW GRANTS TO ROLE DBT_PROD_ROLE;
SHOW GRANTS TO ROLE ANALYTICS_READER;
SHOW FUTURE GRANTS IN SCHEMA DBT_PROD_DB.MART;
