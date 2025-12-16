{{ config(
    materialized='table',
    on_schema_change='sync_all_columns'
) }}

with enriched as (
    select distinct
        md5(
            concat_ws(
                '|',
                coalesce(aantal_cilinders, ''),
                coalesce(cilinderinhoud, ''),
                coalesce(type_gasinstallatie, ''),
                coalesce(zuinigheidsclassificatie, ''),
                coalesce(vermogen_massarijklaar, '')
            )
        ) as motorconfiguratie_id,
        aantal_cilinders,
        cilinderinhoud,
        type_gasinstallatie,
        zuinigheidsclassificatie,
        vermogen_massarijklaar,
        afwijkende_maximum_snelheid
    from {{ source('lakehouse_bronze', 'gekentekendevoertuigen') }}
)

select * from enriched;
