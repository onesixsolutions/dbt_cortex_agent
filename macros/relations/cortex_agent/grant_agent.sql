-- Generates GRANT USAGE ON AGENT DDL for each role in the grants list.
-- Called by the cortex_agent materialization when the `grants` config is set.
-- Args:
--   relation : the target relation object (database, schema, identifier)
--   roles    : list of role names to grant USAGE to
{% macro snowflake__grant_cortex_agent_usage(relation, roles) %}
  {%- for role in roles %}
  grant usage on agent
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}
  to role {{ role }};
  {%- endfor %}
{% endmacro %}
