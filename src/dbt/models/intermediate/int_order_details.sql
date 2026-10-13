-- One row per order from the JSON source. Arrays are ordered by their own
-- timestamps/dates, never by position.

WITH details AS (

    SELECT * FROM {{ ref('stg_order_details') }}

),

status_events AS (

    SELECT
        d.order_id,
        s.value:status::VARCHAR                                AS status,
        TRY_TO_TIMESTAMP_NTZ(s.value:timestamp::VARCHAR)       AS status_at
    FROM details AS d,
        LATERAL FLATTEN(input => d.status_history) AS s

),

latest_status AS (

    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY status_at DESC) AS status_rank
    FROM status_events

),

nav_points AS (

    SELECT
        d.order_id,
        TRY_TO_DATE(n.value:date::VARCHAR)                     AS nav_date,
        TRY_TO_NUMBER(n.value:nav::VARCHAR, 18, 2)             AS nav
    FROM details AS d,
        LATERAL FLATTEN(input => d.nav_history) AS n

),

-- Previous NAV = most recent history point before the current NAV date.
previous_nav AS (

    SELECT
        p.order_id,
        p.nav,
        ROW_NUMBER() OVER (PARTITION BY p.order_id ORDER BY p.nav_date DESC) AS nav_rank
    FROM nav_points AS p
    INNER JOIN details AS d
        ON p.order_id = d.order_id
    WHERE p.nav_date < d.nav_as_of_date

),

order_details_final AS (

    SELECT
        d.order_id,
        d.organization_id,
        d.investor_id,
        d.investor_name,
        d.product_id,
        d.product_name,
        d.investment_amount,
        s.status                        AS latest_status,
        s.status_at                     AS latest_status_at,
        d.current_nav,
        d.nav_as_of_date,
        p.nav                           AS previous_nav,
        d.current_nav - p.nav           AS nav_change
    FROM details AS d
    LEFT JOIN latest_status AS s
        ON d.order_id = s.order_id
        AND s.status_rank = 1
    LEFT JOIN previous_nav AS p
        ON d.order_id = p.order_id
        AND p.nav_rank = 1

)

SELECT * FROM order_details_final
