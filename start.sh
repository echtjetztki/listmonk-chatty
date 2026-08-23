#!/bin/sh
# Capture stderr too so panics/fatals show up in Vercel logs
exec 2>&1

# Parse the Supabase URL that Vercel already provides (no new env vars needed).
url="${POSTGRES_URL_NON_POOLING:-$POSTGRES_URL}"

if [ -n "$url" ]; then
  rest="${url#postgres://}"
  userpass="${rest%%@*}"
  export LISTMONK_db__user="${userpass%%:*}"
  export LISTMONK_db__password="${userpass#*:}"
  hostportdb="${rest#*@}"
  hostport="${hostportdb%%/*}"
  export LISTMONK_db__host="${hostport%%:*}"
  export LISTMONK_db__port="${hostport#*:}"
  db="${hostportdb#*/}"
  export LISTMONK_db__database="${db%%\?*}"
fi

# IMPORTANT: listmonk's koanf key is "ssl_mode" (underscore), NOT "sslmode".
# Use "prefer" — Supabase pooler may hang on strict "require" SSL handshake.
# The previous install worked with "disable" (config.toml default).
export LISTMONK_db__ssl_mode=prefer
export LISTMONK_app__address="0.0.0.0:${PORT:-80}"

echo "=== start.sh: DB=${LISTMONK_db__host}:${LISTMONK_db__port}/${LISTMONK_db__database} ssl=${LISTMONK_db__ssl_mode} addr=${LISTMONK_app__address} ==="

./listmonk --install --idempotent --yes
echo "=== install exit code: $? ==="

echo "=== starting server ==="
exec ./listmonk
