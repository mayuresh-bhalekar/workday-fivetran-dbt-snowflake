{{
    config(
        materialized='incremental',
        unique_key='pay_result_id',
        cluster_by=['pay_period_end_date'],
        incremental_strategy='merge'
    )
}}

-- Atomic fact. Grain: one row per worker per pay period per
-- earning/deduction code.
-- Additive measure: amount (signed — earnings positive, deductions negative).

with pay_results as (

    select * from {{ ref('stg_workday__pay_results') }} as src

    {% if is_incremental() %}
        where src._fivetran_synced > (
            select coalesce(max(this_tbl._fivetran_synced), '1900-01-01')
            from {{ this }} as this_tbl
        )
    {% endif %}

),

dim_employee_current as (

    select * from {{ ref('dim_employee') }}
    where is_current

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['pay_results.pay_result_id']) }}
            as pay_key,
        pay_results.pay_result_id,
        pay_results.employee_id,
        dim_employee_current.employee_key,
        pay_results.pay_period_end_date,
        {{ dbt_utils.generate_surrogate_key([
            'pay_results.pay_period_end_date'
        ]) }}
            as date_key,
        pay_results.pay_group_id,
        pay_results.earning_deduction_code,
        pay_results.code_type,
        {{ signed_amount('pay_results.amount', 'pay_results.code_type') }}
            as amount,
        pay_results._fivetran_synced
    from pay_results
    left join dim_employee_current
        on pay_results.employee_id = dim_employee_current.employee_id

)

select * from final
