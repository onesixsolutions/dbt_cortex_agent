-- Builds the GRANT ... ON CORTEX SEARCH SERVICE statements for the `search_service_grants` config.
-- Returns a LIST of SQL strings; the materialization executes each one as its own statement.
--
-- Search service privileges: USAGE (query the service), MONITOR (view refresh history),
-- OPERATE (suspend/resume, refresh, change warehouse and target lag).
-- Args:
--   relation : the target relation object (database, schema, identifier)
--   grants   : a list of grantees (each gets USAGE) or a map of privilege -> grantees.
--              See macros/utils/grants.sql for the accepted forms.
{% macro snowflake__grant_cortex_search_service_usage(relation, grants) %}
  {%- set _relation_name = relation.database ~ '.' ~ relation.schema ~ '.' ~ relation.identifier -%}
  {{ return(dbt_cortex_agent.get_grant_statements('cortex search service', _relation_name, grants, 'search_service_grants')) }}
{% endmacro %}
