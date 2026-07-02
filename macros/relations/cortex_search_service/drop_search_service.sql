-- Generates DROP CORTEX SEARCH SERVICE DDL for a Snowflake Cortex Search Service.
-- Called by dbt internals when a cortex_search_service model is removed or replaced.
{% macro snowflake__get_drop_cortex_search_service_sql(relation) %}

  drop cortex search service if exists
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}

{% endmacro %}
