-- depends_on: {{ ref('cortex_agent_test') }}
-- Fails if the AGENT_SUBMIT_FEEDBACK stored procedure was not created by the materialization,
-- or if the feedback_execute_as='owner' override was not applied.
-- Returns 0 rows on success (standard dbt test contract).

select 'AGENT_SUBMIT_FEEDBACK procedure not found' as error
where not exists (
  select 1
  from {{ target.database }}.information_schema.procedures
  where procedure_schema = '{{ target.schema }}_INTEGRATION_TESTS'
    and procedure_name   = 'AGENT_SUBMIT_FEEDBACK'
)

union all

select 'AGENT_SUBMIT_FEEDBACK procedure execute_as is not OWNER' as error
where exists (
  select 1
  from {{ target.database }}.information_schema.procedures
  where procedure_schema = '{{ target.schema }}_INTEGRATION_TESTS'
    and procedure_name   = 'AGENT_SUBMIT_FEEDBACK'
)
and not (
  get_ddl(
    'procedure',
    '{{ target.database }}.{{ target.schema }}_INTEGRATION_TESTS.AGENT_SUBMIT_FEEDBACK(VARCHAR, NUMBER, VARCHAR, VARCHAR)'
  ) ilike '%execute as owner%'
)
