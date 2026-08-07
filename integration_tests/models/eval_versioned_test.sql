{{
    config(
        materialized='cortex_agent_evaluation',
        run_on_build=false,
        tags=['integration', 'eval']
    )
}}
{#
  Version-controlled evaluation for cortex_agent_versioned_test.
  The ref(...) calls below both resolve to fully-qualified names AND wire this eval into the
  dbt DAG, so it is re-deployed after the agent and dataset on every run.
  run_on_build=false: `dbt run` only keeps this config in sync on the stage (free); trigger an
  actual (paid) run with run_on_build=true or by calling EXECUTE_AI_EVALUATION('START').
  Use Jinja comments (not SQL `--`) for prose here: `--` is not a YAML comment and would be
  written verbatim into the config file, breaking the eval YAML parser.
#}
dataset:
  dataset_type: "CORTEX AGENT"
  table_name: "{{ ref('eval_dataset_versioned_test') }}"
  dataset_name: "EVAL_DATASET_VERSIONED_TEST"
  column_mapping:
    query_text: "query_text"
    ground_truth: "ground_truth"

evaluation:
  agent_params:
    agent_name: "{{ ref('cortex_agent_versioned_test') }}"
    agent_type: "CORTEX AGENT"
  source_metadata:
    type: "dataset"
    dataset_name: "EVAL_DATASET_VERSIONED_TEST"

metrics:
  - answer_correctness
