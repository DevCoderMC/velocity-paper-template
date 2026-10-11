#!/usr/bin/env bash
# Startet den Velocity-Proxy des Netzwerks.
# Spieler verbinden sich ausschließlich mit diesem Port (Standard 25565).
# Benötigt Java 25 oder neuer.
cd "$(dirname "$(readlink -f "$0")")" || exit 1

find_java() {
  local c
  if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    echo "$JAVA_HOME/bin/java"; return
  fi
  for c in /usr/lib/jvm/java-2[5-9]-openjdk-*/bin/java \
           /usr/lib/jvm/jdk-2[5-9]*/bin/java ; do
    [ -x "$c" ] && { echo "$c"; return; }
  done
  command -v java
}

JAVA_BIN="$(find_java)"
if [ -z "$JAVA_BIN" ]; then
  echo "Kein Java gefunden. Bitte JDK 25 oder neuer installieren." >&2
  exit 1
fi

exec "$JAVA_BIN" \
  -Xms512M -Xmx1G \
  -XX:+UseG1GC -XX:G1HeapRegionSize=4M \
  -XX:+ParallelRefProcEnabled -XX:+AlwaysPreTouch \
  -XX:+UnlockExperimentalVMOptions -XX:MaxInlineLevel=15 \
  -jar velocity.jar
