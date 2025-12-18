{{ config(
    materialized='incremental',
    unique_key='event_id',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
) }}

with events as (
    select
        kenteken,
        datum_eerste_toelating     as event_datum,
        'eerste_toelating'         as event_type
    from {{ ref('md_voertuig') }}
    where datum_eerste_toelating is not null

    union all

    select
        kenteken,
        datum_eerste_tenaamstelling_in_nederland as event_datum,
        'tenaamstelling_in_nederland'            as event_type
    from {{ ref('md_voertuig') }}
    where datum_eerste_tenaamstelling_in_nederland is not null

    union all

    select
        kenteken,
        datum_tenaamstelling       as event_datum,
        'tenaamstelling'           as event_type
    from {{ ref('md_voertuig') }}
    where datum_tenaamstelling is not null
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
