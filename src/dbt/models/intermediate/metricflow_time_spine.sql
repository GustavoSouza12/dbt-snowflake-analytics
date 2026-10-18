-- One row per day, used by MetricFlow for time-based metrics.

WITH days AS (
    {{ dbt.date_spine('day', "TO_DATE('2020-01-01')", "TO_DATE('2031-01-01')") }}
)

SELECT CAST(date_day AS DATE) AS date_day
FROM days
