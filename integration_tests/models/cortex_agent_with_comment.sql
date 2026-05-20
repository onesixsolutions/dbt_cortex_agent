{{ config(
    materialized='cortex_agent',
    comment='integration test comment'
) }}

models:
  orchestration: claude-4-sonnet
instructions:
  response: 'You are a helpful assistant.'
