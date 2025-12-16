{{ config(
    materialized='table',
    on_schema_change='sync_all_columns'
) }}

select distinct
    kenteken,
    europese_voertuigcategorie,
    europese_voertuigcategorie_toevoeging,
    subcategorie_nederland,
    typegoedkeuringsnummer,
    europese_uitvoeringcategorie_toevoeging,
    volgnummer_wijziging_eu_typegoedkeuring
from {{ source('lakehouse_bronze', 'gekentekendevoertuigen') }};
