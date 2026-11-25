-- cortex_agent_copy_grants_test is replaced on every run and grants nothing itself. Its
-- post-hook grants MONITOR on a first run only, so after a second run
-- (--vars '{second_run: true}') the grant can only still exist if COPY GRANTS carried it
-- across the CREATE OR REPLACE. See the model for details.
-- Returns 0 rows on success (standard dbt test contract).

{{ expect_grant(ref('cortex_agent_copy_grants_test_grants'), 'monitor', 'dbt_demo_role', 'cortex_agent_copy_grants_test') }}
