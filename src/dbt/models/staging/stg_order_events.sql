-- Staging model for the order_events seed: one row per event received.

WITH source AS (

    SELECT * FROM {{ ref('order_events') }}

),

typed AS (

    SELECT
        TRY_TO_NUMBER(event_id)                                       AS event_id,
        TRY_TO_NUMBER(order_id)                                       AS order_id,
        LOWER(TRIM(event_type))                                       AS event_type,
        TRY_TO_TIMESTAMP_NTZ(created_at, 'YYYY-MM-DD"T"HH24:MI:SS')   AS created_at
    FROM source

)

SELECT * FROM typed
