{% macro snowflake__create_feedback_procedure(feedback_db, feedback_schema, feedback_table) %}

  create or replace procedure
    {{ feedback_db }}.{{ feedback_schema }}.AGENT_SUBMIT_FEEDBACK(
      AGENT_NAME           varchar,
      RATING               number,
      USER_COMMENT         varchar,
      CONVERSATION_HISTORY varchar
    )
  returns varchar
  language sql
  execute as caller
  as
  $$
  begin
    let parsed_history variant := parse_json(:CONVERSATION_HISTORY);
    insert into {{ feedback_table }}
      (agent_name, user_name, rating, comment, conversation_history, created_at)
    select
      :AGENT_NAME, current_user(), :RATING, :USER_COMMENT, :parsed_history, current_timestamp();
    return 'Feedback submitted';
  end;
  $$

{% endmacro %}
