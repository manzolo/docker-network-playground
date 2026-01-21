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
debug() { echo -e "${BLUE}DEBUG: $1${NC}"; }

# Detect context
if [ ! -f /.dockerenv ]; then
    error "This script must be run inside a container (preferably a router)"
    echo "Usage: docker exec <router_container> /scripts/container/nat-setup.sh <command>"
    exit 1
fi

# Show current NAT rules
show_nat() {
    echo -e "${CYAN}=== Current NAT Rules ===${NC}"
    echo ""
    echo "NAT table (PREROUTING):"
    iptables -t nat -L PREROUTING -n -v --line-numbers
    echo ""
    echo "NAT table (POSTROUTING):"
    iptables -t nat -L POSTROUTING -n -v --line-numbers
    echo ""
    echo "NAT table (OUTPUT):"
    iptables -t nat -L OUTPUT -n -v --line-numbers
}

# Setup SNAT (Source NAT) - masquerading
setup_snat() {
    local out_interface=$1

    info "Setting up SNAT (masquerading) on interface $out_interface"

    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1 > /dev/null

    # Add SNAT rule
    iptables -t nat -A POSTROUTING -o "$out_interface" -j MASQUERADE

    info "SNAT configured successfully"
    info "All outgoing traffic on $out_interface will be masqueraded"
    echo ""

    show_nat
}

# Setup SNAT with specific source IP
setup_snat_ip() {
    local out_interface=$1
    local nat_ip=$2

    info "Setting up SNAT on interface $out_interface with IP $nat_ip"

    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1 > /dev/null

    # Add SNAT rule with specific IP
    iptables -t nat -A POSTROUTING -o "$out_interface" -j SNAT --to-source "$nat_ip"

    info "SNAT configured successfully"
    info "All outgoing traffic on $out_interface will use source IP: $nat_ip"
    echo ""

    show_nat
}

# Setup DNAT (Destination NAT) - port forwarding
setup_dnat() {
    local external_port=$1
    local internal_ip=$2
    local internal_port=$3
    local protocol=${4:-tcp}

    info "Setting up DNAT (port forwarding)"
    info "  External port: $external_port ($protocol)"
    info "  Internal destination: $internal_ip:$internal_port"

    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1 > /dev/null

    # Add DNAT rule
    iptables -t nat -A PREROUTING -p "$protocol" --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port"

    # Allow forwarding
    iptables -A FORWARD -p "$protocol" -d "$internal_ip" --dport "$internal_port" -j ACCEPT

    info "DNAT configured successfully"
    info "Traffic to port $external_port will be forwarded to $internal_ip:$internal_port"
    echo ""

    show_nat
}

# Setup full NAT gateway for a network
setup_nat_gateway() {
    local internal_network=$1
    local external_interface=$2

    info "Setting up NAT gateway for network $internal_network"
    info "  External interface: $external_interface"

    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1 > /dev/null

    # Allow forwarding for internal network
    iptables -A FORWARD -s "$internal_network" -j ACCEPT
    iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Setup masquerading
    iptables -t nat -A POSTROUTING -s "$internal_network" -o "$external_interface" -j MASQUERADE

    info "NAT gateway configured successfully"
    info "Network $internal_network can now access external networks via $external_interface"
    echo ""

    show_nat
}

# Clear all NAT rules
clear_nat() {
    warn "Clearing all NAT rules..."

    iptables -t nat -F PREROUTING
    iptables -t nat -F POSTROUTING
    iptables -t nat -F OUTPUT
    iptables -F FORWARD

    info "NAT rules cleared"
    echo ""

    show_nat
}

# Example: Router1 as NAT gateway for LAN 20
example_router1_nat() {
    info "Example: Configuring router1 as NAT gateway for LAN 20"
    echo ""

    warn "This will configure:"
    warn "  - SNAT for LAN 20 (192.168.20.0/28) via eth2 (transit_12)"
    warn "  - Allows LAN 20 hosts to access other networks"
    echo ""

    read -p "Continue? (y/n): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warn "Cancelled"
        exit 0
    fi

    setup_nat_gateway "192.168.20.0/28" "eth2"
}

# Example: Port forwarding HTTP to server_web
example_port_forward() {
    info "Example: Port forwarding HTTP (8080) to server_web (192.168.60.5:80)"
    echo ""

    warn "This will configure:"
    warn "  - Forward external port 8080 to 192.168.60.5:80"
    warn "  - Allows access to web server via router's IP:8080"
    echo ""

    read -p "Continue? (y/n): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warn "Cancelled"
        exit 0
    fi

    setup_dnat 8080 "192.168.60.5" 80 tcp
}

# Show help
show_help() {
    cat << EOF
${CYAN}=== NAT Setup Script ===${NC}

Usage: $0 <command> [arguments]

Commands:
  show                                    - Show current NAT rules
  clear                                   - Clear all NAT rules

  snat <out_interface>                    - Setup SNAT (masquerading) on interface
  snat-ip <out_interface> <nat_ip>        - Setup SNAT with specific source IP

  dnat <ext_port> <int_ip> <int_port> [proto]
                                          - Setup DNAT (port forwarding)
                                            proto: tcp (default) or udp

  nat-gateway <network> <ext_interface>   - Setup full NAT gateway for a network

  example-router1                         - Example: Router1 as NAT gateway
  example-portforward                     - Example: Port forwarding to web server

Examples:
  # Show current NAT rules
  $0 show

  # Setup SNAT on eth2 (masquerading)
  $0 snat eth2

  # Setup SNAT with specific IP
  $0 snat-ip eth2 192.168.100.2

  # Forward port 8080 to 192.168.60.5:80
  $0 dnat 8080 192.168.60.5 80 tcp

  # Setup router as NAT gateway
  $0 nat-gateway 192.168.20.0/28 eth2

  # Run examples
  $0 example-router1
  $0 example-portforward

  # Clear all rules
  $0 clear

${YELLOW}Prerequisites:${NC}
  - IP forwarding must be enabled (script enables it automatically)
  - Must be run on a router container with iptables support
  - Requires privileged container mode

${YELLOW}Notes:${NC}
  - NAT rules do not persist across container restarts
  - Use 'show' to verify rules are applied correctly
  - Use 'clear' to remove all NAT rules

${CYAN}NAT Types:${NC}
  - SNAT (Source NAT): Changes source IP of outgoing packets
    Use case: Allow internal network to access external networks

  - DNAT (Destination NAT): Changes destination IP/port of incoming packets
    Use case: Port forwarding, load balancing

EOF
}

# Main execution
main() {
    # Check for iptables
    if ! command -v iptables &> /dev/null; then
        error "iptables is not available in this container"
        exit 1
    fi

    # Parse command
    case "${1:-help}" in
        show)
            show_nat
            ;;
        clear)
            clear_nat
            ;;
        snat)
            if [ -z "${2:-}" ]; then
                error "Missing output interface"
                echo "Usage: $0 snat <out_interface>"
                exit 1
            fi
            setup_snat "$2"
            ;;
        snat-ip)
            if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
                error "Missing arguments"
                echo "Usage: $0 snat-ip <out_interface> <nat_ip>"
                exit 1
            fi
            setup_snat_ip "$2" "$3"
            ;;
        dnat)
            if [ -z "${2:-}" ] || [ -z "${3:-}" ] || [ -z "${4:-}" ]; then
                error "Missing arguments"
                echo "Usage: $0 dnat <ext_port> <int_ip> <int_port> [protocol]"
                exit 1
            fi
            setup_dnat "$2" "$3" "$4" "${5:-tcp}"
            ;;
        nat-gateway)
            if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
                error "Missing arguments"
                echo "Usage: $0 nat-gateway <network> <ext_interface>"
                exit 1
            fi
            setup_nat_gateway "$2" "$3"
            ;;
        example-router1)
            example_router1_nat
            ;;
        example-portforward)
            example_port_forward
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
