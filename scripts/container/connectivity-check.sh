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
if [ -f /.dockerenv ]; then
    CONTEXT="container"
else
    CONTEXT="host"
    error "This script must be run inside a container"
    echo "Usage: docker exec <container_name> /bin/bash /path/to/connectivity-check.sh"
    exit 1
fi

# Get container information
get_container_info() {
    echo -e "${CYAN}=== Container Information ===${NC}"
    echo ""

    # Hostname
    echo "Hostname: $(hostname)"

    # IP addresses
    echo ""
    echo "IP Addresses:"
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | while read -r ip; do
        echo "  - $ip"
    done

    # Default gateway
    echo ""
    echo "Default Gateway:"
    ip route | grep default | awk '{print "  - " $3 " (via " $5 ")"}'

    # DNS servers
    echo ""
    echo "DNS Servers:"
    if [ -f /etc/resolv.conf ]; then
        grep "^nameserver" /etc/resolv.conf | awk '{print "  - " $2}'
    fi

    echo ""
}

# Check connectivity to a target
check_connectivity() {
    local target=$1
    local description=$2

    echo -n "  Testing $description ($target): "

    if ping -c 1 -W 2 "$target" &>/dev/null; then
        # Get RTT
        rtt=$(ping -c 1 -W 2 "$target" 2>/dev/null | grep "time=" | sed 's/.*time=\([0-9.]*\).*/\1/')
        echo -e "${GREEN}✓ OK${NC} (${rtt}ms)"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        return 1
    fi
}

# Check DNS resolution
check_dns() {
    local hostname=$1
    local description=$2

    echo -n "  Resolving $description ($hostname): "

    if resolved_ip=$(nslookup "$hostname" 2>/dev/null | grep -A1 "Name:" | grep "Address" | awk '{print $2}' | head -1); then
        echo -e "${GREEN}✓ OK${NC} → $resolved_ip"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        return 1
    fi
}

# Check HTTP connectivity
check_http() {
    local url=$1
    local description=$2

    echo -n "  HTTP GET $description ($url): "

    if response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null); then
        if [ "$response" -ge 200 ] && [ "$response" -lt 400 ]; then
            echo -e "${GREEN}✓ OK${NC} (HTTP $response)"
            return 0
        else
            echo -e "${YELLOW}⚠ WARN${NC} (HTTP $response)"
            return 1
        fi
    else
        echo -e "${RED}✗ FAIL${NC}"
        return 1
    fi
}

# Display routing table
show_routing_table() {
    echo -e "${CYAN}=== Routing Table ===${NC}"
    echo ""

    echo "Destination     Gateway         Genmask         Interface"
    echo "---------------------------------------------------------------"
    route -n | grep -v "Kernel" | grep -v "Destination" | awk '{printf "%-15s %-15s %-15s %-10s\n", $1, $2, $3, $8}'

    echo ""
}

# Main connectivity tests
run_connectivity_tests() {
    echo -e "${CYAN}=== Connectivity Tests ===${NC}"
    echo ""

    # Test gateway
    info "Testing Gateway:"
    gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    if [ -n "$gateway" ]; then
        check_connectivity "$gateway" "Default Gateway"
    else
        warn "  No default gateway configured"
    fi

    echo ""

    # Test DNS server
    info "Testing DNS Server:"
    dns_server=$(grep "^nameserver" /etc/resolv.conf | head -1 | awk '{print $2}')
    if [ -n "$dns_server" ]; then
        check_connectivity "$dns_server" "DNS Server"
    else
        warn "  No DNS server configured"
    fi

    echo ""

    # Test common targets based on network
    info "Testing Common Targets:"

    # Determine network by IP
    my_ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -1)

    if [[ "$my_ip" == 192.168.20.* ]]; then
        # LAN 20
        check_connectivity "192.168.30.3" "pc3 (LAN 30)"
        check_connectivity "192.168.60.5" "server_web (LAN 60)"
    elif [[ "$my_ip" == 192.168.30.* ]]; then
        # LAN 30
        check_connectivity "192.168.20.3" "pc1 (LAN 20)"
        check_connectivity "192.168.60.5" "server_web (LAN 60)"
    elif [[ "$my_ip" == 192.168.40.* ]]; then
        # LAN 40
        check_connectivity "192.168.20.3" "pc1 (LAN 20)"
        check_connectivity "192.168.60.5" "server_web (LAN 60)"
    elif [[ "$my_ip" == 192.168.60.* ]]; then
        # LAN 60
        check_connectivity "192.168.20.3" "pc1 (LAN 20)"
        check_connectivity "192.168.40.3" "pc4 (LAN 40)"
    fi

    echo ""
}

# DNS resolution tests
run_dns_tests() {
    echo -e "${CYAN}=== DNS Resolution Tests ===${NC}"
    echo ""

    info "Testing Hostname Resolution:"
    check_dns "dnsmasq" "DNS Server"
    check_dns "router1" "Router 1"
    check_dns "pc1" "PC 1"
    check_dns "server_web" "Web Server"

    echo ""
}

# HTTP tests
run_http_tests() {
    echo -e "${CYAN}=== HTTP Tests ===${NC}"
    echo ""

    info "Testing Web Server:"

    # Check if curl is available
    if ! command -v curl &>/dev/null; then
        warn "  curl not available, skipping HTTP tests"
        echo ""
        return
    fi

    check_http "http://server_web" "Web Server (hostname)"
    check_http "http://192.168.60.5" "Web Server (IP)"

    echo ""
}

# Main function
main() {
    clear
    echo "========================================="
    info "Network Connectivity Check"
    echo "========================================="
    echo ""

    get_container_info
    show_routing_table
    run_connectivity_tests
    run_dns_tests
    run_http_tests

    echo "========================================="
    info "Check complete!"
    echo "========================================="
}

main "$@"
