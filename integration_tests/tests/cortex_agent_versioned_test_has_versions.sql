-- Verify the versioned agent has at least one committed named version.
-- A successful auto_commit produces VERSION$1 on first run and increments on each subsequent run.
-- Returns 0 rows on success (standard dbt test contract).

select 'no committed versions found for cortex_agent_versioned_test' as error
where (select count(*) from {{ ref('cortex_agent_versioned_test_versions') }}) < 1
