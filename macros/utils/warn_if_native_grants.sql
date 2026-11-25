-- Warns when a model sets dbt's native `grants` config.
--
-- dbt applies native grants through the adapter, which only knows how to grant on tables and
-- views. Agents, MCP servers and Cortex Search Services are different object types with their
-- own GRANT ... ON <type> syntax, so these materializations do not apply the native config:
-- left unremarked, a `grants:` block on one of these models would look configured and do
-- nothing. The package's own option is named in the warning.
{% macro warn_if_native_grants(option_name) %}
  {%- if config.get('grants', default=none) -%}
    {%- do exceptions.warn("Model " ~ model.name ~ " sets dbt's native `grants` config, which this materialization does not apply. Use the `" ~ option_name ~ "` option under `meta` instead (see the dbt_cortex_agent README, \"Grants\").") -%}
  {%- endif -%}
{% endmacro %}
