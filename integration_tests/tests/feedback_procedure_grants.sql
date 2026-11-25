-- Roles with USAGE on an agent that has create_feedback_table=true must also get USAGE on the
-- AGENT_SUBMIT_FEEDBACK procedure — USAGE on the agent alone does not let them call the tool.
-- Returns 0 rows on success (standard dbt test contract).

{{ expect_grant(ref('feedback_procedure_grants'), 'usage', 'dbt_demo_role', 'AGENT_SUBMIT_FEEDBACK') }}
