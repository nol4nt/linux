#!/usr/bin/env bash

TIME=$(date | sed 's/"/\\"/g')

echo '{"text":"Input OK","tooltip":"Script executed successfully\nTime: $TIME"}'

