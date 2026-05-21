{{ config(materialized='semantic_view') }}

-- Minimal semantic view used as a tool_resource in cortex_agent_full.
-- Requires the dbt_semantic_view package.
TABLES(t AS {{ ref('base_table') }})
DIMENSIONS(t.id, t.description)
METRICS(total_amount AS SUM(t.amount))
