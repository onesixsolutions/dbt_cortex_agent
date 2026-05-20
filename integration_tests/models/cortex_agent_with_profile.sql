{{ config(
    materialized='cortex_agent',
    profile='{"display_name": "Integration Test Agent"}'
) }}

models:
  orchestration: claude-4-sonnet
instructions:
  response: 'You are a helpful assistant.'
