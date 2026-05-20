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
  orchestration: claude-4-sonnet
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
    semantic_model: '@my_db.my_schema.my_stage/revenue_model.yaml'
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

## How It Works

The model body is passed verbatim as the agent YAML specification to Snowflake's `CREATE OR REPLACE AGENT ... FROM SPECIFICATION $$ ... $$`. Because it's a direct passthrough:

- All current and future Snowflake agent YAML options work automatically
- No package updates needed when Snowflake adds new features
- You can use Jinja (`{{ ref() }}`, `{{ var() }}`, etc.) anywhere in the spec

## Idempotency

Every `dbt run` issues `CREATE OR REPLACE AGENT`, so re-runs are safe and fully idempotent. `dbt run --full-refresh` behaves identically.

## Supported Tools in Specification

As of the current Snowflake documentation:

- `cortex_analyst_text_to_sql` — text-to-SQL via a Cortex Analyst semantic model
- `cortex_search` — semantic search over unstructured content

Refer to the [Snowflake CREATE AGENT docs](https://docs.snowflake.com/en/sql-reference/sql/create-agent) for the full and up-to-date YAML specification reference.

## License

Apache 2.0
