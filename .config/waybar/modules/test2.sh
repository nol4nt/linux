#!/usr/bin/env bash

jq -n \
  --arg text "Input OK" \
  --arg tooltip "Script executed successfully\nTime: $(date)" \
  '{text: $text, tooltip: $tooltip}'

