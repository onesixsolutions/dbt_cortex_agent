-- Custom dbt materialization for Snowflake Cortex Agent evaluations (AI Observability).
--
-- The model body must be a valid AI-evaluation run-configuration YAML: the `dataset`,
-- `evaluation`, and `metrics` blocks accepted by EXECUTE_AI_EVALUATION. Use {{ ref(...) }}
-- for `dataset.table_name` and `evaluation.agent_params.agent_name` so the eval config is
-- wired into the dbt DAG — it is always (re)deployed AFTER its agent and dataset. This is
-- how an evaluation is "version-controlled and applied to an agent": the config lives in
-- git and is re-materialised on every deploy, including after a --full-refresh of the agent.
-- NOTE: EXECUTE_AI_EVALUATION requires `dataset_name` under the `dataset:` block itself
-- (in addition to evaluation.source_metadata.dataset_name), else it errors "Null dataset_name".
--
-- On every `dbt run` the materialization (idempotently):
--   1. Ensures a stage exists to hold eval-config YAML files.
--   2. Writes the compiled model body to that stage as <model>.yaml (verbatim, via the
--      COPY INTO single-file unload trick).
-- If run_on_build=true it additionally starts an evaluation run via
-- EXECUTE_AI_EVALUATION('START', ...).
--
-- COST: eval runs consume Cortex credits (the agent is invoked once per dataset row and an
-- LLM judge scores each metric per row). run_on_build therefore defaults to FALSE — a normal
-- `dbt run` only keeps the versioned config in sync (free); you trigger paid runs deliberately
-- (e.g. `dbt run --select tag:eval --vars '{eval_run: true}'`, or set run_on_build=true).
--
-- Config options:
--   stage (string, optional)     : fully-qualified stage that holds the config files.
--                                  Defaults to {database}.{schema}.CORTEX_EVAL_CONFIGS.
--   run_on_build (bool, optional): start an eval run on every dbt run. Defaults to false.
--   run_name (string, optional)  : eval run name. Defaults to <model>_<run-start timestamp>.
--                                  Run names should be unique per run; the default timestamp
--                                  keeps them so.

{% materialization cortex_agent_evaluation, adapter='snowflake' %}

  {%- set stage        = config.get('stage', default=none) -%}
  {%- set run_on_build = config.get('run_on_build', default=false) -%}
  {%- set run_name     = config.get('run_name', default=none) -%}

  -- dbt has no native 'evaluation' relation type. 'view' is a graph-tracking placeholder
  -- only — the materialization never creates a view; it writes a config file to a stage.
  {%- set target_relation = api.Relation.create(
      identifier=this.identifier,
      schema=this.schema,
      database=this.database,
      type='view'
  ) -%}

  {%- if stage is none -%}
    {%- set stage = target_relation.database ~ '.' ~ target_relation.schema ~ '.CORTEX_EVAL_CONFIGS' -%}
  {%- endif -%}
  {%- set config_file = target_relation.identifier ~ '.yaml' -%}
  {%- set stage_path  = '@' ~ stage ~ '/' ~ config_file -%}

  {%- if run_name is none -%}
    {%- set run_name = target_relation.identifier ~ '_' ~ run_started_at.strftime('%Y%m%d_%H%M%S') -%}
  {%- endif -%}

  {{ run_hooks(pre_hooks) }}

  {% call statement('create_stage') %}
    {{ dbt_cortex_agent.snowflake__create_eval_config_stage(stage) }}
  {% endcall %}

  {# 'main' is required by dbt's materialization framework; the config write is our main op. #}
  {% call statement('main') %}
    {{ dbt_cortex_agent.snowflake__write_eval_config(stage, config_file, sql) }}
  {% endcall %}

  {%- if run_on_build %}
  {% call statement('start_eval') %}
    {{ dbt_cortex_agent.snowflake__execute_ai_evaluation(run_name, stage_path) }}
  {% endcall %}
  {%- endif %}

  {{ run_hooks(post_hooks) }}

  {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}
