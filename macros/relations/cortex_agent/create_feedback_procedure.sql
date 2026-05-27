{% macro snowflake__create_feedback_procedure(relation, feedback_table) %}

  create or replace procedure
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}_SUBMIT_FEEDBACK(
      SESSION_ID           varchar,
      RATING               varchar,
      COMMENT              varchar,
      CONVERSATION_HISTORY variant
    )
  returns varchar
  language sql
  as
  $$
  begin
    insert into {{ feedback_table }}
      (agent_name, session_id, rating, comment, conversation_history, created_at)
    values
      ('{{ relation.identifier }}', SESSION_ID, RATING, COMMENT, CONVERSATION_HISTORY, current_timestamp());
    return 'Feedback submitted';
  end;
  $$

{% endmacro %}
