{{ config(materialized='cortex_agent') }}

models:
  orchestration: claude-4-sonnet
instructions:
  response: 'You are a helpful assistant.'
