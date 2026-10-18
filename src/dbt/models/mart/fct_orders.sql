-- One row per order, latest version.

SELECT
    order_id,
    organization_id,
    IFF(status = 'complete', 'completed', status) AS status,
    amount,
    created_at,
    updated_at
FROM {{ ref('int_orders_latest') }}
