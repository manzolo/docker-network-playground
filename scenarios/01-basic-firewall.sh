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

# Scenario metadata
SCENARIO_NAME="Basic Firewall Configuration"
SCENARIO_DESCRIPTION="Demonstrates basic firewall rules using iptables on router1"

# Display scenario intro
show_intro() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Scenario: $SCENARIO_NAME${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "$SCENARIO_DESCRIPTION"
    echo ""
    echo -e "${YELLOW}What this scenario demonstrates:${NC}"
    echo "  1. Blocking ICMP (ping) from a specific host"
    echo "  2. Rate limiting to prevent ping floods"
    echo "  3. Port filtering (blocking specific ports)"
    echo "  4. Firewall rule verification"
    echo ""
    echo -e "${YELLOW}Target container:${NC} router1"
    echo -e "${YELLOW}Test hosts:${NC} pc1, pc2, pc3"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."

    # Check if containers are running
    if ! docker ps --format '{{.Names}}' | grep -q "router1"; then
        error "router1 container is not running"
        echo "Please start containers with: docker compose up -d"
        exit 1
    fi

    if ! docker ps --format '{{.Names}}' | grep -q "pc1"; then
        error "pc1 container is not running"
        echo "Please start containers with: docker compose up -d"
        exit 1
    fi

    info "Prerequisites OK"
    echo ""
}

# Step 1: Block ICMP from pc1
step1_block_icmp() {
    echo -e "${CYAN}═══ Step 1: Block ICMP from pc1 (192.168.20.3) ═══${NC}"
    echo ""

    info "Before applying rule:"
    echo "Testing: pc1 → router1 ping"
    if docker exec pc1 ping -c 2 -W 2 192.168.20.2 &>/dev/null; then
        echo -e "  ${GREEN}✓ Ping successful (as expected before blocking)${NC}"
    else
        echo -e "  ${RED}✗ Ping failed (unexpected)${NC}"
    fi
    echo ""

    read -p "Press Enter to apply firewall rule..."
    echo ""

    info "Applying firewall rule on router1: Block ICMP from 192.168.20.3"
    docker exec router1 iptables -A INPUT -p icmp -s 192.168.20.3 -j DROP

    info "Showing router1 firewall rules:"
    docker exec router1 iptables -L INPUT -n -v --line-numbers
    echo ""

    info "After applying rule:"
    echo "Testing: pc1 → router1 ping"
    if docker exec pc1 ping -c 2 -W 2 192.168.20.2 &>/dev/null; then
        echo -e "  ${YELLOW}⚠ Ping still works (rule may not be effective)${NC}"
    else
        echo -e "  ${GREEN}✓ Ping blocked (firewall rule working!)${NC}"
    fi
    echo ""

    info "Note: pc2 can still ping router1:"
    if docker exec pc2 ping -c 2 -W 2 192.168.20.2 &>/dev/null; then
        echo -e "  ${GREEN}✓ pc2 → router1 ping successful (as expected)${NC}"
    fi
    echo ""
}

# Step 2: Rate limiting
step2_rate_limiting() {
    echo -e "${CYAN}═══ Step 2: ICMP Rate Limiting ═══${NC}"
    echo ""

    read -p "Press Enter to continue with rate limiting..."
    echo ""

    info "First, clearing previous rules..."
    docker exec router1 iptables -F INPUT

    info "Applying rate limiting: 5 pings per second"
    docker exec router1 iptables -A INPUT -p icmp -m limit --limit 5/second --limit-burst 10 -j ACCEPT
    docker exec router1 iptables -A INPUT -p icmp -j DROP

    info "Showing router1 firewall rules:"
    docker exec router1 iptables -L INPUT -n -v --line-numbers
    echo ""

    info "Testing rate limit with flood ping from pc1:"
    echo "Running: ping -f for 3 seconds (this generates many packets)"
    echo ""

    # Run flood ping in background and capture packet count
    timeout 3 docker exec pc1 ping -c 100 -i 0.01 192.168.20.2 2>/dev/null | grep "transmitted" || true

    echo ""
    info "Rate limiting in action - only ~15 packets should get through (5/sec × 3 sec)"
    echo ""
}

# Step 3: Port filtering
step3_port_filtering() {
    echo -e "${CYAN}═══ Step 3: Port Filtering ═══${NC}"
    echo ""

    read -p "Press Enter to continue with port filtering..."
    echo ""

    info "Clearing previous rules..."
    docker exec router1 iptables -F INPUT

    info "Blocking TCP port 80 (HTTP) on router1"
    docker exec router1 iptables -A INPUT -p tcp --dport 80 -j DROP

    info "Showing router1 firewall rules:"
    docker exec router1 iptables -L INPUT -n -v --line-numbers
    echo ""

    warn "Note: This blocks port 80 on router1 itself"
    warn "The web server (server_web) on a different host is not affected"
    echo ""
}

# Cleanup
cleanup() {
    echo -e "${CYAN}═══ Cleanup ═══${NC}"
    echo ""

    info "Clearing all firewall rules on router1..."
    docker exec router1 iptables -F INPUT
    docker exec router1 iptables -P INPUT ACCEPT

    info "Verifying cleanup:"
    docker exec router1 iptables -L INPUT -n
    echo ""

    info "Testing connectivity after cleanup:"
    if docker exec pc1 ping -c 2 -W 2 192.168.20.2 &>/dev/null; then
        echo -e "  ${GREEN}✓ pc1 → router1 ping successful (firewall cleared)${NC}"
    else
        echo -e "  ${RED}✗ Ping still blocked (unexpected)${NC}"
    fi
    echo ""

    info "Scenario complete!"
}

# Show summary
show_summary() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Scenario Summary${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}What you learned:${NC}"
    echo "  ✓ How to block ICMP from specific hosts"
    echo "  ✓ How to implement rate limiting to prevent floods"
    echo "  ✓ How to filter traffic by port"
    echo "  ✓ How to verify firewall rules"
    echo "  ✓ How to clean up firewall configuration"
    echo ""
    echo -e "${YELLOW}Key commands used:${NC}"
    echo "  • iptables -A INPUT -p icmp -s <ip> -j DROP"
    echo "  • iptables -A INPUT -p icmp -m limit --limit <rate> -j ACCEPT"
    echo "  • iptables -A INPUT -p tcp --dport <port> -j DROP"
    echo "  • iptables -L INPUT -n -v --line-numbers"
    echo "  • iptables -F INPUT"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  • Try the NAT gateway scenario (02-nat-gateway.sh)"
    echo "  • Read docs/NETWORKING-BASICS.md for more info"
    echo "  • Practice exercises in docs/EXERCISES.md"
    echo ""
}

# Main execution
main() {
    show_intro

    read -p "Press Enter to start the scenario (or Ctrl+C to cancel)..."
    echo ""

    check_prerequisites

    step1_block_icmp
    step2_rate_limiting
    step3_port_filtering

    cleanup
    show_summary
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    main "$@"
fi
