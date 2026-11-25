-- Builds the GRANT ... ON MCP SERVER statements for the `mcp_server_grants` config.
-- Returns a LIST of SQL strings; the materialization executes each one as its own statement.
--
-- MCP server privileges: USAGE (connect, list tools, call tools), MODIFY (describe or drop
-- the server, but not use it).
--
-- USAGE is what lets a role connect to the server, list its tools and call them. It does NOT
-- give access to the tools themselves: the role separately needs privileges on every object
-- a tool wraps (USAGE on the search service / agent / procedure, SELECT on the semantic view,
-- USAGE on the warehouse).
-- Args:
--   relation : the target relation object (database, schema, identifier)
--   grants   : a list of grantees (each gets USAGE) or a map of privilege -> grantees.
--              See macros/utils/grants.sql for the accepted forms.
{% macro snowflake__grant_mcp_server_usage(relation, grants) %}
  {%- set _relation_name = relation.database ~ '.' ~ relation.schema ~ '.' ~ relation.identifier -%}
  {{ return(dbt_cortex_agent.get_grant_statements('mcp server', _relation_name, grants, 'mcp_server_grants')) }}
{% endmacro %}
