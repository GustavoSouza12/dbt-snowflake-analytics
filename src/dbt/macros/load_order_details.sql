{#
    Load data/order_details.json into RAW.ORDER_DETAILS natively in Snowflake:
    PUT the file to an internal stage, then COPY INTO a VARIANT table, one row
    per array element (STRIP_OUTER_ARRAY). Idempotent: COPY skips files it has
    already loaded, so reruns never duplicate rows.

        dbt run-operation load_order_details
#}
{% macro load_order_details(file_path='../../data/order_details.json') %}

    {% set database = target.database %}
    {% set schema = generate_schema_name('RAW', none) %}
    {% set fq = database ~ '.' ~ schema %}

    {% if not adapter.check_schema_exists(database, schema) %}
        {% do run_query('create schema ' ~ fq) %}
    {% endif %}

    {% set setup_sql %}
        create file format if not exists {{ fq }}.json_array_format
            type = json
            strip_outer_array = true;

        create stage if not exists {{ fq }}.order_details_stage
            file_format = {{ fq }}.json_array_format;

        create table if not exists {{ fq }}.order_details (
            payload     variant,
            _file       varchar,
            _file_row   number,
            _loaded_at  timestamp_ltz
        );
    {% endset %}
    {% for statement in setup_sql.split(';') if statement.strip() %}
        {% do run_query(statement) %}
    {% endfor %}

    {% do run_query(
        "put 'file://" ~ file_path ~ "' @" ~ fq ~ ".order_details_stage auto_compress = false overwrite = false"
    ) %}

    {% set result = run_query(
        "copy into " ~ fq ~ ".order_details (payload, _file, _file_row, _loaded_at)
         from (
             select $1, metadata$filename, metadata$file_row_number, current_timestamp()
             from @" ~ fq ~ ".order_details_stage
         )
         on_error = abort_statement"
    ) %}

    {% for row in result.rows %}
        {{ log(row[0] ~ ': ' ~ row[1], info=true) }}
    {% endfor %}

{% endmacro %}
