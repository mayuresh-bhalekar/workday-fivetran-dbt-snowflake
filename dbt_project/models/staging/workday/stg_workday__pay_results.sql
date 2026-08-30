with source as (

    select * from {{ source('workday', 'workday_pay_results') }}
    where not coalesce(_fivetran_deleted, false)

),

renamed as (

    select
        pay_result_id,
        employee_id,
        pay_period_end_date,
        pay_group_id,
        code as earning_deduction_code,
        code_type,
        amount,
        _fivetran_synced
    from source

)

select * from renamed
