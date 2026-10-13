{#
    Drop the PR_<number>_* schemas a pull request build created in the dev
    database. Used by .github/workflows/cleanup-pr.yml when a PR closes.

        dbt run-operation drop_pr_schemas --args '{pr_number: 123}'

    Guards: dev target only, numeric PR number, exact prefix match (no LIKE
    wildcards, so PR_1_ never matches PR_12_).
#}
{% macro drop_pr_schemas(pr_number) %}
    {% if target.name != 'dev' %}
        {{ exceptions.raise_compiler_error("drop_pr_schemas only runs against the dev target, not " ~ target.name) }}
    {% endif %}
    {% set pr = pr_number | string | trim %}
    {% if not modules.re.fullmatch('[1-9][0-9]*', pr) %}
        {{ exceptions.raise_compiler_error("pr_number must be a positive integer, got: " ~ pr) }}
    {% endif %}
    {% set prefix = 'PR_' ~ pr ~ '_' %}

    {% set schemas_query %}
        select schema_name
        from {{ target.database }}.information_schema.schemata
        where startswith(schema_name, '{{ prefix }}')
        order by schema_name
    {% endset %}
    {% set schemas = run_query(schemas_query).columns[0].values() %}

    {% if schemas | length == 0 %}
        {{ log("No schemas with prefix " ~ prefix ~ " in " ~ target.database, info=true) }}
    {% endif %}
    {% for schema in schemas %}
        {{ log("Dropping " ~ target.database ~ "." ~ schema, info=true) }}
        {% do run_query("drop schema if exists " ~ target.database ~ "." ~ schema) %}
    {% endfor %}
{% endmacro %}
