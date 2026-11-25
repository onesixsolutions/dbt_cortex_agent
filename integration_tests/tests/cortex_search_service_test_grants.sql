-- test_search_service sets search_service_grants=['dbt_demo_role'] (list form => USAGE).
-- Returns 0 rows on success (standard dbt test contract).

{{ expect_grant(ref('test_search_service_grants'), 'usage', 'dbt_demo_role', 'test_search_service') }}
