{#
    Schemas are the layer names (RAW, INTERMEDIATE, MART) without dbt's default
    "<target_schema>_" concatenation. DBT_SCHEMA_PREFIX isolates a build, e.g.
    PR_123_ for pull requests; it is refused on the prod target.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set schema_prefix = env_var('DBT_SCHEMA_PREFIX', '') | trim | upper -%}
    {%- if schema_prefix -%}
        {%- if target.name == 'prod' -%}
            {{ exceptions.raise_compiler_error("DBT_SCHEMA_PREFIX must not be set for the prod target") }}
        {%- endif -%}
        {%- if not modules.re.fullmatch('[A-Z][A-Z0-9_]*_', schema_prefix) -%}
            {{ exceptions.raise_compiler_error("DBT_SCHEMA_PREFIX must match [A-Z][A-Z0-9_]*_ , got: " ~ schema_prefix) }}
        {%- endif -%}
    {%- endif -%}
    {%- set base_schema = target.schema if custom_schema_name is none else custom_schema_name | trim -%}
    {{ schema_prefix ~ (base_schema | upper) }}
{%- endmacro %}
