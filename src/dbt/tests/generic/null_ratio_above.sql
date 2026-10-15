-- src/dbt/tests/generic/null_ratio_above.sql
{% test null_ratio_above(model, column_name, max_ratio) %}

SELECT
    COUNT_IF ({{ column_name}} IS NULL) / NULLIF(COUNT(*), 0) AS null_ratio_above
FROM {{model}}
HAVING null_ratio_above > {{max_ratio}}

{% endtest %}