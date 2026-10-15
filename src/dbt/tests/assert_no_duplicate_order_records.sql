{{ config(severity = 'warn') }}

SELECT
    HASH(*)              AS row_hash,
    ANY_VALUE(order_id)  AS order_id,
    COUNT(*)             AS occurrences
FROM {{ ref('stg_orders') }}
GROUP BY row_hash
HAVING COUNT(*) > 1
