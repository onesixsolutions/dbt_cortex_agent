{% macro snowflake__create_feedback_procedure(relation, feedback_table) %}

  create or replace procedure
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier | upper }}_SUBMIT_FEEDBACK(
      SESSION_ID           varchar,
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
      (session_id, user_name, rating, comment, conversation_history, created_at)
    select
      :SESSION_ID, current_user(), :RATING, :USER_COMMENT, :parsed_history, current_timestamp();
    return 'Feedback submitted';
  end;
  $$

{% endmacro %}
