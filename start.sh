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

# listmonk's koanf key is "ssl_mode" (underscore), NOT "sslmode"
export LISTMONK_db__ssl_mode=require
# Keep the DB footprint tiny: Vercel spins up multiple container instances on
# cold starts and the Supabase pooler limits concurrent connections.
# listmonk's default (max_open=25) exhausts the pooler -> connections hang.
export LISTMONK_db__max_open=2
export LISTMONK_db__max_idle=1
# Fail fast instead of hanging forever when the pooler is full/unreachable.
export LISTMONK_db__params="connect_timeout=10"
export LISTMONK_app__address="0.0.0.0:${PORT:-80}"

echo "=== start.sh $(date -u +%H:%M:%S) DB=${LISTMONK_db__host}:${LISTMONK_db__port}/${LISTMONK_db__database} ssl=${LISTMONK_db__ssl_mode} max_open=2 ==="

./listmonk --install --idempotent --yes
echo "=== install rc=$? $(date -u +%H:%M:%S) ==="

attempt=0
while true; do
  attempt=$((attempt+1))
  echo "=== server attempt ${attempt} $(date -u +%H:%M:%S) ==="
  ./listmonk
  code=$?
  echo "!!! listmonk EXITED code=${code} attempt=${attempt} $(date -u +%H:%M:%S) !!!"
  sleep 3
done
