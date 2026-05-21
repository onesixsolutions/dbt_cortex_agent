{{- config(materialized='table') -}}

-- Minimal base table used by test_semantic_view in the integration test suite.
select
    1    as id,
    'test row' as description,
    100.00 as amount
