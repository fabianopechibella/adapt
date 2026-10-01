#!/bin/bash
# Duplo clique no Finder abre o Autopeças Oficina no navegador.
cd "$(dirname "$0")"
case "$(uname -m)" in
  arm64) BIN=bin/servidor-mac-arm64 ;;
  *)     BIN=bin/servidor-mac-intel ;;
esac
chmod +x "$BIN" 2>/dev/null
# Remove a quarentena do macOS só dos arquivos deste pacote.
xattr -dr com.apple.quarantine . 2>/dev/null
exec "./$BIN" "$@"
