#!/bin/sh
# Abre o Autopeças Oficina no navegador. Uso: ./iniciar-linux.sh [--rede]
cd "$(dirname "$0")" || exit 1
chmod +x bin/servidor-linux 2>/dev/null
exec ./bin/servidor-linux "$@"
