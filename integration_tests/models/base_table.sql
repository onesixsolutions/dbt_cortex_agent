{{- config(
    materialized='table',
    alias='BASE_TABLE'
) -}}

-- Minimal base table used by test_semantic_view and test_search_service in the integration test suite.
select * from values
    (1, 'Revenue figures show strong growth in the enterprise segment last quarter.',      100.00),
    (2, 'Chargeback rates increased by 2% among small business clients in Q3.',           200.00),
    (3, 'Top client by revenue is Acme Corp with 1.2M in annual recurring revenue.',      300.00),
    (4, 'Integration test row for search indexing — safe to ignore in production.',        0.00)
  as t(id, description, amount)
