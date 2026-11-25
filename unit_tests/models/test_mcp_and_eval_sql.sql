{{ config(materialized='view') }}
{#- DDL generated for MCP servers and agent evaluations. -#}
{% if execute %}
{%- set rel = test_relation() -%}

-- MCP server
{{ assert_sql('mcp: create or replace from specification',
    dbt_cortex_agent.snowflake__create_mcp_server(rel, 'tools:\n  - name: "t"'),
    'create or replace mcp server DB.SCH.OBJ from specification $$ tools: - name: "t" $$') }}
{{ assert_contains('mcp: the spec is trimmed and starts at column 0',
    dbt_cortex_agent.snowflake__create_mcp_server(rel, '\n\ntools:\n  - name: "t"\n\n'),
    '$$\ntools:\n  - name: "t"\n  $$') }}
{{ assert_sql('mcp: drop', dbt_cortex_agent.snowflake__get_drop_mcp_server_sql(rel), 'drop mcp server if exists DB.SCH.OBJ') }}

-- evaluations
{{ assert_sql('eval: stage is created idempotently with a directory table',
    dbt_cortex_agent.snowflake__create_eval_config_stage('DB.SCH.CORTEX_EVAL_CONFIGS'),
    'create stage if not exists DB.SCH.CORTEX_EVAL_CONFIGS directory = (enable = true)') }}
{{ assert_sql('eval: config is unloaded verbatim as a single uncompressed file',
    dbt_cortex_agent.snowflake__write_eval_config('DB.SCH.STG', 'my_eval.yaml', 'metrics:\n  - answer_correctness'),
    'copy into @DB.SCH.STG/my_eval.yaml from (select $$metrics: - answer_correctness$$) file_format = ( type = csv compression = none field_optionally_enclosed_by = none escape_unenclosed_field = none ) single = true overwrite = true header = false max_file_size = 67108864') }}
{{ assert_contains('eval: inner YAML indentation and newlines are preserved, outer whitespace trimmed',
    dbt_cortex_agent.snowflake__write_eval_config('DB.SCH.STG', 'my_eval.yaml', '\n\nmetrics:\n  - answer_correctness\n\n'),
    '(select $$metrics:\n  - answer_correctness$$)') }}
{{ assert_sql('eval: start call',
    dbt_cortex_agent.snowflake__execute_ai_evaluation('run_2026', '@DB.SCH.STG/my_eval.yaml'),
    "call execute_ai_evaluation( 'START', object_construct('run_name', 'run_2026'), '@DB.SCH.STG/my_eval.yaml' )") }}
{% endif %}
select 1 as ok
