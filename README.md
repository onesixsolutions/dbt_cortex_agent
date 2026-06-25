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
| `create_feedback_table` | bool | No | Whether to create the feedback table and procedure. Defaults to `false`. Set to `true` to enable. See [Feedback Tool](#feedback-tool). |
| `feedback_schema` | string | No | Schema for the feedback table and `AGENT_SUBMIT_FEEDBACK` procedure. Accepts `'SCHEMA'` or `'DB.SCHEMA'`. Defaults to the agent's own database and schema. See [Feedback Tool](#feedback-tool). |
| `feedback_table` | string | No | Fully-qualified table name override for user feedback. Defaults to `{feedback_schema}.AGENT_FEEDBACK`. Ignored when `create_feedback_table` is `false`. See [Feedback Tool](#feedback-tool). |
| `feedback_execute_as` | string | No | Execution rights for the `AGENT_SUBMIT_FEEDBACK` procedure. `'caller'` (default) captures the end user via `current_user()`. Use `'owner'` if the calling role lacks `INSERT` on the feedback table. See [Feedback Tool](#feedback-tool). |
| `enable_versioning` | bool | No | Whether to use Snowflake agent versioning. Defaults to `true`. When `true`, uses `CREATE AGENT IF NOT EXISTS` + `ALTER AGENT MODIFY LIVE VERSION` instead of `CREATE OR REPLACE AGENT`, preserving version history across runs. Set to `false` in dev environments to skip versioning overhead. `dbt run --full-refresh` always falls back to `CREATE OR REPLACE`, resetting history. |
| `auto_commit` | bool | No | When `enable_versioning=true`, automatically snapshot the LIVE version into a new named version after each run. Defaults to `true`. Set to `false` to accumulate spec changes in LIVE without committing, then commit manually via `ALTER AGENT COMMIT`. |
| `version_comment` | string | No | Comment attached to each committed version snapshot. Only used when `enable_versioning=true` and `auto_commit=true`. |

## How It Works

The model body is passed verbatim as the agent YAML specification to Snowflake. Because it's a direct passthrough:

- All current and future Snowflake agent YAML options work automatically
- No package updates needed when Snowflake adds new features
- You can use Jinja (`{{ ref() }}`, `{{ var() }}`, etc.) anywhere in the spec
- `{{ ref() }}` calls in `tool_resources` resolve to fully qualified names **and** wire the agent into the dbt DAG — the agent will always run after its upstream semantic views

## Versioning

By default (`enable_versioning=true`, `auto_commit=true`) every `dbt run`:

1. Creates the agent if it doesn't exist (`CREATE AGENT IF NOT EXISTS`)
2. Restores a LIVE working copy from the last committed version (`ALTER AGENT ADD LIVE VERSION FROM LAST`)
3. Updates the LIVE copy with the latest compiled spec (`ALTER AGENT MODIFY LIVE VERSION SET SPECIFICATION`)
4. Commits the LIVE copy as a new named version — `VERSION$1`, `VERSION$2`, … (`ALTER AGENT COMMIT`)

Version history accumulates across runs. `dbt run --full-refresh` falls back to `CREATE OR REPLACE AGENT`, resetting all history.

**Disable versioning in dev** to avoid the overhead when iterating quickly:

```yaml
# dbt_project.yml
models:
  my_project:
    agents:
      +enable_versioning: false
```

Or per-model:

```sql
{{ config(materialized='cortex_agent', enable_versioning=false) }}
```

**Commit manually** by setting `auto_commit=false` — the materialization keeps the LIVE version open across runs and you commit explicitly when ready:

```sql
{{ config(materialized='cortex_agent', auto_commit=false) }}
```

## Idempotency

With versioning enabled (default), every `dbt run` preserves history — re-runs are safe and create a new committed version. With `enable_versioning=false`, every run issues `CREATE OR REPLACE AGENT`. `dbt run --full-refresh` always uses `CREATE OR REPLACE AGENT`, resetting all version history.

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

To enable feedback provisioning, set `create_feedback_table: true`:

```sql
{{ config(
    materialized='cortex_agent',
    create_feedback_table=true
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
      description: 'Records user feedback about agent responses. Call when the user says "feedback" or explicitly rates or comments on a response. Each time feedback is triggered, ask the user fresh for a rating (1–5) and comment — do NOT reuse, reference, or pre-fill from any previously submitted feedback. For conversation_history, include only the last 10 messages that are NOT part of a prior feedback exchange (exclude all previous AGENT_SUBMIT_FEEDBACK tool calls and their results). Example: user says "1. Output wrong, expected $100" → call with rating=1, user_comment="Output wrong, expected $100". Example: user says "5. Completely Correct" → call with rating=5, user_comment="Completely Correct".'
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

By default the procedure runs with `EXECUTE AS CALLER`, so `current_user()` inside the procedure captures the actual end user calling the agent. If the calling role does not have `INSERT` privileges on the feedback table, switch to owner rights:

```sql
{{ config(
    materialized='cortex_agent',
    create_feedback_table=true,
    feedback_execute_as='owner'
) }}
```

The procedure is recreated on every `dbt run`, so changes to the feedback table schema are picked up automatically. The feedback table uses `CREATE TABLE IF NOT EXISTS`, so existing data is never dropped.

## MCP Servers

The package also ships an `mcp_server` materialization for deploying [Snowflake-managed MCP servers](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp). It works the same way as `cortex_agent`: the model body is the raw MCP server YAML specification (a `tools:` array), wrapped in `CREATE OR REPLACE MCP SERVER ... FROM SPECIFICATION $$ ... $$`.

```sql
-- models/mcp/data_mcp_server.sql
{{ config(materialized='mcp_server') }}

tools:
  - name: "product_search"
    type: "CORTEX_SEARCH_SERVICE_QUERY"
    identifier: "{{ ref('product_search_service') }}"
    title: "Product Search"
    description: "Cortex Search service over product documentation."

  - name: "revenue_analyst"
    type: "CORTEX_ANALYST_MESSAGE"
    identifier: "{{ ref('revenue_semantic_view') }}"
    title: "Revenue Analyst"
    description: "Semantic view for revenue analysis."

  - name: "sql_exec_tool"
    type: "SYSTEM_EXECUTE_SQL"
    title: "SQL Execution"
    description: "Execute read-only SQL against Snowflake."
    config:
      read_only: true
      query_timeout: 120
      warehouse: "MY_WAREHOUSE"
```

Run it:

```bash
dbt run --select data_mcp_server
```

Verify in Snowflake:

```sql
SHOW MCP SERVERS IN SCHEMA my_db.my_schema;
DESCRIBE MCP SERVER my_db.my_schema.data_mcp_server;
```

Notes specific to MCP servers:

- The `tools` array is required and must contain at least one tool. Supported `type` values include `CORTEX_SEARCH_SERVICE_QUERY`, `CORTEX_ANALYST_MESSAGE`, `CORTEX_AGENT_RUN`, `SYSTEM_EXECUTE_SQL`, and `GENERIC`. Each tool that wraps an existing object needs a fully-qualified `identifier` — use `{{ ref() }}` to wire it into the dbt DAG so the MCP server always runs after its upstream objects.
- Unlike agents, the MCP server DDL has **no `COMMENT` or `PROFILE` clause**, so the `mcp_server` materialization takes no extra config options — everything lives in the spec body.
- Like `cortex_agent`, every `dbt run` issues `CREATE OR REPLACE MCP SERVER`, so re-runs are fully idempotent, and Jinja (`{{ ref() }}`, `{{ var() }}`, etc.) works anywhere in the spec.
- To drop an MCP server explicitly, use the helper macro in a dbt operation or post-hook: `{% do run_query(dbt_cortex_agent.snowflake__get_drop_mcp_server_sql(this)) %}` (or run `DROP MCP SERVER IF EXISTS <db>.<schema>.<name>;` directly).

Refer to the [Snowflake CREATE MCP SERVER docs](https://docs.snowflake.com/en/sql-reference/sql/create-mcp-server) for the full and up-to-date specification reference.

## Local Development

### Prerequisites

- PowerShell
- dbt-snowflake installed in your environment
- A Snowflake account with Cortex Agents enabled

### Setup

1. Copy the env template and fill in your Snowflake details:

```powershell
# integration_tests/.env is git-ignored
```

Edit `integration_tests/.env`:

```
SNOWFLAKE_TEST_ACCOUNT=<orgname>-<accountname>
SNOWFLAKE_TEST_USER=you@example.com
SNOWFLAKE_TEST_ROLE=<your_role>
SNOWFLAKE_TEST_DATABASE=<your_database>
SNOWFLAKE_TEST_WAREHOUSE=<your_warehouse>
SNOWFLAKE_TEST_SCHEMA=<your_schema>
SNOWFLAKE_TEST_AUTHENTICATOR=externalbrowser
```

> Set `SNOWFLAKE_TEST_AUTHENTICATOR=externalbrowser` for Google SSO (a browser window will open on first connection). For key-pair auth, set it to `snowflake_jwt` and add `SNOWFLAKE_TEST_PRIVATE_KEY_PATH` and `SNOWFLAKE_TEST_PRIVATE_KEY_PASSPHRASE`.

2. Run the integration tests:

```powershell
.\scripts\run_tests.ps1
```

This script stages a clean copy of the package to avoid a Windows path-length issue caused by dbt's recursive local package installation, then runs `dbt deps` and `dbt build` from `integration_tests/`.

To install packages only (no build):

```powershell
.\scripts\run_tests.ps1 -DepsOnly
```

## License

Apache 2.0
