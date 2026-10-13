-- Latest version of each order: one row per order_id.
-- Latest = most recent updated_at; ties broken by lifecycle stage so the
-- result is deterministic. Exact duplicate rows (e.g. 1010) collapse to one.

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