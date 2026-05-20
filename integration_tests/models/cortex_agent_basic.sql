-- Copyright 2025 OneSix Solutions
-- SPDX-License-Identifier: Apache-2.0

{{ config(materialized='cortex_agent') }}

models:
  orchestration: claude-4-sonnet
instructions:
  response: 'You are a helpful assistant.'
