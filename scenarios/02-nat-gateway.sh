#!/bin/bash
set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
error() { echo -e "${RED}ERROR: $1${NC}" >&2; }
warn() { echo -e "${YELLOW}WARNING: $1${NC}" >&2; }
info() { echo -e "${GREEN}INFO: $1${NC}"; }

# Scenario metadata
SCENARIO_NAME="NAT Gateway Configuration"
SCENARIO_DESCRIPTION="Demonstrates NAT setup on routers"

show_intro() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Scenario: $SCENARIO_NAME${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "$SCENARIO_DESCRIPTION"
    echo ""
    echo -e "${YELLOW}What this scenario demonstrates:${NC}"
    echo "  1. Setting up SNAT (Source NAT) for outgoing traffic"
    echo "  2. Configuring port forwarding with DNAT"
    echo "  3. Understanding NAT gateway functionality"
    echo ""
}

check_prerequisites() {
    info "Checking prerequisites..."
    if ! docker ps --format '{{.Names}}' | grep -q "router1\|router2"; then
        error "Router containers are not running"
        exit 1
    fi
    info "Prerequisites OK"
    echo ""
}

step1_show_nat_basics() {
    echo -e "${CYAN}═══ Step 1: Understanding NAT Basics ═══${NC}"
    echo ""

    info "NAT (Network Address Translation) rewrites IP addresses in packets"
    echo ""
    echo "Types of NAT:"
    echo "  • SNAT (Source NAT): Changes source IP (for outgoing traffic)"
    echo "  • DNAT (Destination NAT): Changes destination IP (for incoming traffic)"
    echo "  • Masquerading: Dynamic SNAT using interface IP"
    echo ""

    read -p "Press Enter to continue..."
    echo ""
}

step2_setup_snat() {
    echo -e "${CYAN}═══ Step 2: SNAT Configuration on router1 ═══${NC}"
    echo ""

    info "Viewing current NAT rules on router1:"
    docker exec router1 iptables -t nat -L POSTROUTING -n -v
    echo ""

    read -p "Press Enter to apply SNAT rule..."
    echo ""

    info "Enabling IP forwarding on router1..."
    docker exec router1 sysctl -w net.ipv4.ip_forward=1 > /dev/null

    info "Adding SNAT rule: Masquerade traffic from LAN 20 going out eth2"
    docker exec router1 iptables -t nat -A POSTROUTING -s 192.168.20.0/28 -o eth2 -j MASQUERADE

    info "NAT rules after SNAT:"
    docker exec router1 iptables -t nat -L POSTROUTING -n -v
    echo ""

    info "Traffic from LAN 20 will now appear to come from router1's eth2 IP"
    echo ""
}

step3_port_forwarding() {
    echo -e "${CYAN}═══ Step 3: Port Forwarding (DNAT) ═══${NC}"
    echo ""

    read -p "Press Enter to setup port forwarding..."
    echo ""

    info "Example: Forward port 8080 on router2 to server_web:80"
    info "Command: iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to 192.168.60.5:80"
    echo ""

    warn "This is a demonstration - actual port forwarding would require additional network setup"
    echo ""

    info "Viewing PREROUTING rules:"
    docker exec router2 iptables -t nat -L PREROUTING -n -v
    echo ""
}

cleanup() {
    echo -e "${CYAN}═══ Cleanup ═══${NC}"
    echo ""

    info "Clearing NAT rules on router1..."
    docker exec router1 iptables -t nat -F POSTROUTING
    docker exec router1 iptables -t nat -F PREROUTING

    info "Cleanup complete"
    echo ""
}

show_summary() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Scenario Summary${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}What you learned:${NC}"
    echo "  ✓ NAT types and use cases"
    echo "  ✓ SNAT/Masquerading configuration"
    echo "  ✓ Port forwarding concepts"
    echo ""
    echo -e "${YELLOW}Key commands:${NC}"
    echo "  • iptables -t nat -A POSTROUTING -o <iface> -j MASQUERADE"
    echo "  • iptables -t nat -A PREROUTING -p tcp --dport <port> -j DNAT --to <ip>:<port>"
    echo ""
}

main() {
    show_intro
    read -p "Press Enter to start..."
    echo ""

    check_prerequisites
    step1_show_nat_basics
    step2_setup_snat
    step3_port_forwarding
    cleanup
    show_summary
}

if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    main "$@"
fi
