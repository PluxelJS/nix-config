#!/usr/bin/env bash
set -euo pipefail

IFS=', ' read -r -a databases <<<"${POSTGRES_EXTRA_DATABASES:-}"
for database in "${databases[@]}"; do
  [[ -n "$database" ]] || continue
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -v "target_db=$database" <<'SQL'
SELECT format('CREATE DATABASE %I', :'target_db')
WHERE NOT EXISTS (
  SELECT 1 FROM pg_database WHERE datname = :'target_db'
)\gexec
SQL
done
