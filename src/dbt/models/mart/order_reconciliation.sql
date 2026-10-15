-- Compares orders with the JSON details by order_id.

WITH orders AS (

    SELECT * FROM {{ ref('int_orders_latest') }}

),

details AS (

    SELECT * FROM {{ ref('int_order_details') }}

),

joined AS (

    SELECT
        COALESCE(o.order_id, d.order_id) AS order_id,
        o.order_id IS NOT NULL AS in_orders,
        d.order_id IS NOT NULL AS in_json,
        o.organization_id AS orders_organization_id,
        d.organization_id AS json_organization_id,
        o.amount AS orders_amount,
        d.investment_amount AS json_amount,
        o.status AS orders_status,
        d.latest_status AS json_status,
        o.updated_at AS orders_updated_at,
        d.latest_status_at AS json_status_at
    FROM orders AS o
    FULL OUTER JOIN details AS d
        ON o.order_id = d.order_id

),

compared AS (

    SELECT
        *,
        IFF(in_orders AND in_json, EQUAL_NULL(orders_organization_id, json_organization_id), NULL) AS organization_matches,
        IFF(in_orders AND in_json, EQUAL_NULL(orders_amount, json_amount), NULL) AS amount_matches,
        IFF(in_orders AND in_json, EQUAL_NULL(orders_status, json_status), NULL) AS status_matches,
        IFF(in_orders AND in_json, EQUAL_NULL(orders_updated_at, json_status_at), NULL) AS status_at_matches
    FROM joined

)

SELECT
    *,
    COALESCE(organization_matches AND amount_matches
        AND status_matches AND status_at_matches, FALSE) AS is_consistent
FROM compared
