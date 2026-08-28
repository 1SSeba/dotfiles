#!/usr/bin/env bash
# Recompila el shim. Casi nunca hace falta: no linkea Qt, todo se resuelve por
# dlopen/dlsym en runtime. Solo si Qt cambiara los símbolos mangleados.
# A propósito no linkea Qt: todo se resuelve con dlopen/dlsym en runtime, así los
# procesos hijos de la shell no arrastran las libs.
set -euo pipefail
cd "$(dirname "$0")"
g++ -shared -fPIC -O2 -o libqs-webengine-shim.so qs_webengine_shim.cpp -ldl
echo "ok: $(pwd)/libqs-webengine-shim.so"
