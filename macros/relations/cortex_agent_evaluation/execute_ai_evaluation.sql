-- Starts a Cortex Agent evaluation run from a config YAML already written to a stage.
-- Only invoked when the model sets run_on_build=true, because eval runs cost Cortex credits
-- (agent invoked per dataset row + LLM judge per metric per row).
--
-- To check status or clean up a run, call EXECUTE_AI_EVALUATION directly with 'STATUS',
-- 'CANCEL', or 'DELETE' and the same run_name.
{% macro snowflake__execute_ai_evaluation(run_name, stage_path) %}

  call execute_ai_evaluation(
    'START',
    object_construct('run_name', '{{ run_name }}'),
    '{{ stage_path }}'
  )

{% endmacro %}
