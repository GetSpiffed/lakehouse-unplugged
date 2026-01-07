{{
  config(
    materialized='table',
    file_format='iceberg'
  )
}}

select
  id,
  label,
  created_at
from {{ ref('smoke_seed_base') }}
