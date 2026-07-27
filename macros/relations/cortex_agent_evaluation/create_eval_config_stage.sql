-- Creates the internal stage that holds Cortex Agent evaluation run-config YAML files.
-- Directory table enabled so the files are listable. Idempotent — safe on every run.
{% macro snowflake__create_eval_config_stage(stage) %}

  create stage if not exists {{ stage }}
    directory = (enable = true)

{% endmacro %}
