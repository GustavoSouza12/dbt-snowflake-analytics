WITH source AS (

    SELECT * FROM {{ ref('order_details') }}

),

parsed AS (

    SELECT
        record_number,
        PARSE_JSON(payload) AS j
    FROM source

)

SELECT
    j:order_id::NUMBER                                       AS order_id,
    j:organization_id::NUMBER                                AS organization_id,
    j:investor.investor_id::VARCHAR                          AS investor_id,
    j:investor.name::VARCHAR                                 AS investor_name,
    j:product.product_id::VARCHAR                            AS product_id,
    j:product.product_name::VARCHAR                          AS product_name,
    TRY_TO_NUMBER(j:investment.amount::VARCHAR, 18, 2)       AS investment_amount,
    TRY_TO_NUMBER(j:nav.current_nav::VARCHAR, 18, 2)         AS current_nav,
    TRY_TO_DATE(j:nav.as_of_date::VARCHAR)                   AS nav_as_of_date,
    j:status_history                                         AS status_history,
    j:nav.history                                            AS nav_history
FROM parsed

