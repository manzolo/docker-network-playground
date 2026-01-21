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
SCENARIO_NAME="Network Problems Simulation"
SCENARIO_DESCRIPTION="Simulates various network issues using tc (traffic control)"

show_intro() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Scenario: $SCENARIO_NAME${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "$SCENARIO_DESCRIPTION"
    echo ""
    echo -e "${YELLOW}What this scenario demonstrates:${NC}"
    echo "  1. Adding network latency (delay)"
    echo "  2. Simulating packet loss"
    echo "  3. Creating unstable network conditions"
    echo "  4. Testing application behavior under stress"
    echo ""
}

check_prerequisites() {
    info "Checking prerequisites..."
    if ! docker ps --format '{{.Names}}' | grep -q "router1\|pc1"; then
        error "Required containers are not running"
        exit 1
    fi
    info "Prerequisites OK"
    echo ""
}

step1_add_latency() {
    echo -e "${CYAN}═══ Step 1: Adding Network Latency ═══${NC}"
    echo ""

    info "Testing baseline latency from pc1 to server_web:"
    docker exec pc1 ping -c 5 192.168.60.5 | grep "avg" || true
    echo ""

    read -p "Press Enter to add 100ms latency on router1..."
    echo ""

    info "Adding 100ms latency to router1's eth0 interface..."
    docker exec router1 tc qdisc add dev eth0 root netem delay 100ms

    info "Showing tc configuration:"
    docker exec router1 tc qdisc show dev eth0
    echo ""

    info "Testing latency after adding delay:"
    docker exec pc1 ping -c 5 192.168.60.5 | grep "avg" || true
    echo ""

    info "Notice the ~100ms increase in round-trip time!"
    echo ""
}

step2_packet_loss() {
    echo -e "${CYAN}═══ Step 2: Simulating Packet Loss ═══${NC}"
    echo ""

    read -p "Press Enter to add packet loss..."
    echo ""

    info "Resetting router1 tc rules..."
    docker exec router1 tc qdisc del dev eth0 root 2>/dev/null || true

    info "Adding 20% packet loss on router1's eth0..."
    docker exec router1 tc qdisc add dev eth0 root netem loss 20%

    info "Testing with packet loss (notice missing responses):"
    docker exec pc1 ping -c 10 192.168.60.5 | tail -2
    echo ""

    info "Approximately 20% of packets should be lost"
    echo ""
}

step3_unstable_network() {
    echo -e "${CYAN}═══ Step 3: Unstable Network (Latency + Jitter + Loss) ═══${NC}"
    echo ""

    read -p "Press Enter to simulate unstable network..."
    echo ""

    info "Resetting router1 tc rules..."
    docker exec router1 tc qdisc del dev eth0 root 2>/dev/null || true

    info "Adding: 50ms latency ± 25ms jitter + 10% packet loss"
    docker exec router1 tc qdisc add dev eth0 root netem delay 50ms 25ms loss 10%

    info "Showing tc configuration:"
    docker exec router1 tc qdisc show dev eth0
    echo ""

    info "Testing unstable network (notice variable latency):"
    docker exec pc1 ping -c 10 192.168.60.5
    echo ""

    warn "This simulates a poor quality connection (like congested WiFi)"
    echo ""
}

cleanup() {
    echo -e "${CYAN}═══ Cleanup ═══${NC}"
    echo ""

    info "Removing all tc rules from router1..."
    docker exec router1 tc qdisc del dev eth0 root 2>/dev/null || true

    info "Testing network after cleanup:"
    docker exec pc1 ping -c 3 192.168.60.5 | grep "avg" || true
    echo ""

    info "Network restored to normal!"
    echo ""
}

show_summary() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Scenario Summary${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}What you learned:${NC}"
    echo "  ✓ How to simulate network latency"
    echo "  ✓ How to simulate packet loss"
    echo "  ✓ How to create unstable network conditions"
    echo "  ✓ How network issues affect connectivity"
    echo ""
    echo -e "${YELLOW}Key commands:${NC}"
    echo "  • tc qdisc add dev <iface> root netem delay <time>"
    echo "  • tc qdisc add dev <iface> root netem loss <percent>%"
    echo "  • tc qdisc add dev <iface> root netem delay <time> <jitter> loss <percent>%"
    echo ""
    echo -e "${BLUE}Use cases:${NC}"
    echo "  • Testing application resilience"
    echo "  • Simulating mobile networks"
    echo "  • Educational demonstrations"
    echo ""
}

main() {
    show_intro
    read -p "Press Enter to start..."
    echo ""

    check_prerequisites
    step1_add_latency
    step2_packet_loss
    step3_unstable_network
    cleanup
    show_summary
}

if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    main "$@"
fi
