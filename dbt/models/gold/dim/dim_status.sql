{{ config(
    materialized='table',
    on_schema_change='sync_all_columns'
) }}

select
    kenteken,
    export_indicator,
    openstaande_terugroepactie_indicator,
    taxi_indicator,
    tellerstandoordeel,
    tenaamstellen_mogelijk
from {{ ref('rd_voertuig_statuswaarden') }};
