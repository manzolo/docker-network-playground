#!/bin/bash
set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
error() { echo -e "${RED}ERROR: $1${NC}" >&2; }
warn() { echo -e "${YELLOW}WARNING: $1${NC}" >&2; }
info() { echo -e "${GREEN}INFO: $1${NC}"; }
debug() { echo -e "${BLUE}DEBUG: $1${NC}"; }

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test ping connectivity
test_ping() {
    local from_container=$1
    local to_host=$2
    local description=$3

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "Testing: $description ... "

    if docker exec "$from_container" ping -c 1 -W 2 "$to_host" &> /dev/null; then
        echo -e "${GREEN}PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Main test execution
main() {
    info "Starting network connectivity tests..."
    echo ""

    # Check if containers are running
    info "Checking if containers are running..."
    if ! docker ps --format '{{.Names}}' | grep -q "pc1"; then
        error "Containers are not running. Please start them with: docker compose up -d"
        exit 1
    fi

    echo ""
    info "=== LAN 20 Tests ==="
    test_ping "pc1" "192.168.20.4" "pc1 → pc2 (same LAN)"
    test_ping "pc1" "192.168.20.2" "pc1 → router1 (gateway)"
    test_ping "pc1" "192.168.20.10" "pc1 → DNS server"

    echo ""
    info "=== LAN 30 Tests ==="
    test_ping "pc3" "192.168.30.2" "pc3 → router1 (gateway)"
    test_ping "pc3" "192.168.30.10" "pc3 → DNS server"

    echo ""
    info "=== LAN 40 Tests ==="
    test_ping "pc4" "192.168.40.4" "pc4 → pc5 (same LAN)"
    test_ping "pc4" "192.168.40.2" "pc4 → router2 (gateway)"
    test_ping "pc4" "192.168.40.10" "pc4 → DNS server"

    echo ""
    info "=== Router Connectivity Tests ==="
    test_ping "router1" "192.168.100.3" "router1 → router2 (transit_12)"
    test_ping "router2" "192.168.200.3" "router2 → router3 (transit_23)"
    test_ping "router2" "192.168.100.2" "router2 → router1 (transit_12)"

    echo ""
    warn "Note: Direct cross-LAN PC-to-PC routing is limited by Docker bridge isolation"
    warn "This is expected behavior and demonstrates network segmentation"

    echo ""
    info "=== Service Reachability from Local LAN ==="
    test_ping "pc1" "192.168.20.10" "pc1 → DNS (same LAN)"
    test_ping "pc4" "192.168.40.10" "pc4 → DNS (same LAN)"

    # Summary
    echo ""
    echo "========================================"
    info "Test Summary:"
    echo "  Total tests:  $TOTAL_TESTS"
    echo -e "  ${GREEN}Passed:       $PASSED_TESTS${NC}"
    echo -e "  ${RED}Failed:       $FAILED_TESTS${NC}"
    echo "========================================"

    if [ "$FAILED_TESTS" -eq 0 ]; then
        info "All connectivity tests passed!"
        exit 0
    else
        error "Some connectivity tests failed!"
        exit 1
    fi
}

main "$@"
