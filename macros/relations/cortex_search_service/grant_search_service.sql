-- Generates GRANT USAGE ON CORTEX SEARCH SERVICE DDL for each role in the grants list.
-- Called by the cortex_search_service materialization when the `search_service_grants` config is set.
-- Args:
--   relation : the target relation object (database, schema, identifier)
--   roles    : list of role names to grant USAGE to
{% macro snowflake__grant_cortex_search_service_usage(relation, roles) %}
  {%- for role in roles %}
  grant usage on cortex search service
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}
  to role {{ role }};
  {%- endfor %}
{% endmacro %}
