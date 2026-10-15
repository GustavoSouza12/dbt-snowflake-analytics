-- Orders from the raw CSV with proper types, one row per version.

WITH source AS (
    SELECT * FROM {{ ref('orders') }}
),

typed AS (
    SELECT
        TRY_TO_NUMBER(order_id) AS order_id,
        TRY_TO_NUMBER(organization_id) AS organization_id,
        LOWER(TRIM(status)) AS status,
        TRY_TO_NUMBER(amount, 18, 2) AS amount,
        TRY_TO_TIMESTAMP_NTZ(created_at, 'YYYY-MM-DD"T"HH24:MI:SS') AS created_at,
        TRY_TO_TIMESTAMP_NTZ(updated_at, 'YYYY-MM-DD"T"HH24:MI:SS') AS updated_at
    FROM source
)

SELECT * FROM typed
