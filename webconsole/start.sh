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
PID=$!
echo "$PID" > "$PIDFILE"

for _ in $(seq 1 60); do
  if ! kill -0 "$PID" 2>/dev/null; then
    echo "Web-Konsole konnte nicht gestartet werden (Prozess sofort beendet)." >&2
    echo "Ist Port $PORT bereits durch ein anderes Programm belegt?" >&2
    tail -n 20 logs/webconsole.log >&2 2>/dev/null || true
    rm -f "$PIDFILE"
    exit 1
  fi
  # Nur eine Antwort der eigenen Instanz (gleiche PID) gilt als Erfolg – nicht
  # irgendein fremdes Programm, das bereits auf dem Port lauscht.
  ANSWER_PID="$(curl -s --max-time 1 "http://$HOSTADDR:$PORT/api/state" 2>/dev/null \
    | python3 -c 'import sys, json
try:
    print(json.load(sys.stdin).get("console", {}).get("pid", ""))
except Exception:
    print("")' 2>/dev/null)"
  if [ "$ANSWER_PID" = "$PID" ]; then
    echo "Web-Konsole läuft: http://$HOSTADDR:$PORT"
    exit 0
  fi
  sleep 0.25
done

echo "Web-Konsole konnte nicht gestartet werden." >&2
echo "Antwortet auf Port $PORT bereits ein anderes Programm? (eigene PID: $PID)" >&2
tail -n 20 logs/webconsole.log >&2 2>/dev/null || true
kill "$PID" 2>/dev/null || true
rm -f "$PIDFILE"
exit 1
