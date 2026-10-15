{{ config(severity = 'warn') }}

SELECT
    order_id,
    status,
    created_at,
    updated_at
FROM {{ ref('stg_orders') }}
WHERE updated_at < created_at
