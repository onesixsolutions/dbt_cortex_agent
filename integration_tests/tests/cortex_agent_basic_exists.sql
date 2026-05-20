-- Copyright 2025 OneSix Solutions
-- SPDX-License-Identifier: Apache-2.0
--
-- Fails if the basic agent does not exist in Snowflake.
-- GET_DDL raises an error if the object doesn't exist, causing the test to fail.
-- Returns 0 rows on success (standard dbt test contract).

select 'agent does not exist' as error
where (
  select length(
    get_ddl(
      'agent',
      '{{ target.database }}.{{ target.schema }}_INTEGRATION_TESTS.CORTEX_AGENT_BASIC'
    )
  )
) = 0
