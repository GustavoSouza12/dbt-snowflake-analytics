{# Lifecycle stage of an order status, used to break ties deterministically. #}
{% macro order_status_stage(status_column) -%}
    CASE {{ status_column }}
        WHEN 'cancelled' THEN 4
        WHEN 'completed' THEN 3
        WHEN 'complete'  THEN 3
        WHEN 'approved'  THEN 2
        WHEN 'pending'   THEN 1
        WHEN 'created'   THEN 1
        ELSE 0
    END
{%- endmacro %}
