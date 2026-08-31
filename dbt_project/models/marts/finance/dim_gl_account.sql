{{ config(materialized='table') }}

-- Conformed dimension, SCD Type 1 (overwrite). Grain: one row per GL account.

select
    gl_account_id,
    account_name,
    account_type,
    account_category
from {{ ref('stg_workday__ledger_accounts') }}
