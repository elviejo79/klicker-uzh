#!/usr/bin/env bash
# Runs one root pnpm script from a Git hook when this checkout has its own
# dependency install. Devcontainer checkouts keep node_modules in container
# volumes, so the host copy stays empty; host pnpm would then fail its
# verifyDepsBeforeRun check, and installing on the host would build a second,
# platform-specific dependency tree. Those checkouts skip the step with a
# notice instead: required CI runs the same checks and build on every push.
set -euo pipefail

script="${1:?usage: run-hook-pnpm.sh <root pnpm script>}"

# A root .modules.yaml alone does not prove a usable install. `pnpm playwright:host`
# bootstraps the host with `--filter @klicker-uzh/playwright...`, which writes that
# file but populates only the filter closure and leaves every other workspace package
# with an empty node_modules; a root script then fails on a missing binary instead of
# skipping. Globs mirror pnpm-workspace.yaml. A package that declares no dependencies
# would read as incomplete and skip, which is the safe direction.
has_usable_install() {
  [[ -f node_modules/.modules.yaml ]] || return 1
  local manifest
  for manifest in apps/*/package.json packages/*/package.json playwright/package.json; do
    [[ -f $manifest ]] || continue
    [[ -n $(ls -A "${manifest%/package.json}/node_modules" 2>/dev/null) ]] || return 1
  done
  return 0
}

if has_usable_install; then
  exec pnpm run "$script"
fi

echo "⚠ No usable dependency install in this checkout (devcontainer checkouts keep it in the container) — skipping 'pnpm run ${script}'. Required CI enforces it; see docs/getting-started.md to run it in the container."
