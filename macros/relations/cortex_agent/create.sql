-- Copyright 2025 OneSix Solutions
-- SPDX-License-Identifier: Apache-2.0

{% macro snowflake__create_cortex_agent(relation, specification, comment, profile) %}

  create or replace agent
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}
  {%- if comment is not none %}
  comment = '{{ comment }}'
  {%- endif %}
  {%- if profile is not none %}
  profile = '{{ profile }}'
  {%- endif %}
  from specification
  $$
  {{ specification }}
  $$

{% endmacro %}
