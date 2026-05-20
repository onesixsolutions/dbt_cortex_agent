-- Copyright 2025 OneSix Solutions
-- SPDX-License-Identifier: Apache-2.0

{% macro snowflake__get_drop_cortex_agent_sql(relation) %}

  drop agent if exists
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}

{% endmacro %}
