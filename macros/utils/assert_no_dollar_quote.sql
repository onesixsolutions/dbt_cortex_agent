-- Fails compilation when a model body contains `$$`.
--
-- The agent, MCP server and evaluation materializations place the model body inside a
-- dollar-quoted string ($$ ... $$). A `$$` anywhere in the body ends that string early, and
-- Snowflake then reports a syntax error somewhere in the middle of the specification that
-- says nothing about the cause. Catching it here names the model and the reason.
{% macro assert_no_dollar_quote(body, materialization_name) %}
  {%- if '$$' in (body | string) -%}
    {{ exceptions.raise_compiler_error("Model " ~ model.name ~ " (" ~ materialization_name ~ "): the model body contains `$$`. The body is sent to Snowflake inside a $$ ... $$ dollar-quoted string, so it cannot contain `$$` itself. Remove it or write it another way (for example `$ $`).") }}
  {%- endif -%}
{% endmacro %}
