-- Copyright 2025 OneSix Solutions
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- Generates and executes CREATE OR REPLACE AGENT DDL for a Snowflake Cortex Agent.
-- Called by the cortex_agent materialization on every dbt run.
-- Args:
--   relation      : the target relation object (database, schema, identifier)
--   specification : compiled YAML agent spec from the model body
--   comment       : optional agent description shown in Snowflake
--   profile       : optional JSON string for display_name, avatar, and color
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
