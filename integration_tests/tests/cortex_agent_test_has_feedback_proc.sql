-- Fails if the SUBMIT_FEEDBACK stored procedure was not created by the materialization.
-- Returns 0 rows on success (standard dbt test contract).

select 'CORTEX_AGENT_TEST_SUBMIT_FEEDBACK procedure not found' as error
where not exists (
  select 1
  from {{ target.database }}.information_schema.procedures
  where procedure_schema = '{{ target.schema }}_INTEGRATION_TESTS'
    and procedure_name   = 'CORTEX_AGENT_TEST_SUBMIT_FEEDBACK'
)
