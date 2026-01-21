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
SCENARIO_NAME="Traffic Generation and Testing"
SCENARIO_DESCRIPTION="Generates various types of network traffic for testing"

show_intro() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Scenario: $SCENARIO_NAME${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "$SCENARIO_DESCRIPTION"
    echo ""
    echo -e "${YELLOW}What this scenario demonstrates:${NC}"
    echo "  1. HTTP traffic generation to web server"
    echo "  2. Continuous connectivity testing with ping"
    echo "  3. Bandwidth testing with iperf3"
    echo "  4. DNS query generation"
    echo ""
}

check_prerequisites() {
    info "Checking prerequisites..."
    if ! docker ps --format '{{.Names}}' | grep -q "pc1\|server_web"; then
        error "Required containers are not running"
        exit 1
    fi
    info "Prerequisites OK"
    echo ""
}

step1_http_traffic() {
    echo -e "${CYAN}═══ Step 1: HTTP Traffic Generation ═══${NC}"
    echo ""

    info "Generating HTTP requests from pc1 to server_web..."
    echo ""

    for i in {1..5}; do
        echo -n "Request $i: "
        if response=$(docker exec pc1 curl -s -o /dev/null -w "%{http_code} - %{time_total}s" http://server_web 2>/dev/null); then
            echo -e "${GREEN}$response${NC}"
        else
            echo -e "${RED}Failed${NC}"
        fi
        sleep 0.5
    done

    echo ""
    info "HTTP traffic generation complete"
    echo ""
}

step2_continuous_ping() {
    echo -e "${CYAN}═══ Step 2: Continuous Connectivity Test ═══${NC}"
    echo ""

    info "Running continuous ping test for 10 seconds..."
    info "This verifies network stability"
    echo ""

    docker exec pc1 timeout 10 ping -i 0.2 192.168.60.5 | head -20

    echo ""
    info "Connectivity test complete"
    echo ""
}

step3_bandwidth_test() {
    echo -e "${CYAN}═══ Step 3: Bandwidth Testing with iperf3 ═══${NC}"
    echo ""

    info "Starting iperf3 server on server_web (port 5201)..."
    docker exec -d server_web iperf3 -s -1 > /dev/null 2>&1

    sleep 2

    read -p "Press Enter to run bandwidth test..."
    echo ""

    info "Running iperf3 client from pc1 to server_web..."
    echo ""

    if docker exec pc1 iperf3 -c 192.168.60.5 -t 5 2>/dev/null; then
        echo ""
        info "Bandwidth test complete"
    else
        warn "iperf3 test failed - server may not be running"
    fi

    echo ""
}

step4_dns_queries() {
    echo -e "${CYAN}═══ Step 4: DNS Query Generation ═══${NC}"
    echo ""

    info "Generating DNS queries from pc1..."
    echo ""

    hosts=("pc2" "pc3" "pc4" "pc5" "router1" "router2" "router3" "server_web" "dnsmasq")

    for host in "${hosts[@]}"; do
        echo -n "Resolving $host: "
        if resolved=$(docker exec pc1 nslookup "$host" 2>/dev/null | grep -A1 "Name:" | grep "Address" | awk '{print $2}' | head -1); then
            echo -e "${GREEN}$resolved${NC}"
        else
            echo -e "${RED}Failed${NC}"
        fi
        sleep 0.2
    done

    echo ""
    info "DNS query generation complete"
    echo ""
}

step5_mixed_traffic() {
    echo -e "${CYAN}═══ Step 5: Mixed Traffic Simulation ═══${NC}"
    echo ""

    read -p "Press Enter to generate mixed traffic for 15 seconds..."
    echo ""

    info "Generating mixed traffic (HTTP + ping + DNS) for 15 seconds..."
    echo ""

    # Start background processes
    docker exec pc1 bash -c 'for i in {1..30}; do curl -s http://server_web > /dev/null 2>&1; sleep 0.5; done' &
    PID1=$!

    docker exec pc1 ping -i 0.3 192.168.60.5 > /dev/null 2>&1 &
    PID2=$!

    # Run for 15 seconds
    for i in {1..15}; do
        echo -n "."
        sleep 1
    done
    echo ""

    # Stop background processes
    kill $PID1 $PID2 2>/dev/null || true
    wait $PID1 $PID2 2>/dev/null || true

    echo ""
    info "Mixed traffic generation complete"
    echo ""

    info "You can monitor this traffic using:"
    echo "  • docker exec router1 tcpdump -i any -n"
    echo "  • ./scripts/host/network-stats.sh"
    echo ""
}

cleanup() {
    echo -e "${CYAN}═══ Cleanup ═══${NC}"
    echo ""

    info "Stopping any remaining iperf3 servers..."
    docker exec server_web pkill iperf3 2>/dev/null || true

    info "Cleanup complete"
    echo ""
}

show_summary() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Scenario Summary${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}What you learned:${NC}"
    echo "  ✓ How to generate HTTP traffic"
    echo "  ✓ How to test connectivity continuously"
    echo "  ✓ How to measure bandwidth with iperf3"
    echo "  ✓ How to generate DNS queries"
    echo "  ✓ How to simulate mixed traffic patterns"
    echo ""
    echo -e "${YELLOW}Key tools:${NC}"
    echo "  • curl - HTTP client"
    echo "  • ping - Connectivity testing"
    echo "  • iperf3 - Bandwidth measurement"
    echo "  • nslookup - DNS queries"
    echo ""
    echo -e "${BLUE}Use cases:${NC}"
    echo "  • Load testing web servers"
    echo "  • Network performance measurement"
    echo "  • Monitoring and analytics testing"
    echo ""
}

main() {
    show_intro
    read -p "Press Enter to start..."
    echo ""

    check_prerequisites
    step1_http_traffic
    step2_continuous_ping
    step3_bandwidth_test
    step4_dns_queries
    step5_mixed_traffic
    cleanup
    show_summary
}

if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    main "$@"
fi
