-- Builds the GRANT USAGE ON CORTEX SEARCH SERVICE statements for each role in the grants list.
-- Called by the cortex_search_service materialization when the `search_service_grants` config is set.
-- Returns a LIST of SQL strings, one per role; the materialization executes each one as its
-- own statement (see snowflake__grant_cortex_agent_usage for why).
-- Args:
--   relation : the target relation object (database, schema, identifier)
--   roles    : list of role names to grant USAGE to
{% macro snowflake__grant_cortex_search_service_usage(relation, roles) %}
  {%- set _relation_name = relation.database ~ '.' ~ relation.schema ~ '.' ~ relation.identifier -%}
  {%- set _statements = [] -%}
  {%- for role in roles -%}
    {%- do _statements.append('grant usage on cortex search service ' ~ _relation_name ~ ' to role ' ~ role) -%}
  {%- endfor -%}
  {{ return(_statements) }}
{% endmacro %}
