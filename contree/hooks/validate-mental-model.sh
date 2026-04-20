#!/usr/bin/env bash

FILE="MENTAL_MODEL.md"

if [ ! -f "$FILE" ]; then
  printf 'MENTAL_MODEL.md is missing\n'
  exit 0
fi
