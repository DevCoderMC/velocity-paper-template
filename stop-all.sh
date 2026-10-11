#!/usr/bin/env bash
# Stoppt die Web-Konsole und darüber das gesamte Netzwerk (Velocity, Lobby, SMP).
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")" || exit 1

bash webconsole/stop.sh
