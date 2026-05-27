# dbt_cortex_agent

A custom dbt materialization for deploying [Snowflake Cortex Agents](https://docs.snowflake.com/en/sql-reference/sql/create-agent) using dbt. Define, version, and run Cortex Agents the same way you manage any other dbt model.

## Requirements

- dbt >= 1.0.0
- Snowflake adapter (`dbt-snowflake`)
- Snowflake account with Cortex Agents enabled

## Installation

Add to your project's `packages.yml`:

```yaml
packages:
  - git: "https://github.com/<your-org>/dbt_cortex_agent"
    revision: "0.1.0"
```

Then run:

```bash
dbt deps
```

## Usage

Create a model file whose **body is the raw Snowflake agent YAML specification**. The materialization wraps it in `CREATE OR REPLACE AGENT ... FROM SPECIFICATION $$ ... $$`.

```sql
-- models/agents/revenue_assistant.sql
{{ config(
    materialized='cortex_agent',
    comment='Revenue analysis assistant powered by Cortex Analyst',
    profile='{"display_name": "Revenue Assistant", "color": "blue"}'
) }}

models:
  orchestration: auto
orchestration:
  budget:
    seconds: 30
    tokens: 16000
instructions:
  response: 'You are a helpful revenue analyst. Answer questions using the available data.'
  sample_questions:
    - question: 'What was total revenue last quarter?'
    - question: 'Which clients had the highest chargeback rate?'
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: revenue_analyst
tool_resources:
  revenue_analyst:
    execution_environment:
      type: "warehouse"
      warehouse: ""
    semantic_view: '{{ ref("revenue_semantic_view") }}'
```

Run it:

```bash
dbt run --select revenue_assistant
```

Verify in Snowflake:

```sql
SHOW AGENTS IN SCHEMA my_db.my_schema;
```

## Config Options

| Option | Type | Required | Description |
|---|---|---|---|
| `materialized` | string | Yes | Must be `'cortex_agent'` |
| `comment` | string | No | Agent description visible in Snowflake |
| `profile` | string (JSON) | No | `{"display_name": "...", "avatar": "...", "color": "..."}` |
| `agent_grants` | list | No | Role names to grant `USAGE` on the agent, e.g. `['my_role']` |
| `feedback_table` | string | No | Fully-qualified table for user feedback, e.g. `'MY_DB.MY_SCHEMA.AGENT_FEEDBACK'`. See [Feedback Tool](#feedback-tool). |

## How It Works

The model body is passed verbatim as the agent YAML specification to Snowflake's `CREATE OR REPLACE AGENT ... FROM SPECIFICATION $$ ... $$`. Because it's a direct passthrough:

- All current and future Snowflake agent YAML options work automatically
- No package updates needed when Snowflake adds new features
- You can use Jinja (`{{ ref() }}`, `{{ var() }}`, etc.) anywhere in the spec
- `{{ ref() }}` calls in `tool_resources` resolve to fully qualified names **and** wire the agent into the dbt DAG — the agent will always run after its upstream semantic views

## Idempotency

Every `dbt run` issues `CREATE OR REPLACE AGENT`, so re-runs are safe and fully idempotent. `dbt run --full-refresh` behaves identically.

## Supported Tools in Specification

Built-in tool types (add to the `tools:` section of your spec body):

- `cortex_analyst_text_to_sql` — text-to-SQL via a Cortex Analyst semantic model
- `cortex_search` — semantic search over unstructured content
- `generic` — any Snowflake stored procedure or UDF (see [Feedback Tool](#feedback-tool) for an example)

Refer to the [Snowflake CREATE AGENT docs](https://docs.snowflake.com/en/sql-reference/sql/create-agent) for the full and up-to-date YAML specification reference.

## Feedback Tool

Set `feedback_table` in your model config to automatically provision:

1. A **feedback table** (created once, never replaced) with columns: `feedback_id`, `agent_name`, `session_id`, `rating`, `comment`, `conversation_history`, `created_at`
2. A **stored procedure** named `{AGENT_NAME}_SUBMIT_FEEDBACK` in the same database/schema as the agent

Then add the tool entry to your spec body so the agent can call it:

```sql
{{ config(
    materialized='cortex_agent',
    feedback_table='MY_DB.MY_SCHEMA.AGENT_FEEDBACK'
) }}

tools:
  - tool_spec:
      type: generic
      name: SUBMIT_FEEDBACK
      description: 'Records user feedback. Call when the user rates or comments on a response. Always pass the last 10 conversation messages.'
      input_schema:
        type: object
        properties:
          session_id:
            type: string
            description: 'Current conversation session identifier.'
          rating:
            type: string
            enum: [good, bad]
          comment:
            type: string
            description: 'Optional free-text feedback.'
          conversation_history:
            type: string
            description: 'Last 10 messages from the conversation as a JSON string, e.g. [{"role":"user","content":"..."}].'
        required: [session_id, rating, conversation_history]

tool_resources:
  SUBMIT_FEEDBACK:
    execution_environment:
      query_timeout: 300
      type: warehouse
      warehouse: ''
    identifier: '{{ this.database }}.{{ this.schema }}.{{ this.identifier | upper }}_SUBMIT_FEEDBACK'
    name: '{{ this.identifier | upper }}_SUBMIT_FEEDBACK(VARCHAR, VARCHAR, VARCHAR, VARCHAR)'
    type: procedure
```

The procedure is recreated on every `dbt run`, so changes to the feedback table schema are picked up automatically. The feedback table uses `CREATE TABLE IF NOT EXISTS`, so existing data is never dropped.

## License

Apache 2.0
