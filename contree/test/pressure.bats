#!/usr/bin/env bats

load test_helper

SCRIPT="$PROJECT_ROOT/hooks/pressure.sh"

make_phrases_dir() {
  local tmpdir
  tmpdir=$(mktemp -d)
  mkdir -p "$tmpdir/hooks"
  echo "$tmpdir"
}

# --- Failure safety ---

@test "exits 0 when phrases.txt does not exist" {
  local tmpdir; tmpdir=$(mktemp -d)
  CLAUDE_PLUGIN_ROOT="$tmpdir" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  rm -rf "$tmpdir"
}

@test "exits 0 when phrases.txt is empty" {
  local tmpdir; tmpdir=$(make_phrases_dir)
  touch "$tmpdir/hooks/phrases.txt"
  CLAUDE_PLUGIN_ROOT="$tmpdir" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  rm -rf "$tmpdir"
}

# --- Injection behaviour ---

@test "when injection fires, exits 2" {
  local tmpdir; tmpdir=$(make_phrases_dir)
  printf 'phrase one\nphrase two\nphrase three\n' > "$tmpdir/hooks/phrases.txt"

  local fired=0
  for _ in $(seq 1 60); do
    status_code=0
    CLAUDE_PLUGIN_ROOT="$tmpdir" bash "$SCRIPT" 2>/dev/null || status_code=$?
    if [ "$status_code" -eq 2 ]; then
      fired=1
      break
    fi
  done

  [ "$fired" -eq 1 ]
  rm -rf "$tmpdir"
}

@test "when injection fires, output is a line from phrases.txt" {
  local tmpdir; tmpdir=$(make_phrases_dir)
  printf 'alpha phrase\nbeta phrase\ngamma phrase\n' > "$tmpdir/hooks/phrases.txt"

  local output=""
  for _ in $(seq 1 60); do
    status_code=0
    output=$(CLAUDE_PLUGIN_ROOT="$tmpdir" bash "$SCRIPT" 2>&1) || status_code=$?
    if [ "$status_code" -eq 2 ]; then
      break
    fi
  done

  grep -qxF "$output" "$tmpdir/hooks/phrases.txt"
  rm -rf "$tmpdir"
}

@test "injection does not fire on every call" {
  local tmpdir; tmpdir=$(make_phrases_dir)
  printf 'phrase one\nphrase two\n' > "$tmpdir/hooks/phrases.txt"

  local skip_count=0
  for _ in $(seq 1 30); do
    status_code=0
    CLAUDE_PLUGIN_ROOT="$tmpdir" bash "$SCRIPT" 2>/dev/null || status_code=$?
    [ "$status_code" -eq 2 ] || (( skip_count++ )) || true
  done

  [ "$skip_count" -gt 0 ]
  rm -rf "$tmpdir"
}
