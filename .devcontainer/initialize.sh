#!/usr/bin/env bash
# Runs on the host before Compose resolves the devcontainer configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
node "$SCRIPT_DIR/../util/generate-dependency-mounts.mjs" "$SCRIPT_DIR/.."
CERT_DIR="$SCRIPT_DIR/certs"
PNPM_STORE_VOLUME='klicker-uzh-pnpm-store-v1'

# DevPod chowns the workspace to the container user (root). On Linux that writes
# through the bind mount and locks the host out of its own checkout, so record
# the owner here — while the tree is still host-owned — for post-start to restore.
if [ "$(uname -s)" = 'Linux' ]; then
  echo "$(id -u):$(id -g)" >"$SCRIPT_DIR/.host-owner" 2>/dev/null || true
fi

# TLS trust is optional for plain localhost mode, so keep certificate setup
# best-effort when mkcert is not installed on the host.
mkdir -p "$CERT_DIR"
touch "$CERT_DIR/rootCA.pem"
if MKCERT_CAROOT="$(mkcert -CAROOT 2>/dev/null)" &&
  [ -r "$MKCERT_CAROOT/rootCA.pem" ]; then
  cp "$MKCERT_CAROOT/rootCA.pem" "$CERT_DIR/rootCA.pem"
fi

# The pnpm content store is the only cache shared across worktrees. It is
# external so deleting one DevPod cannot remove packages used by another.
docker volume inspect "$PNPM_STORE_VOLUME" >/dev/null 2>&1 ||
  docker volume create "$PNPM_STORE_VOLUME" >/dev/null 2>&1 ||
  docker volume inspect "$PNPM_STORE_VOLUME" >/dev/null
