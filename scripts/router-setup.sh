#!/bin/bash
# Configura il router
sysctl -w net.ipv4.ip_forward=1

# Disable reverse path filtering which can block inter-LAN traffic
sysctl -w net.ipv4.conf.all.rp_filter=0
sysctl -w net.ipv4.conf.default.rp_filter=0
for iface in /proc/sys/net/ipv4/conf/*/rp_filter; do
    echo 0 > $iface
done

# Allow forwarding between all interfaces
iptables -P FORWARD ACCEPT

# Clear any existing rules that might block forwarding
iptables -F FORWARD

# Explicitly allow forwarding between all interface pairs
for iface in eth0 eth1 eth2; do
  iptables -A FORWARD -i $iface -j ACCEPT
  iptables -A FORWARD -o $iface -j ACCEPT
done

# Allow established connections
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Add MASQUERADE rules to work around Docker bridge isolation
# This makes inter-LAN traffic appear to come from the router
for iface in eth0 eth1 eth2; do
  iptables -t nat -A POSTROUTING -o $iface -j MASQUERADE
done

# Aggiungi le rotte passate tramite variabili d'ambiente
if [ -n "$ROUTES" ]; then
  IFS=',' read -ra ROUTE_ARRAY <<< "$ROUTES"
  for route in "${ROUTE_ARRAY[@]}"; do
    ip route replace $route
  done
fi

# Mantieni il container attivo
/bin/bash