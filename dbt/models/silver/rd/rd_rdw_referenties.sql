{{ config(
    materialized='table',
    on_schema_change='sync_all_columns'
) }}

select distinct
    kenteken,
    api_gekentekende_voertuigen_assen,
    api_gekentekende_voertuigen_brandstof,
    api_gekentekende_voertuigen_carrosserie,
    api_gekentekende_voertuigen_carrosserie_specifiek,
    api_gekentekende_voertuigen_voertuigklasse
from {{ source('lakehouse_bronze', 'gekentekendevoertuigen') }};
