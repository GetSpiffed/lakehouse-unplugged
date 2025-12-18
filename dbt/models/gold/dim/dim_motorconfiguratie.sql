{{ config(
    materialized='table',
    on_schema_change='sync_all_columns'
) }}

select
    motorconfiguratie_id,
    aantal_cilinders,
    cilinderinhoud,
    type_gasinstallatie,
    zuinigheidsclassificatie,
    vermogen_massarijklaar,
    afwijkende_maximum_snelheid
from {{ ref('rd_motorconfiguratie') }};
