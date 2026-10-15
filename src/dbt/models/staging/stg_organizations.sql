-- Organizations from the raw CSV with proper types.

WITH source AS (
    SELECT * FROM {{ ref('organizations') }}
),

typed AS (
    SELECT
        TRY_TO_NUMBER(id) AS organization_id,
        TRIM(name) AS organization_name,
        TRY_TO_TIMESTAMP_NTZ(created_at, 'YYYY-MM-DD"T"HH24:MI:SS') AS created_at
    FROM source
)

SELECT * FROM typed
