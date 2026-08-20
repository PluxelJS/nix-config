#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

case "${1:-}" in
  -h | --help)
    exec "$repo_dir/bootstrap/bin/cachyos-bootstrap" "$@"
    ;;
  atop | bootstrap | deps | firewall | flatpaks | pull-gui-config | cleanup | verify)
    exec "$repo_dir/bootstrap/bin/cachyos-bootstrap" "$@"
    ;;
  *)
    exec "$repo_dir/bootstrap/bin/cachyos-bootstrap" bootstrap "$@"
    ;;
esac
