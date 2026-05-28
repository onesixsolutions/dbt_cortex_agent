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
| `create_feedback_table` | bool | No | Whether to create the feedback table and procedure. Defaults to `true`. Set to `false` to skip. See [Feedback Tool](#feedback-tool). |
| `feedback_schema` | string | No | Schema for the feedback table and `AGENT_SUBMIT_FEEDBACK` procedure. Accepts `'SCHEMA'` or `'DB.SCHEMA'`. Defaults to the agent's own database and schema. See [Feedback Tool](#feedback-tool). |
| `feedback_table` | string | No | Fully-qualified table name override for user feedback. Defaults to `{feedback_schema}.AGENT_FEEDBACK`. Ignored when `create_feedback_table` is `false`. See [Feedback Tool](#feedback-tool). |

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

All agents share a single feedback table and a single `AGENT_SUBMIT_FEEDBACK` procedure — no config required. On each `dbt run` the materialization provisions (idempotently):

1. A **feedback table** named `AGENT_FEEDBACK` in the agent's database and schema, with columns: `feedback_id`, `agent_name`, `user_name`, `rating`, `comment`, `conversation_history`, `created_at`
2. A **stored procedure** named `AGENT_SUBMIT_FEEDBACK` in the same location

By default both land in the agent's own schema. Use `feedback_schema` to place them in a shared schema instead:

```sql
{{ config(
    materialized='cortex_agent',
    feedback_schema='SHARED_SCHEMA'
) }}
```

Or with an explicit database:

```sql
{{ config(
    materialized='cortex_agent',
    feedback_schema='MY_DB.SHARED_SCHEMA'
) }}
```

To override the table name independently of the schema, use `feedback_table`:

```sql
{{ config(
    materialized='cortex_agent',
    feedback_schema='SHARED_SCHEMA',
    feedback_table='MY_DB.SHARED_SCHEMA.AGENT_FEEDBACK'
) }}
```

To disable feedback provisioning entirely, set `create_feedback_table: false`:

```sql
{{ config(
    materialized='cortex_agent',
    create_feedback_table=false
) }}
```

Add the tool entry to your spec body so the agent can call it. Update the `identifier` to match your `feedback_schema` if you set one:

```sql
{{ config(
    materialized='cortex_agent',
    feedback_schema='SHARED_SCHEMA'
) }}

tools:
  - tool_spec:
      type: generic
      name: AGENT_SUBMIT_FEEDBACK
      description: 'Records user feedback. Call when the user says "feedback" or explicitly rates or comments on a response. Always pass the last 10 conversation messages. Example: user says "feedback: 1. Output wrong, expected $100" → call with rating=1, user_comment="Output wrong, expected $100". Example: user says "feedback: 5. Completely Correct" → call with rating=5, user_comment="Completely Correct".'
      input_schema:
        type: object
        properties:
          agent_name:
            type: string
            description: 'Name of this agent. Always pass "{{ this.identifier | upper }}".'
          rating:
            type: number
            description: 'The user rating from 1 (worst) to 5 (best).'
          user_comment:
            type: string
            description: 'Optional free-text feedback.'
          conversation_history:
            type: string
            description: 'Last 10 messages from the conversation as a JSON string, e.g. [{"role":"user","content":"..."}].'
        required: [agent_name, rating, conversation_history]

tool_resources:
  AGENT_SUBMIT_FEEDBACK:
    execution_environment:
      query_timeout: 300
      type: warehouse
      warehouse: ''
    identifier: '{{ this.database }}.SHARED_SCHEMA.AGENT_SUBMIT_FEEDBACK'
    name: 'AGENT_SUBMIT_FEEDBACK(VARCHAR, NUMBER, VARCHAR, VARCHAR)'
    type: procedure
```

The procedure is recreated on every `dbt run`, so changes to the feedback table schema are picked up automatically. The feedback table uses `CREATE TABLE IF NOT EXISTS`, so existing data is never dropped.

## License

Apache 2.0
