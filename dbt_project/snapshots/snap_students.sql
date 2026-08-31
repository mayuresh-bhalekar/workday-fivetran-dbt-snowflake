{% snapshot snap_students %}

{{
    config(
        target_schema='snapshots',
        unique_key='student_id',
        strategy='timestamp',
        updated_at='source_last_modified',
        invalidate_hard_deletes=True,
    )
}}

-- SCD Type 2 on the Student record: captures enrollment-status and program
-- changes over time (Active -> Withdrawn/Graduated, program transfers) so
-- fact_enrollment can be joined to "the dim_student row that was true as of
-- that registration date" rather than only the current state. Run
-- `dbt snapshot` on a schedule immediately after each Fivetran sync.

    select * from {{ ref('stg_workday__students') }}

{% endsnapshot %}
