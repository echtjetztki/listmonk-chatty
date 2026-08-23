#!/bin/sh
set -e

# Parse the Supabase URL that Vercel already provides (no new env vars needed).
# Format: postgres://user:password@host:port/database?sslmode=require
url="${POSTGRES_URL_NON_POOLING:-$POSTGRES_URL}"

if [ -n "$url" ]; then
  # Strip scheme
  rest="${url#postgres://}"

  # user:password
  userpass="${rest%%@*}"
  export LISTMONK_db__user="${userpass%%:*}"
  export LISTMONK_db__password="${userpass#*:}"

  # host:port/database
  hostportdb="${rest#*@}"
  hostport="${hostportdb%%/*}"
  export LISTMONK_db__host="${hostport%%:*}"
  export LISTMONK_db__port="${hostport#*:}"

  # database (strip query string)
  db="${hostportdb#*/}"
  export LISTMONK_db__database="${db%%\?*}"
fi

export LISTMONK_db__sslmode=require
export LISTMONK_app__address="0.0.0.0:${PORT:-80}"

echo "Starting listmonk on ${LISTMONK_app__address}"
./listmonk --install --idempotent --yes
echo "Install complete, starting server..."
exec ./listmonk
