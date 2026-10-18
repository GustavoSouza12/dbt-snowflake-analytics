-- One row per organization.

SELECT
    organization_id,
    organization_name,
    created_at
FROM {{ ref('stg_organizations') }}
