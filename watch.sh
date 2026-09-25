#!/usr/bin/env bash
# Serve the last successful build while rebuilding on source changes.
set -u

server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Start serving the previous published site immediately, including while a rebuild runs.
mkdir -p .publish
(
  cd .publish
  exec python3 -m http.server
) &
server_pid=$!

# A failed build must not prevent the watcher from starting.
make all || printf 'Initial build failed; serving the previous published site.\n' >&2

# watchexec continues watching when a build command exits unsuccessfully.
watchexec \
  --watch site \
  --watch snippets \
  --watch publish.el \
  --watch build.sh \
  -- make all
