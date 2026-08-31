with source as (

    select * from {{ source('workday', 'workday_ledger_accounts') }}
    where not coalesce(_fivetran_deleted, false)

),

renamed as (

    select
        gl_account_id,
        account_name,
        account_type,
        account_category,
        _fivetran_synced
    from source

)

select * from renamed
