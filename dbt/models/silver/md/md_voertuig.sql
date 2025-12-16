{{ config(
    materialized='incremental',
    unique_key='kenteken',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
) }}

with src as (
    select distinct
        *,
        md5(
            concat_ws(
                '|',
                coalesce(aantal_cilinders, ''),
                coalesce(cilinderinhoud, ''),
                coalesce(type_gasinstallatie, ''),
                coalesce(zuinigheidsclassificatie, ''),
                coalesce(vermogen_massarijklaar, '')
            )
        ) as motorconfiguratie_id
    from {{ source('lakehouse_bronze', 'gekentekendevoertuigen') }}
)

select
    kenteken,

    -- Identiteit
    voertuigsoort,
    merk,
    handelsbenaming,
    uitvoering,
    variant,
    inrichting,

    -- Maten en massa
    lengte,
    breedte,
    hoogte_voertuig as hoogte,
    wielbasis,
    massa_ledig_voertuig,
    massa_rijklaar,
    massa_bedrijfsklaar_maximaal,
    massa_bedrijfsklaar_minimaal,
    toegestane_maximum_massa_voertuig,
    technische_max_massa_voertuig,
    maximale_constructiesnelheid,

    -- Registratie
    datum_eerste_toelating_dt as datum_eerste_toelating,
    datum_eerste_tenaamstelling_in_nederland_dt as datum_eerste_tenaamstelling_in_nederland,
    datum_tenaamstelling_dt as datum_tenaamstelling,
    vervaldatum_apk_dt as vervaldatum_apk,
    vervaldatum_tachograaf_dt as vervaldatum_tachograaf,

    -- FK naar referentie object
    motorconfiguratie_id
from src;
