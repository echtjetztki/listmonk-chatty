#!/bin/sh
# Capture stderr too so panics/fatals show up in Vercel logs
exec 2>&1

# Parse the Supabase URL that Vercel already provides (no new env vars needed).
# Format: postgres://user:password@host:port/database?sslmode=require
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

# listmonk's koanf key is "ssl_mode" (underscore), NOT "sslmode"
export LISTMONK_db__ssl_mode=require
export LISTMONK_app__address="0.0.0.0:${PORT:-80}"

echo "=== start.sh: DB=${LISTMONK_db__host}:${LISTMONK_db__port}/${LISTMONK_db__database} ssl=${LISTMONK_db__ssl_mode} addr=${LISTMONK_app__address} PORT=${PORT:-unset} ==="

./listmonk --install --idempotent --yes
echo "=== install exit code: $? ==="

echo "=== starting server under supervisor loop ==="
attempt=0
while true; do
  attempt=$((attempt+1))
  echo "=== server attempt ${attempt} starting ==="
  ./listmonk
  code=$?
  echo "!!! listmonk server EXITED code=${code} attempt=${attempt} !!!"
  # Keep the container alive and give Vercel log streaming time to flush.
  sleep 3
done
