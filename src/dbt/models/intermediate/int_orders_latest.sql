-- Latest version of each order.

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY
                updated_at DESC,
                {{ order_status_stage('status') }} DESC
        ) AS version_rank
    FROM orders
)

SELECT * EXCLUDE (version_rank)
FROM ranked
WHERE version_rank = 1
