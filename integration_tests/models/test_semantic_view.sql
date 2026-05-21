{{ config(materialized='semantic_view') }}

-- Minimal semantic view used as a tool_resource in cortex_agent_test.
-- Requires the dbt_semantic_view package.
TABLES(t AS {{ ref('base_table') }})
DIMENSIONS(t.id AS id, t.description AS description)
METRICS(t.amount AS SUM(t.amount))
