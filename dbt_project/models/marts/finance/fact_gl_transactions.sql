{{
    config(
        materialized='incremental',
        unique_key='gl_transaction_id',
        cluster_by=['transaction_date'],
        incremental_strategy='merge'
    )
}}

-- Atomic fact. Grain: one row per GL journal line. Additive measure: amount
-- (signed — debit positive, credit negative; every journal_entry_id's lines
-- sum to zero, see tests/assert_gl_journal_entries_balance.sql). Payroll
-- postings carry source_system = 'PAYROLL' and source_reference =
-- 'PAYROLL-<pay_period_end_date>', the join key back to fact_pay for
-- reconciliation.

with gl_transactions as (

    select * from {{ ref('stg_workday__gl_transactions') }}

    {% if is_incremental() %}
        where _fivetran_synced > (
            select coalesce(max(_fivetran_synced), '1900-01-01')
            from {{ this }}
        )
    {% endif %}

),

gl_accounts as (

    select * from {{ ref('dim_gl_account') }}

),

cost_centers as (

    select * from {{ ref('dim_cost_center') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key([
            'gl_transactions.gl_transaction_id'
        ]) }}
            as gl_transaction_key,
        gl_transactions.gl_transaction_id,
        gl_transactions.journal_entry_id,
        gl_transactions.gl_account_id,
        gl_accounts.account_name,
        gl_accounts.account_type,
        gl_transactions.cost_center_id,
        cost_centers.department_id,
        cost_centers.department_name,
        gl_transactions.transaction_date,
        {{ dbt_utils.generate_surrogate_key([
            'gl_transactions.transaction_date'
        ]) }}
            as date_key,
        gl_transactions.amount,
        gl_transactions.source_system,
        gl_transactions.source_reference,
        gl_transactions.description,
        gl_transactions._fivetran_synced
    from gl_transactions
    left join gl_accounts
        on gl_transactions.gl_account_id = gl_accounts.gl_account_id
    left join cost_centers
        on gl_transactions.cost_center_id = cost_centers.cost_center_id

)

select * from final
