#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
exec "$repo_dir/bootstrap/bin/cachyos-bootstrap" bootstrap "$@"
