-- Singular test: every journal entry's lines must sum to zero (debit
-- positive, credit negative — standard double-entry bookkeeping).
-- dbt convention: a singular test should return ZERO rows to pass.

select
    journal_entry_id,
    sum(amount) as journal_entry_total
from {{ ref('fact_gl_transactions') }}
group by journal_entry_id
having abs(sum(amount)) > 0.01
