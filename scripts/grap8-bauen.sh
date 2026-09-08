#!/usr/bin/env bash
# Baut die Grap8-Leinwand aus ~/Projekte/grap8-canvas und legt sie nach Grap8Web/.
#
# Grap8Web/ ist eine Folder Reference im Xcode-Projekt und liegt bewusst IM Repo:
# nur so baut die App ohne das Web-Projekt daneben. Nach jeder Änderung an der
# Leinwand dieses Skript laufen lassen und das Ergebnis mitcommitten.
set -euo pipefail

QUELLE="${GRAP8_QUELLE:-$HOME/Projekte/grap8-canvas}"
ZIEL="$(cd "$(dirname "$0")/.." && pwd)/Grap8Web"

[ -d "$QUELLE" ] || { echo "Web-Projekt nicht gefunden: $QUELLE"; exit 1; }

cd "$QUELLE"
[ -d node_modules ] || npm install --include=dev
npm run build

# base: './' muss in vite.config.js stehen — absolute /assets/… ergeben im
# App-Bundle einen weißen Schirm.
grep -q '"\./assets/' dist/index.html || {
  echo "FEHLER: dist/index.html hat keine relativen Pfade. Fehlt base: './' in vite.config.js?"
  exit 1
}

rsync -a --delete dist/ "$ZIEL/"
echo "Grap8Web aktualisiert:"
find "$ZIEL" -type f | sed "s|$ZIEL|  Grap8Web|"
