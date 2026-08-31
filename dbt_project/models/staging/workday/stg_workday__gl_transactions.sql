with source as (

    select * from {{ source('workday', 'workday_gl_transactions') }}
    where not coalesce(_fivetran_deleted, false)

),

renamed as (

    select
        gl_transaction_id,
        journal_entry_id,
        gl_account_id,
        cost_center_id,
        transaction_date,
        amount,
        source_system,
        source_reference,
        description,
        _fivetran_synced
    from source

)

select * from renamed
