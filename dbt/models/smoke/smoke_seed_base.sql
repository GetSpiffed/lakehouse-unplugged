{{
  config(
    materialized='table',
    file_format='iceberg',
    pre_hook=["CREATE NAMESPACE IF NOT EXISTS {{ target.catalog }}.{{ target.schema }}"]
  )
}}

select
  1 as id,
  'alpha' as label,
  current_timestamp() as created_at
union all
select
  2 as id,
  'beta' as label,
  current_timestamp() as created_at
