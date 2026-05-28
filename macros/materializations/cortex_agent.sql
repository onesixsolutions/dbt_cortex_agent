-- Custom dbt materialization for Snowflake Cortex Agents.
-- The model body must be a valid Snowflake agent YAML specification.
-- The materialization wraps it in CREATE OR REPLACE AGENT ... FROM SPECIFICATION $$ ... $$.
--
-- Config options:
--   comment (string, optional)        : agent-level comment visible in Snowflake
--   profile (string, optional)        : JSON object with display_name, avatar, and color
--   agent_grants (list, optional)     : list of role names to grant USAGE on the agent
--   create_feedback_table (bool, optional) : whether to create the feedback table and procedure.
--                                            Defaults to true. Set to false to skip.
--   feedback_schema (string, optional) : schema for the feedback table and AGENT_SUBMIT_FEEDBACK
--                                        procedure. Accepts 'SCHEMA' or 'DB.SCHEMA'. Defaults to
--                                        the agent's own database and schema.
--   feedback_table (string, optional) : fully-qualified override for the feedback table name.
--                                       Defaults to {feedback_schema}.AGENT_FEEDBACK.
--                                       Creates the table (if absent) and a stored procedure
--                                       named AGENT_SUBMIT_FEEDBACK on every dbt run.

{% materialization cortex_agent, adapter='snowflake' %}

  {%- set comment                = config.get('comment', default=none) -%}
  {%- set profile                = config.get('profile', default=none) -%}
  {%- set agent_grants           = config.get('agent_grants', default=[]) -%}
  {%- set create_feedback_table  = config.get('create_feedback_table', default=true) -%}
  {%- set feedback_schema_config = config.get('feedback_schema', default=none) -%}
  {%- set feedback_table         = config.get('feedback_table', default=none) -%}

  {%- set target_relation = api.Relation.create(
      identifier=this.identifier,
      schema=this.schema,
      database=this.database,
      type='view'
  ) -%}

  {%- if feedback_schema_config is not none -%}
    {%- set _parts = feedback_schema_config.split('.') -%}
    {%- if _parts | length == 2 -%}
      {%- set feedback_db     = _parts[0] -%}
      {%- set feedback_schema = _parts[1] -%}
    {%- else -%}
      {%- set feedback_db     = target_relation.database -%}
      {%- set feedback_schema = feedback_schema_config -%}
    {%- endif -%}
  {%- else -%}
    {%- set feedback_db     = target_relation.database -%}
    {%- set feedback_schema = target_relation.schema -%}
  {%- endif -%}

  {%- if create_feedback_table and feedback_table is none -%}
    {%- set feedback_table = feedback_db ~ '.' ~ feedback_schema ~ '.AGENT_FEEDBACK' -%}
  {%- endif -%}

  {{ run_hooks(pre_hooks) }}

  {%- if create_feedback_table and feedback_table is not none %}
  {% call statement('feedback_table') %}
    {{ dbt_cortex_agent.snowflake__create_feedback_table(feedback_table) }}
  {% endcall %}

  {% call statement('feedback_procedure') %}
    {{ dbt_cortex_agent.snowflake__create_feedback_procedure(feedback_db, feedback_schema, feedback_table) }}
  {% endcall %}
  {%- endif %}

  {% call statement('main') %}
    {{ dbt_cortex_agent.snowflake__create_cortex_agent(target_relation, sql, comment, profile) }}
  {% endcall %}

  {{ run_hooks(post_hooks) }}

  {%- if agent_grants | length > 0 %}
  {% call statement('grants') %}
    {{ dbt_cortex_agent.snowflake__grant_cortex_agent_usage(target_relation, agent_grants) }}
  {% endcall %}
  {%- endif %}

  {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}
