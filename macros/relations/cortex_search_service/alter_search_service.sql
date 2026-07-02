-- Generates and executes ALTER CORTEX SEARCH SERVICE ... SET DDL, updating the mutable
-- properties of an existing Cortex Search Service in place without rebuilding its index.
-- Called by the cortex_search_service materialization on every run after the first,
-- as long as --full-refresh was not passed.
--
-- Emits one full ALTER statement per configured property (e.g.
-- `alter cortex search service if exists <name> set target_lag = '1 hour';`) rather
-- than combining multiple scalar properties into a single SET clause — Snowflake
-- rejected a combined `SET target_lag = ... warehouse = ... comment = ...` clause with
-- a syntax error on the first property, while the single-property form matches
-- Snowflake's own documented examples. Multiple `;`-separated statements in one macro
-- call is the same pattern already used by snowflake__grant_cortex_agent_usage for
-- multi-role grants.
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
  {%- set _relation_name = relation.database ~ '.' ~ relation.schema ~ '.' ~ relation.identifier -%}
  {%- if target_lag is not none %}
  alter cortex search service if exists {{ _relation_name }} set target_lag = '{{ target_lag }}';
  {%- endif %}
  {%- if warehouse is not none %}
  alter cortex search service if exists {{ _relation_name }} set warehouse = {{ warehouse }};
  {%- endif %}
  {%- if full_index_build_interval_days is not none %}
  alter cortex search service if exists {{ _relation_name }} set full_index_build_interval_days = {{ full_index_build_interval_days }};
  {%- endif %}
  {%- if request_logging is not none %}
  alter cortex search service if exists {{ _relation_name }} set request_logging = {{ request_logging | lower }};
  {%- endif %}
  {%- if auto_suspend is not none %}
  alter cortex search service if exists {{ _relation_name }} set auto_suspend = {{ auto_suspend }};
  {%- endif %}
  {%- if comment is not none %}
  alter cortex search service if exists {{ _relation_name }} set comment = '{{ comment }}';
  {%- endif %}
  {%- if primary_key is not none and primary_key | length > 0 %}
  alter cortex search service if exists {{ _relation_name }} set primary key = ({{ primary_key | join(', ') }});
  {%- endif %}
  {%- if attributes is not none and attributes | length > 0 %}
  alter cortex search service if exists {{ _relation_name }} set attributes ({{ attributes | join(', ') }});
  {%- endif %}
{% endmacro %}
