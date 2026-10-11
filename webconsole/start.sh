#!/usr/bin/env bash
# Startet die Web-Konsole im Hintergrund.
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")" || exit 1
mkdir -p logs
PIDFILE="webconsole.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
  echo "Web-Konsole läuft bereits (PID $(cat "$PIDFILE"))."
  exit 0
fi

PORT="$(python3 -c 'import json;print(json.load(open("config.json"))["port"])')"
HOSTADDR="$(python3 -c 'import json;print(json.load(open("config.json")).get("host","127.0.0.1"))')"

nohup python3 server.py >> logs/webconsole.log 2>&1 &
echo $! > "$PIDFILE"

for _ in $(seq 1 60); do
  if curl -s -o /dev/null "http://$HOSTADDR:$PORT/api/state"; then
    echo "Web-Konsole läuft: http://$HOSTADDR:$PORT"
    exit 0
  fi
  sleep 0.25
done

echo "Web-Konsole konnte nicht gestartet werden. Letzte Logzeilen:" >&2
tail -n 20 logs/webconsole.log >&2 2>/dev/null || true
exit 1
