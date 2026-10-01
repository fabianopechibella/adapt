#!/usr/bin/env bash
# Gera o pacote para rodar localmente (modo demonstração):
#   dist/autopecas-local-<versão>.zip
#     web/                  build web da Oficina
#     iniciar-windows.exe   servidor local + abre o navegador
#     iniciar-mac.command   idem (Apple Silicon e Intel)
#     iniciar-linux.sh      idem
#     android/*.apk         opcional: APKs de teste (passe a pasta como argumento)
#
# Uso: scripts/empacotar.sh [pasta-com-apks]
# Requer: Flutter, Go e zip.
set -euo pipefail

MOBILE="$(cd "$(dirname "$0")/.." && pwd)"
APKS="${1:-}"
VERSAO="$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' "$MOBILE/apps/oficina/pubspec.yaml")"
NOME="autopecas-local-$VERSAO"
DEST="$MOBILE/dist/$NOME"

rm -rf "$DEST" "$MOBILE/dist/$NOME.zip"
mkdir -p "$DEST/bin"

echo "› Build web da Oficina"
(cd "$MOBILE/apps/oficina" && flutter build web --release --no-web-resources-cdn)
cp -R "$MOBILE/apps/oficina/build/web" "$DEST/web"
find "$DEST/web" -name '*.symbols' -delete

echo "› Servidor local (Windows, macOS, Linux)"
SRV="$MOBILE/tools/servidor_local"
build() { (cd "$SRV" && CGO_ENABLED=0 GOOS="$1" GOARCH="$2" go build -trimpath -ldflags "-s -w" -o "$3" .); }
build windows amd64 "$DEST/iniciar-windows.exe"
build darwin  arm64 "$DEST/bin/servidor-mac-arm64"
build darwin  amd64 "$DEST/bin/servidor-mac-intel"
build linux   amd64 "$DEST/bin/servidor-linux"

cp "$MOBILE/tools/pacote_local/"* "$DEST/"
chmod +x "$DEST/iniciar-mac.command" "$DEST/iniciar-linux.sh" "$DEST/bin/"*

if [ -n "$APKS" ] && compgen -G "$APKS/*.apk" > /dev/null; then
  echo "› APKs de teste"
  mkdir -p "$DEST/android"
  cp "$APKS"/*.apk "$DEST/android/"
fi

echo "› Compactando"
(cd "$MOBILE/dist" && zip -qr -X "$NOME.zip" "$NOME")
echo "Pacote: $MOBILE/dist/$NOME.zip ($(du -h "$MOBILE/dist/$NOME.zip" | cut -f1))"
