-- Creates (or replaces) the shared AGENT_SUBMIT_FEEDBACK procedure that agents expose as a
-- custom tool.
--
-- COPY GRANTS: the procedure is replaced on every dbt run and is shared by every agent that
-- points at the same feedback schema. Without COPY GRANTS each replace would drop the USAGE
-- grants issued for the other agents' roles, leaving only the roles of whichever agent ran
-- last.
{% macro snowflake__create_feedback_procedure(feedback_db, feedback_schema, feedback_table, execute_as='caller') %}

  create or replace procedure
    {{ feedback_db }}.{{ feedback_schema }}.AGENT_SUBMIT_FEEDBACK(
      AGENT_NAME           varchar,
      RATING               number,
      USER_COMMENT         varchar,
      CONVERSATION_HISTORY varchar
    )
  copy grants
  returns varchar
  language sql
  execute as {{ execute_as }}
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


-- Builds the GRANT USAGE ON PROCEDURE statements that let each role call the
-- AGENT_SUBMIT_FEEDBACK procedure. USAGE on the agent alone is not enough for a custom tool:
-- the calling role also needs USAGE on the procedure behind it, and by default Snowflake
-- skips an inaccessible tool silently rather than failing the run.
-- Returns a LIST of SQL strings, one per role.
--
-- Note: with execute_as='caller' (the default) the role additionally needs INSERT on the
-- feedback table. That grant is left to the project, since the table may be shared.
{% macro snowflake__grant_feedback_procedure_usage(feedback_db, feedback_schema, roles) %}
  {%- set _procedure = feedback_db ~ '.' ~ feedback_schema ~ '.AGENT_SUBMIT_FEEDBACK(varchar, number, varchar, varchar)' -%}
  {%- set _statements = [] -%}
  {%- for role in roles -%}
    {%- do _statements.append('grant usage on procedure ' ~ _procedure ~ ' to role ' ~ role) -%}
  {%- endfor -%}
  {{ return(_statements) }}
{% endmacro %}
