#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${DATABASE_URL:-}" && -f "${ROOT_DIR}/.env" ]]; then
  DATABASE_URL="$(
    awk '
      /^DATABASE_URL=/ {
        sub(/^DATABASE_URL=/, "");
        gsub(/^["'\''"]|["'\''"]$/, "");
        print;
        exit;
      }
    ' "${ROOT_DIR}/.env"
  )"
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required. Set it in your shell or add it to ${ROOT_DIR}/.env." >&2
  exit 1
fi

if [[ "${DATABASE_URL}" != *"binary_parameters="* ]]; then
  if [[ "${DATABASE_URL}" == *"?"* ]]; then
    DATABASE_URL="${DATABASE_URL}&binary_parameters=yes"
  else
    DATABASE_URL="${DATABASE_URL}?binary_parameters=yes"
  fi
fi

if [[ "${DATABASE_URL}" != *"search_path="* ]]; then
  if [[ "${DATABASE_URL}" == *"?"* ]]; then
    DATABASE_URL="${DATABASE_URL}&options=-c%20search_path%3Dpublic"
  else
    DATABASE_URL="${DATABASE_URL}?options=-c%20search_path%3Dpublic"
  fi
fi

export DATABASE_URL
export DBMATE_MIGRATIONS_TABLE="${DBMATE_MIGRATIONS_TABLE:-public.schema_migrations}"
export DBMATE_NO_DUMP_SCHEMA="${DBMATE_NO_DUMP_SCHEMA:-true}"

exec dbmate --migrations-dir "${ROOT_DIR}/db/migrations" "$@"
