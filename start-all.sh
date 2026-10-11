#!/usr/bin/env bash
# Startet die Web-Konsole, die das gesamte Netzwerk steuert.
# Fehlende Server-Jars werden vorher automatisch heruntergeladen.
# Die Minecraft-Server werden von der Konsole mitgestartet
# (siehe webconsole/config.json -> autoStart).
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")" || exit 1

# Jars prüfen (die Konsole startet die Server aus lobby/, smp/ und velocity/).
missing=0
[ -f lobby/paper.jar ] || missing=1
[ -f smp/paper.jar ] || missing=1
[ -f velocity/velocity.jar ] || missing=1
ls lobby/plugins/*.jar >/dev/null 2>&1 || missing=1
ls smp/plugins/*.jar >/dev/null 2>&1 || missing=1
if [ "$missing" = 1 ]; then
  echo ">> Server-Jars fehlen, lade sie herunter ..."
  bash download.sh
fi

bash webconsole/start.sh

PORT="$(python3 -c 'import json;print(json.load(open("webconsole/config.json"))["port"])')"
HOSTADDR="$(python3 -c 'import json;print(json.load(open("webconsole/config.json")).get("host","127.0.0.1"))')"

cat <<EOF

Web-Konsole:  http://$HOSTADDR:$PORT
Dort lassen sich Server starten/stoppen, Logs verfolgen und Befehle senden.

Alles stoppen:  ./stop-all.sh
EOF
