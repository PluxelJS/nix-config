#!/usr/bin/env bash
set -euo pipefail

mode="${1:-preview}"

case "$mode" in
  preview|--preview|"")
    mode="preview"
    ;;
  apply|--apply)
    mode="apply"
    ;;
  -h|--help)
    cat <<'EOF'
Usage:
  bootstrap/dev-runtime-tuning.sh
  bootstrap/dev-runtime-tuning.sh --apply

Installs a small set of host runtime drop-ins for heavy development workloads:
many file watchers, many user services, many local ports, and many containers.

The default mode only prints the exact files. --apply writes them with sudo,
reloads sysctl, and asks systemd to reexec. Log out and back in afterwards so
new shells and user services inherit the new manager limits.
EOF
    exit 0
    ;;
  *)
    echo "Unknown mode: $mode" >&2
    echo "Run with --help for usage." >&2
    exit 2
    ;;
esac

read -r -d '' SYSCTL_CONF <<'EOF' || true
# AHDG developer workstation runtime tuning.
# Focus: file watchers, local containers, many outbound connections, and IDEs.

# Large JS/Rust/Nix repos plus multiple IDEs can exceed the stock inotify queue.
fs.inotify.max_user_watches = 4194304
fs.inotify.max_user_instances = 8192
fs.inotify.max_queued_events = 131072

# Keep global file table and mmap headroom aligned with heavy dev workloads.
fs.file-max = 4194304
vm.max_map_count = 2097152

# Local API servers, reverse proxies, container networking, and bursty tests.
net.core.somaxconn = 8192
net.ipv4.ip_local_port_range = 10000 65535
net.netfilter.nf_conntrack_max = 1048576
EOF

read -r -d '' SYSTEMD_MANAGER_CONF <<'EOF' || true
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=131072
DefaultTasksMax=65536
EOF

read -r -d '' LIMITS_CONF <<'EOF' || true
# AHDG developer workstation process limits for login sessions.
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 131072
* hard nproc 131072
EOF

print_file() {
  local path="$1"
  local content="$2"
  printf '\n==> %s\n' "$path"
  printf '%s\n' "$content"
}

install_file() {
  local path="$1"
  local content="$2"
  printf 'Installing %s\n' "$path"
  printf '%s\n' "$content" | sudo install -D -m 0644 /dev/stdin "$path"
}

print_current_values() {
  printf '\n==> Current relevant values\n'
  sysctl \
    fs.inotify.max_user_watches \
    fs.inotify.max_user_instances \
    fs.inotify.max_queued_events \
    fs.file-max \
    vm.max_map_count \
    net.core.somaxconn \
    net.ipv4.ip_local_port_range \
    net.netfilter.nf_conntrack_max 2>/dev/null || true

  printf '\n'
  systemctl show --property DefaultLimitNOFILE,DefaultLimitNPROC,DefaultTasksMax 2>/dev/null || true
  systemctl --user show --property DefaultLimitNOFILE,DefaultLimitNPROC,DefaultTasksMax 2>/dev/null || true

  printf '\n==> Rootless Podman subordinate ID ranges\n'
  if [[ -n "${USER:-}" ]]; then
    grep -E "^${USER}:" /etc/subuid /etc/subgid 2>/dev/null || true
  else
    echo "USER is not set; skipped /etc/subuid and /etc/subgid lookup."
  fi
  cat <<'EOF'

Subuid/subgid note:
  If you run many rootless containers, consider expanding the user range from
  the common 65536 size to 1048576 after stopping containers, then run:

    podman system migrate

  This script does not edit /etc/subuid or /etc/subgid automatically because
  those ranges must not overlap with other users.
EOF
}

if [[ "$mode" == "preview" ]]; then
  print_file /etc/sysctl.d/90-ahdg-dev-runtime.conf "$SYSCTL_CONF"
  print_file /etc/systemd/system.conf.d/90-ahdg-dev-runtime.conf "$SYSTEMD_MANAGER_CONF"
  print_file /etc/systemd/user.conf.d/90-ahdg-dev-runtime.conf "$SYSTEMD_MANAGER_CONF"
  print_file /etc/security/limits.d/90-ahdg-dev-runtime.conf "$LIMITS_CONF"
  print_current_values
  cat <<'EOF'

Preview only. To install:
  bootstrap/dev-runtime-tuning.sh --apply
EOF
  exit 0
fi

install_file /etc/sysctl.d/90-ahdg-dev-runtime.conf "$SYSCTL_CONF"
install_file /etc/systemd/system.conf.d/90-ahdg-dev-runtime.conf "$SYSTEMD_MANAGER_CONF"
install_file /etc/systemd/user.conf.d/90-ahdg-dev-runtime.conf "$SYSTEMD_MANAGER_CONF"
install_file /etc/security/limits.d/90-ahdg-dev-runtime.conf "$LIMITS_CONF"

printf '\nReloading sysctl values from /etc/sysctl.d/90-ahdg-dev-runtime.conf\n'
sudo sysctl -e -p /etc/sysctl.d/90-ahdg-dev-runtime.conf

printf '\nReexecuting systemd managers so new defaults are visible to new units\n'
sudo systemctl daemon-reexec
systemctl --user daemon-reexec

print_current_values

cat <<'EOF'

Applied. Log out and back in before judging shell, IDE, and user-service limits.
Existing containers and already-running services keep the limits they started with.
EOF
