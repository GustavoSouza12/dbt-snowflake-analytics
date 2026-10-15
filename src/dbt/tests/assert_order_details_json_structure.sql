{{ config(severity = 'warn') }}

{% set expected_keys = "ARRAY_CONSTRUCT('order_id', 'organization_id', 'investor', 'product',
    'investment', 'status_history', 'nav', 'submitted_at')" %}
{% set numeric_types = "('INTEGER', 'DECIMAL', 'DOUBLE')" %}

WITH documents AS (
    SELECT
        record_number,
        TRY_PARSE_JSON(payload) AS doc
    FROM {{ ref('order_details') }}
),

nav_history_types AS (
    SELECT
        d.record_number,
        COUNT_IF(TYPEOF(h.value:nav) NOT IN {{ numeric_types }}) AS non_numeric_points
    FROM documents AS d,
        LATERAL FLATTEN(input => d.doc:nav.history, outer => TRUE) AS h
    GROUP BY d.record_number
),

checks AS (
    SELECT
        d.record_number,
        d.doc:order_id::VARCHAR AS order_id,
        ARRAY_CONSTRUCT_COMPACT(
            IFF(d.doc IS NULL, 'invalid JSON', NULL),
            IFF(d.doc:investor.investor_id::VARCHAR IS NULL, 'missing investor.investor_id', NULL),
            IFF(d.doc:product.product_id::VARCHAR IS NULL, 'missing product.product_id', NULL),
            IFF(d.doc:investment.amount::VARCHAR IS NULL, 'missing investment.amount', NULL),
            IFF(d.doc:nav.current_nav::VARCHAR IS NULL, 'missing nav.current_nav', NULL),
            IFF(TYPEOF(d.doc:investment.amount) NOT IN {{ numeric_types }} AND d.doc:investment.amount::VARCHAR IS NOT NULL,
                'investment.amount is ' || TYPEOF(d.doc:investment.amount), NULL),
            IFF(TYPEOF(d.doc:nav.current_nav) NOT IN {{ numeric_types }} AND d.doc:nav.current_nav::VARCHAR IS NOT NULL,
                'nav.current_nav is ' || TYPEOF(d.doc:nav.current_nav), NULL),
            IFF(n.non_numeric_points > 0, 'nav.history has non-numeric values', NULL),
            IFF(TYPEOF(d.doc:status_history) <> 'ARRAY', 'status_history is not an array', NULL)
        ) AS field_issues,
        ARRAY_EXCEPT({{ expected_keys }}, OBJECT_KEYS(d.doc)) AS missing_keys,
        ARRAY_EXCEPT(OBJECT_KEYS(d.doc), {{ expected_keys }}) AS unexpected_keys
    FROM documents AS d
    LEFT JOIN nav_history_types AS n
        ON d.record_number = n.record_number
)

SELECT *
FROM checks
WHERE ARRAY_SIZE(field_issues) > 0
    OR COALESCE(ARRAY_SIZE(missing_keys), 0) > 0
    OR COALESCE(ARRAY_SIZE(unexpected_keys), 0) > 0
