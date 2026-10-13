-- One row per order from the JSON source. Arrays are ordered by their own
-- timestamps/dates, never by position; arrays are reduced to one row per order
-- (QUALIFY) before joining back, so joins stay 1:1 at any volume.

WITH details AS (

    SELECT * FROM {{ ref('stg_order_details') }}

),

latest_status AS (

    SELECT
        d.order_id,
        s.value:status::VARCHAR                                                     AS status,
        TRY_TO_TIMESTAMP_NTZ(s.value:timestamp::VARCHAR, 'YYYY-MM-DD"T"HH24:MI:SS') AS status_at
    FROM details AS d,
        LATERAL FLATTEN(input => d.status_history) AS s
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY d.order_id
        ORDER BY status_at DESC, {{ order_status_stage('status') }} DESC, s.index DESC
    ) = 1

),

-- Previous NAV = most recent history point before the current NAV date.
previous_nav AS (

    SELECT
        d.order_id,
        TRY_TO_NUMBER(n.value:nav::VARCHAR, 18, 2)                                  AS nav,
        TRY_TO_DATE(n.value:date::VARCHAR, 'YYYY-MM-DD')                            AS nav_date
    FROM details AS d,
        LATERAL FLATTEN(input => d.nav_history) AS n
    WHERE TRY_TO_DATE(n.value:date::VARCHAR, 'YYYY-MM-DD') < d.nav_as_of_date
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY d.order_id
        ORDER BY nav_date DESC, n.index DESC
    ) = 1

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
    LEFT JOIN previous_nav AS p
        ON d.order_id = p.order_id

)

SELECT * FROM order_details_final
