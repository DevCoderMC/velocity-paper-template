#!/usr/bin/env bash
# Setzt das Netzwerk auf einen frischen Template-Zustand zurück:
# entfernt alle Welten, Spielerdaten und Laufzeitdateien.
#   ./reset.sh        -> fragt nach Bestätigung
#   ./reset.sh -y     -> ohne Nachfrage
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")" || exit 1

if [ "${1:-}" != "-y" ] && [ "${1:-}" != "--yes" ]; then
  read -r -p "Wirklich alle Welten und Spielerdaten löschen? [j/N] " antwort
  case "$antwort" in
    j | J | y | Y) ;;
    *)
      echo "Abgebrochen."
      exit 0
      ;;
  esac
fi

echo ">> Server stoppen ..."
bash stop-all.sh 2>/dev/null || true

rm -rf -- \
  lobby/world lobby/world_nether lobby/world_the_end \
  smp/world smp/world_nether smp/world_the_end \
  lobby/logs smp/logs velocity/logs \
  lobby/cache smp/cache \
  lobby/libraries smp/libraries \
  lobby/versions smp/versions \
  lobby/usercache.json smp/usercache.json \
  lobby/ops.json smp/ops.json \
  lobby/whitelist.json smp/whitelist.json \
  lobby/banned-ips.json lobby/banned-players.json \
  smp/banned-ips.json smp/banned-players.json \
  lobby/version_history.json smp/version_history.json \
  lobby/.console_history smp/.console_history velocity/.console_history \
  webconsole/logs webconsole/webconsole.pid

# Plugin-Laufzeitdaten (Konfigordner); die Plugin-Jars bleiben erhalten.
rm -rf -- lobby/plugins/*/ smp/plugins/*/ velocity/plugins/*/

echo ">> Fertig: keine Spielerdaten mehr vorhanden."
