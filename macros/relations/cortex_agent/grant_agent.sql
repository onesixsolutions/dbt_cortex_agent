-- Builds the GRANT USAGE ON AGENT statements for each role in the grants list.
-- Called by the cortex_agent materialization when the `agent_grants` config is set.
-- Returns a LIST of SQL strings, one per role. The materialization executes each one as its
-- own statement: sending several `;`-separated statements in a single call relies on
-- dbt-snowflake's client-side statement splitting, which is not guaranteed on every engine.
-- Args:
--   relation : the target relation object (database, schema, identifier)
--   roles    : list of role names to grant USAGE to
{% macro snowflake__grant_cortex_agent_usage(relation, roles) %}
  {%- set _relation_name = relation.database ~ '.' ~ relation.schema ~ '.' ~ relation.identifier -%}
  {%- set _statements = [] -%}
  {%- for role in roles -%}
    {%- do _statements.append('grant usage on agent ' ~ _relation_name ~ ' to role ' ~ role) -%}
  {%- endfor -%}
  {{ return(_statements) }}
{% endmacro %}
