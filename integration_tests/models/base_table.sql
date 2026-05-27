{{- config(
    materialized='table',
    alias='BASE_TABLE',
    post_hook="create or replace cortex search service {{ this.database }}.{{ this.schema }}.TEST_SEARCH_SERVICE on description attributes id warehouse = {{ target.warehouse }} target_lag = '7 days' as (select id, description from {{ this }})"
) -}}

-- Minimal base table used by test_semantic_view and TEST_SEARCH_SERVICE in the integration test suite.
select * from values
    (1, 'Revenue figures show strong growth in the enterprise segment last quarter.',      100.00),
    (2, 'Chargeback rates increased by 2% among small business clients in Q3.',           200.00),
    (3, 'Top client by revenue is Acme Corp with 1.2M in annual recurring revenue.',      300.00),
    (4, 'Integration test row for search indexing — safe to ignore in production.',        0.00)
  as t(id, description, amount)
