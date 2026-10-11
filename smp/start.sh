#!/usr/bin/env bash
# Startet diesen Paper-Server (Backend hinter dem Velocity-Proxy).
cd "$(dirname "$(readlink -f "$0")")" || exit 1

JAVA_BIN="${JAVA_HOME:+$JAVA_HOME/bin/java}"
[ -x "$JAVA_BIN" ] || JAVA_BIN="$(command -v java)"

exec "$JAVA_BIN" \
  -Xms2G -Xmx4G \
  -XX:+AlwaysPreTouch \
  -XX:+DisableExplicitGC \
  -XX:+ParallelRefProcEnabled \
  -XX:+PerfDisableSharedMem \
  -XX:+UnlockExperimentalVMOptions \
  -XX:+UseG1GC \
  -XX:G1HeapRegionSize=8M \
  -XX:G1HeapWastePercent=5 \
  -XX:G1MaxNewSizePercent=40 \
  -XX:G1MixedGCCountTarget=4 \
  -XX:G1MixedGCLiveThresholdPercent=90 \
  -XX:G1NewSizePercent=30 \
  -XX:G1RSetUpdatingPauseTimePercent=5 \
  -XX:G1ReservePercent=20 \
  -XX:InitiatingHeapOccupancyPercent=15 \
  -XX:MaxGCPauseMillis=200 \
  -XX:MaxTenuringThreshold=1 \
  -XX:SurvivorRatio=32 \
  -Dusing.aikars.flags=https://mcflags.emc.gs \
  -Daikars.new.flags=true \
  -jar paper.jar --nogui
