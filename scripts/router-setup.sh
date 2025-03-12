#!/bin/bash
# Configura il router
sysctl -w net.ipv4.ip_forward=1

# Aggiungi le rotte passate tramite variabili d'ambiente
if [ -n "$ROUTES" ]; then
  IFS=',' read -ra ROUTE_ARRAY <<< "$ROUTES"
  for route in "${ROUTE_ARRAY[@]}"; do
    ip route replace $route
  done
fi

# Mantieni il container attivo
/bin/bash