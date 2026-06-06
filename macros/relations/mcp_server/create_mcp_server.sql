-- Generates and executes CREATE OR REPLACE MCP SERVER DDL for a Snowflake MCP Server.
-- Called by the mcp_server materialization on every dbt run.
-- Args:
--   relation      : the target relation object (database, schema, identifier)
--   specification : compiled YAML MCP server spec from the model body
{% macro snowflake__create_mcp_server(relation, specification) %}

  create or replace mcp server
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}
  from specification
  $$
{{ specification | trim }}
  $$

{% endmacro %}
