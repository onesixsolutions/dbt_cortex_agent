-- Builds the GRANT USAGE ON MCP SERVER statements for each role in the grants list.
-- Called by the mcp_server materialization when the `mcp_server_grants` config is set.
-- Returns a LIST of SQL strings, one per role; the materialization executes each one as its
-- own statement.
--
-- USAGE is what lets a role connect to the server, list its tools and call them. It does NOT
-- give access to the tools themselves: the role separately needs privileges on every object
-- a tool wraps (USAGE on the search service / agent / procedure, SELECT on the semantic view,
-- USAGE on the warehouse).
-- Args:
--   relation : the target relation object (database, schema, identifier)
--   roles    : list of role names to grant USAGE to
{% macro snowflake__grant_mcp_server_usage(relation, roles) %}
  {%- set _relation_name = relation.database ~ '.' ~ relation.schema ~ '.' ~ relation.identifier -%}
  {%- set _statements = [] -%}
  {%- for role in roles -%}
    {%- do _statements.append('grant usage on mcp server ' ~ _relation_name ~ ' to role ' ~ role) -%}
  {%- endfor -%}
  {{ return(_statements) }}
{% endmacro %}
