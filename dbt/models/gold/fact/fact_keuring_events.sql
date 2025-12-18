{{ config(
    materialized='incremental',
    unique_key='event_id',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
) }}

with events as (
    select
        kenteken,
        vervaldatum_apk       as event_datum,
        'apk_verval'          as event_type
    from {{ ref('md_voertuig') }}
    where vervaldatum_apk is not null

    union all

    select
        kenteken,
        vervaldatum_tachograaf as event_datum,
        'tachograaf_verval'    as event_type
    from {{ ref('md_voertuig') }}
    where vervaldatum_tachograaf is not null
)

select
    md5(
        concat_ws(
            '|',
            coalesce(kenteken, ''),
            coalesce(event_type, ''),
            coalesce(cast(event_datum as string), '')
        )
    ) as event_id,
    kenteken,
    event_datum,
    event_type
from events;
