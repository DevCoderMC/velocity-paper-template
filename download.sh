#!/usr/bin/env bash
# Lädt die benötigten Server-Jars in der exakt festgelegten Version.
# Wird von start-all.sh automatisch aufgerufen, wenn Jars fehlen.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")" || exit 1

PAPER_URL='https://fill-data.papermc.io/v1/objects/5ffef465eeeb5f2a3c23a24419d97c51afd7dbb4923ff42df9a3f58bba1ccfba/paper-1.21.11-132.jar'
PAPER_SHA='5ffef465eeeb5f2a3c23a24419d97c51afd7dbb4923ff42df9a3f58bba1ccfba'
VELOCITY_URL='https://fill-data.papermc.io/v1/objects/35a5596a5468a035d8a32c8de5ebb0dc6b8d8f0cc3ff5169d514aca762af8aa8/velocity-4.2.0-30.jar'
VELOCITY_SHA='35a5596a5468a035d8a32c8de5ebb0dc6b8d8f0cc3ff5169d514aca762af8aa8'
VIA_VERSION='5.12.1'
VIA_URL="https://github.com/ViaVersion/ViaVersion/releases/download/${VIA_VERSION}/ViaVersion-${VIA_VERSION}.jar"
VIA_SHA='b8033807e7182c35003a45962352dd642c1e91880ca281da3a43cb6f481a95a2'
VIAB_URL="https://github.com/ViaVersion/ViaBackwards/releases/download/${VIA_VERSION}/ViaBackwards-${VIA_VERSION}.jar"
VIAB_SHA='29d94d3a26c85c8a327574b2322db4078992ae457f0173325431a12aac384911'

fetch() { # <url> <sha256> <ziel>
  local url="$1" sha="$2" out="$3"
  mkdir -p "$(dirname "$out")"
  if [ -f "$out" ] && echo "$sha  $out" | sha256sum -c - >/dev/null 2>&1; then
    echo "   vorhanden: $out"
    return 0
  fi
  echo "   lade: $out"
  curl -fL --retry 3 --retry-delay 2 -o "$out" "$url"
  echo "$sha  $out" | sha256sum -c - >/dev/null
}

fetch "$PAPER_URL"    "$PAPER_SHA"    'lobby/paper.jar'
fetch "$PAPER_URL"    "$PAPER_SHA"    'smp/paper.jar'
fetch "$VELOCITY_URL" "$VELOCITY_SHA" 'velocity/velocity.jar'
fetch "$VIA_URL"      "$VIA_SHA"      "lobby/plugins/ViaVersion-${VIA_VERSION}.jar"
fetch "$VIAB_URL"     "$VIAB_SHA"     "lobby/plugins/ViaBackwards-${VIA_VERSION}.jar"
fetch "$VIA_URL"      "$VIA_SHA"      "smp/plugins/ViaVersion-${VIA_VERSION}.jar"
fetch "$VIAB_URL"     "$VIAB_SHA"     "smp/plugins/ViaBackwards-${VIA_VERSION}.jar"

echo ">> Alle Jars sind vorhanden und geprüft."
