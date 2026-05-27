{% macro snowflake__create_feedback_table(feedback_table) %}

  create table if not exists {{ feedback_table }} (
    feedback_id          varchar         default uuid_string(),
    agent_name           varchar         not null,
    session_id           varchar,
    rating               number,
    comment              varchar,
    conversation_history variant,
    created_at           timestamp_ntz   default current_timestamp()
  )

{% endmacro %}
