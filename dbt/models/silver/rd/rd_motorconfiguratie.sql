{{ config(
    materialized='table',
    on_schema_change='sync_all_columns'
) }}

with base as (
    select
        coalesce(aantal_cilinders, '')          as aantal_cilinders,
        coalesce(cilinderinhoud, '')            as cilinderinhoud,
        coalesce(type_gasinstallatie, '')       as type_gasinstallatie,
        coalesce(zuinigheidsclassificatie, '')  as zuinigheidsclassificatie,
        coalesce(vermogen_massarijklaar, '')    as vermogen_massarijklaar,
        afwijkende_maximum_snelheid
    from {{ source('lakehouse_bronze', 'gekentekendevoertuigen') }}
),

dedup as (
    select
        md5(concat_ws(
            '|',
            aantal_cilinders,
            cilinderinhoud,
            type_gasinstallatie,
            zuinigheidsclassificatie,
            vermogen_massarijklaar
        )) as motorconfiguratie_id,

        aantal_cilinders,
        cilinderinhoud,
        type_gasinstallatie,
        zuinigheidsclassificatie,
        vermogen_massarijklaar,

        max(afwijkende_maximum_snelheid) as afwijkende_maximum_snelheid
    from base
    group by
        aantal_cilinders,
        cilinderinhoud,
        type_gasinstallatie,
        zuinigheidsclassificatie,
        vermogen_massarijklaar
)

select * from dedup;
