-- One row per organization with its order metrics.

WITH organizations AS (
    SELECT * FROM {{ ref('stg_organizations') }}
),

orders AS (
    SELECT
        *,
        status IN ('completed', 'complete') AS is_completed
    FROM {{ ref('int_orders_latest') }}
),

order_metrics AS (
    SELECT
        organization_id,
        COUNT(*) AS number_of_orders,
        COUNT_IF(is_completed) AS completed_orders,
        SUM(CASE WHEN is_completed AND amount > 0 THEN amount END) AS completed_order_amount,
        COUNT_IF(is_completed AND (amount IS NULL OR amount <= 0)) AS orders_with_invalid_amount,
        MAX(created_at) AS latest_order_at,
        MAX(CASE WHEN is_completed THEN updated_at END) AS latest_completed_order_at
    FROM orders
    WHERE organization_id IS NOT NULL
    GROUP BY organization_id
),

org_summary_final AS (
    SELECT
        o.organization_id,
        o.organization_name,
        COALESCE(m.number_of_orders, 0) AS number_of_orders,
        COALESCE(m.completed_orders, 0) AS completed_orders,
        COALESCE(m.completed_order_amount, 0) AS completed_order_amount,
        COALESCE(m.orders_with_invalid_amount, 0) AS orders_with_invalid_amount,
        m.latest_order_at,
        m.latest_completed_order_at
    FROM organizations AS o
    LEFT JOIN order_metrics AS m
        ON o.organization_id = m.organization_id
)

SELECT * FROM org_summary_final
