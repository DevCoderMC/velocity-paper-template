#!/usr/bin/env bash
# Stoppt die Web-Konsole und darüber alle Minecraft-Server sauber.
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")" || exit 1
PIDFILE="webconsole.pid"

if [ ! -f "$PIDFILE" ]; then
  echo "Web-Konsole läuft nicht."
  exit 0
fi

PID="$(cat "$PIDFILE" 2>/dev/null || true)"
if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
  echo "Web-Konsole läuft nicht."
  rm -f "$PIDFILE"
  exit 0
fi

echo ">> stoppe Web-Konsole (PID $PID) und alle Server ..."
kill -TERM "$PID"
for _ in $(seq 1 200); do
  kill -0 "$PID" 2>/dev/null || break
  sleep 1
done
if kill -0 "$PID" 2>/dev/null; then
  echo ">> erzwinge Beenden ..."
  kill -KILL "$PID" 2>/dev/null || true
fi
rm -f "$PIDFILE"
echo ">> Web-Konsole gestoppt."
