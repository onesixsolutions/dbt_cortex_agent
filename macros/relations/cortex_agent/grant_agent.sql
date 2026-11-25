-- Builds the GRANT ... ON AGENT statements for the `agent_grants` config.
-- Returns a LIST of SQL strings; the materialization executes each one as its own statement.
--
-- Agent privileges: USAGE (run the agent), MONITOR (view threads, logs and traces; also
-- required to run and read evaluations), MODIFY (alter or drop the agent).
-- Args:
--   relation : the target relation object (database, schema, identifier)
--   grants   : a list of grantees (each gets USAGE) or a map of privilege -> grantees.
--              See macros/utils/grants.sql for the accepted forms.
{% macro snowflake__grant_cortex_agent_usage(relation, grants) %}
  {%- set _relation_name = relation.database ~ '.' ~ relation.schema ~ '.' ~ relation.identifier -%}
  {{ return(dbt_cortex_agent.get_grant_statements('agent', _relation_name, grants, 'agent_grants')) }}
{% endmacro %}
