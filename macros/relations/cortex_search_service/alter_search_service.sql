-- Generates and executes ALTER CORTEX SEARCH SERVICE ... SET DDL, updating the mutable
-- properties of an existing Cortex Search Service in place without rebuilding its index.
-- Called by the cortex_search_service materialization on every run after the first,
-- as long as --full-refresh was not passed.
--
-- Returns a LIST of SQL strings: one full ALTER statement per configured property (e.g.
-- `alter cortex search service if exists <name> set target_lag = '1 hour'`) rather
-- than combining multiple scalar properties into a single SET clause — Snowflake
-- rejected a combined `SET target_lag = ... warehouse = ... comment = ...` clause with
-- a syntax error on the first property, while the single-property form matches
-- Snowflake's own documented examples. The materialization executes each statement on its
-- own rather than sending them `;`-separated in one call, which relies on dbt-snowflake's
-- client-side statement splitting and is not guaranteed on every engine.
--
-- PRIMARY KEY and ATTRIBUTES are each their own dedicated ALTER form per Snowflake's
-- syntax reference (not part of the general SET clause above), confirmed via docs:
--   ALTER CORTEX SEARCH SERVICE mysvc SET PRIMARY KEY = (region, agent_id);
--   ALTER CORTEX SEARCH SERVICE mysvc SET ATTRIBUTES (category, region);
--
-- Args mirror snowflake__create_cortex_search_service, minus the immutable properties
-- (search_column, embedding_model, refresh_mode, initialize, and the defining query itself)
-- which cannot be changed without CREATE OR REPLACE.
{% macro snowflake__alter_cortex_search_service(relation, attributes, warehouse, target_lag, primary_key, full_index_build_interval_days, request_logging, auto_suspend, comment) %}
  {%- set _prefix = 'alter cortex search service if exists ' ~ relation.database ~ '.' ~ relation.schema ~ '.' ~ relation.identifier ~ ' set ' -%}
  {%- set _statements = [] -%}
  {%- if target_lag is not none -%}
    {%- do _statements.append(_prefix ~ "target_lag = '" ~ target_lag ~ "'") -%}
  {%- endif -%}
  {%- if warehouse is not none -%}
    {%- do _statements.append(_prefix ~ 'warehouse = ' ~ warehouse) -%}
  {%- endif -%}
  {%- if full_index_build_interval_days is not none -%}
    {%- do _statements.append(_prefix ~ 'full_index_build_interval_days = ' ~ full_index_build_interval_days) -%}
  {%- endif -%}
  {%- if request_logging is not none -%}
    {%- do _statements.append(_prefix ~ 'request_logging = ' ~ (request_logging | lower)) -%}
  {%- endif -%}
  {%- if auto_suspend is not none -%}
    {%- do _statements.append(_prefix ~ 'auto_suspend = ' ~ auto_suspend) -%}
  {%- endif -%}
  {%- if comment is not none -%}
    {%- do _statements.append(_prefix ~ "comment = '" ~ dbt_cortex_agent.escape_string_literal(comment) ~ "'") -%}
  {%- endif -%}
  {%- if primary_key is not none and primary_key | length > 0 -%}
    {%- do _statements.append(_prefix ~ 'primary key = (' ~ (primary_key | join(', ')) ~ ')') -%}
  {%- endif -%}
  {%- if attributes is not none and attributes | length > 0 -%}
    {%- do _statements.append(_prefix ~ 'attributes (' ~ (attributes | join(', ')) ~ ')') -%}
  {%- endif -%}
  {{ return(_statements) }}
{% endmacro %}
