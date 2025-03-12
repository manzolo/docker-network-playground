#!/bin/bash
# Configura il server web

# Aggiungi le rotte passate tramite variabili d'ambiente
if [ -n "$ROUTES" ]; then
  IFS=',' read -ra ROUTE_ARRAY <<< "$ROUTES"
  for route in "${ROUTE_ARRAY[@]}"; do
    ip route replace $route
  done
fi

nginx -g "daemon off;"