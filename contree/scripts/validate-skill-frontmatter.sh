#!/usr/bin/env bash
set -eu

skills_dir="${1:?usage: $0 <skills_dir>}"

if [ ! -d "$skills_dir" ]; then
  printf 'skills dir does not exist: %s\n' "$skills_dir" >&2
  exit 1
fi

offenders=()

while IFS= read -r -d '' skill_file; do
  marker_count=$(awk '/^---$/ { count++ } END { print count+0 }' "$skill_file")
  if [ "$marker_count" -lt 2 ]; then
    offenders+=("$skill_file: missing or unclosed frontmatter")
    continue
  fi

  frontmatter=$(awk '
    /^---$/ { markers++; if (markers == 1) { inside=1; next } if (markers == 2) { exit } }
    inside { print }
  ' "$skill_file")

  if [ -z "$frontmatter" ]; then
    offenders+=("$skill_file: missing or empty frontmatter")
    continue
  fi

  name=$(printf '%s\n' "$frontmatter" | awk '
    /^name:[[:space:]]*/ {
      sub(/^name:[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ')
  description=$(printf '%s\n' "$frontmatter" | awk '
    /^description:[[:space:]]*/ {
      sub(/^description:[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ')

  if [ -z "$name" ]; then
    offenders+=("$skill_file: missing or empty 'name'")
  fi
  if [ -z "$description" ]; then
    offenders+=("$skill_file: missing or empty 'description'")
  fi
done < <(find "$skills_dir" -type f -name 'SKILL.md' -print0)

if [ "${#offenders[@]}" -gt 0 ]; then
  printf '%s\n' "${offenders[@]}" >&2
  exit 1
fi
