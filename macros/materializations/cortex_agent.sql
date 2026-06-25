-- Custom dbt materialization for Snowflake Cortex Agents.
-- The model body must be a valid Snowflake agent YAML specification.
-- The materialization wraps it in CREATE OR REPLACE AGENT ... FROM SPECIFICATION $$ ... $$.
--
-- Config options:
--   comment (string, optional)        : agent-level comment visible in Snowflake
--   profile (string, optional)        : JSON object with display_name, avatar, and color
--   agent_grants (list, optional)     : list of role names to grant USAGE on the agent
--   create_feedback_table (bool, optional) : whether to create the feedback table and procedure.
--                                            Defaults to false. Set to true to enable.
--   feedback_schema (string, optional) : schema for the feedback table and AGENT_SUBMIT_FEEDBACK
--                                        procedure. Accepts 'SCHEMA' or 'DB.SCHEMA'. Defaults to
--                                        the agent's own database and schema.
--   feedback_table (string, optional) : fully-qualified override for the feedback table name.
--                                       Defaults to {feedback_schema}.AGENT_FEEDBACK.
--                                       Creates the table (if absent) and a stored procedure
--                                       named AGENT_SUBMIT_FEEDBACK on every dbt run.
--   feedback_execute_as (string, optional) : execution rights for the AGENT_SUBMIT_FEEDBACK procedure.
--                                            Accepts 'caller' (default) or 'owner'.
--                                            Use 'caller' to capture the end user via current_user().
--                                            Use 'owner' if the calling role lacks INSERT on the feedback table.
--   enable_versioning (bool, optional) : opt into Snowflake agent versioning. Defaults to true.
--                                        When true, uses CREATE AGENT IF NOT EXISTS + ALTER AGENT
--                                        MODIFY LIVE VERSION instead of CREATE OR REPLACE AGENT,
--                                        preserving version history across runs.
--                                        Set to false in dev environments to skip versioning overhead.
--                                        dbt run --full-refresh falls back to CREATE OR REPLACE,
--                                        resetting all version history.
--   auto_commit (bool, optional)      : when enable_versioning=true, automatically snapshot the
--                                       LIVE version into a new named version after each run.
--                                       Defaults to true. Set to false to accumulate changes in
--                                       LIVE without committing, then commit manually.
--   version_comment (string, optional) : comment attached to the committed version snapshot.
--                                        Only used when enable_versioning=true and auto_commit=true.

{% materialization cortex_agent, adapter='snowflake' %}

  {%- set comment                = config.get('comment', default=none) -%}
  {%- set profile                = config.get('profile', default=none) -%}
  {%- set agent_grants           = config.get('agent_grants', default=[]) -%}
  {%- set create_feedback_table  = config.get('create_feedback_table', default=false) -%}
  {%- set feedback_schema_config = config.get('feedback_schema', default=none) -%}
  {%- set feedback_table         = config.get('feedback_table', default=none) -%}
  {%- set feedback_execute_as    = config.get('feedback_execute_as', default='caller') -%}
  {%- set enable_versioning      = config.get('enable_versioning', default=true) -%}
  {%- set auto_commit            = config.get('auto_commit', default=true) -%}
  {%- set version_comment        = config.get('version_comment', default=none) -%}

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
    {{ dbt_cortex_agent.snowflake__create_feedback_procedure(feedback_db, feedback_schema, feedback_table, feedback_execute_as) }}
  {% endcall %}
  {%- endif %}

  {%- if enable_versioning and not should_full_refresh() %}

  {# Determine whether any committed versions exist.
     On first run (agent absent or no committed versions) skip MODIFY LIVE VERSION —
     the LIVE working copy does not exist until after the first COMMIT.
     On subsequent runs COMMIT has already established LIVE, so we can update it. #}
  {%- set _show_agents_sql -%}
    SHOW AGENTS LIKE '{{ target_relation.identifier }}' IN SCHEMA {{ target_relation.database }}.{{ target_relation.schema }}
  {%- endset -%}
  {%- set _agent_rows = run_query(_show_agents_sql) -%}
  {%- set _has_committed_versions = false -%}
  {%- if _agent_rows | length > 0 -%}
    {%- set _show_versions_sql -%}
      SHOW VERSIONS IN AGENT {{ target_relation.database }}.{{ target_relation.schema }}.{{ target_relation.identifier }}
    {%- endset -%}
    {%- set _version_rows = run_query(_show_versions_sql) -%}
    {%- set _has_committed_versions = (_version_rows | length) > 0 -%}
  {%- endif -%}

  {% call statement('main') %}
    {{ dbt_cortex_agent.snowflake__create_cortex_agent_if_not_exists(target_relation, sql, comment, profile) }}
  {% endcall %}

  {%- if _has_committed_versions %}
  {# COMMIT consumes LIVE and does not recreate it. Explicitly restore LIVE from the
     last committed version before modifying, so MODIFY LIVE VERSION has a target. #}
  {% call statement('add_live') %}
    {{ dbt_cortex_agent.snowflake__add_cortex_agent_live_version(target_relation) }}
  {% endcall %}
  {%- endif %}

  {% call statement('update_live') %}
    {{ dbt_cortex_agent.snowflake__alter_cortex_agent_live_spec(target_relation, sql) }}
  {% endcall %}

  {%- if auto_commit %}
  {% call statement('commit_version') %}
    {{ dbt_cortex_agent.snowflake__commit_cortex_agent_version(target_relation, version_comment) }}
  {% endcall %}
  {%- endif %}

  {%- else %}

  {% call statement('main') %}
    {{ dbt_cortex_agent.snowflake__create_cortex_agent(target_relation, sql, comment, profile) }}
  {% endcall %}

  {%- endif %}

  {{ run_hooks(post_hooks) }}

  {%- if agent_grants | length > 0 %}
  {% call statement('grants') %}
    {{ dbt_cortex_agent.snowflake__grant_cortex_agent_usage(target_relation, agent_grants) }}
  {% endcall %}
  {%- endif %}

  {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}
