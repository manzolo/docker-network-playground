#!/bin/bash
set -euo pipefail

# Aggiungi le rotte passate tramite variabili d'ambiente
if [ -n "${ROUTES:-}" ]; then
  IFS=',' read -ra ROUTE_ARRAY <<< "$ROUTES"
  for route in "${ROUTE_ARRAY[@]}"; do
    ip route replace $route
  done
fi

# Mantieni il container attivo
exec /bin/bash