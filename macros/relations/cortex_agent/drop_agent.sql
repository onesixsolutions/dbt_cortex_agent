-- Generates DROP AGENT IF EXISTS DDL for a Snowflake Cortex Agent.
-- Called by dbt internals when a cortex_agent model is removed or replaced.
{% macro snowflake__get_drop_cortex_agent_sql(relation) %}

  drop agent if exists
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}

{% endmacro %}
