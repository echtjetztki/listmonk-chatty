#!/bin/sh
# Capture stderr so panics/fatals show up in Vercel logs
exec 2>&1

# Heartbeat: proves the container shell is still alive even if listmonk dies
( i=0; while true; do i=$((i+1)); echo "heartbeat #$i $(date -u +%H:%M:%S)"; sleep 2; done ) &
HB_PID=$!

# Catch termination signals so we can see if Vercel is killing us
trap 'echo "!!! GOT SIGTERM $(date -u +%H:%M:%S) !!!"; kill $HB_PID 2>/dev/null; exit 143' TERM
trap 'echo "!!! GOT SIGINT $(date -u +%H:%M:%S) !!!"; kill $HB_PID 2>/dev/null; exit 130' INT

# Parse the Supabase URL that Vercel already provides
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

# listmonk koanf key is "ssl_mode" (underscore)
export LISTMONK_db__ssl_mode=require
export LISTMONK_db__max_open=2
export LISTMONK_db__max_idle=1
export LISTMONK_db__params="connect_timeout=10"
export LISTMONK_app__address="0.0.0.0:${PORT:-80}"

echo "=== start.sh $(date -u +%H:%M:%S) ==="
echo "DB=${LISTMONK_db__host}:${LISTMONK_db__port}/${LISTMONK_db__database}"
echo "ssl=${LISTMONK_db__ssl_mode} addr=${LISTMONK_app__address} PORT=${PORT:-unset}"
echo "user=${LISTMONK_db__user} pass_len=${#LISTMONK_db__password}"

echo "=== running install $(date -u +%H:%M:%S) ==="
./listmonk --install --idempotent --yes
echo "=== install rc=$? $(date -u +%H:%M:%S) ==="

echo "=== starting server $(date -u +%H:%M:%S) ==="
./listmonk &
SRV_PID=$!
echo "server pid=$SRV_PID"

# Wait for the server process; if it exits, report and restart
while true; do
  if ! kill -0 $SRV_PID 2>/dev/null; then
    wait $SRV_PID 2>/dev/null
    code=$?
    echo "!!! listmonk EXITED code=${code} $(date -u +%H:%M:%S) !!!"
    echo "=== restarting server $(date -u +%H:%M:%S) ==="
    ./listmonk &
    SRV_PID=$!
    echo "server restarted pid=$SRV_PID"
  fi
  sleep 1
done
