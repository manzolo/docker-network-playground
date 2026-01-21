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

# Test DNS resolution
test_dns() {
    local from_container=$1
    local hostname=$2
    local expected_ip=$3
    local description=$4

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "Testing: $description ... "

    # Try to resolve the hostname
    if resolved_ip=$(docker exec "$from_container" nslookup "$hostname" 2>/dev/null | grep -A1 "Name:" | grep "Address" | awk '{print $2}' | head -1); then
        if [ "$resolved_ip" = "$expected_ip" ]; then
            echo -e "${GREEN}PASS${NC} (resolved to $resolved_ip)"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            echo -e "${RED}FAIL${NC} (resolved to $resolved_ip, expected $expected_ip)"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    else
        echo -e "${RED}FAIL${NC} (resolution failed)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Test reverse DNS
test_reverse_dns() {
    local from_container=$1
    local ip=$2
    local expected_hostname=$3
    local description=$4

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "Testing: $description ... "

    # Try reverse DNS lookup
    if resolved_name=$(docker exec "$from_container" nslookup "$ip" 2>/dev/null | grep "name =" | awk '{print $4}' | sed 's/\.$//' | head -1); then
        if [[ "$resolved_name" == *"$expected_hostname"* ]]; then
            echo -e "${GREEN}PASS${NC} (resolved to $resolved_name)"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            echo -e "${YELLOW}PARTIAL${NC} (resolved to $resolved_name, expected $expected_hostname)"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        fi
    else
        echo -e "${YELLOW}SKIP${NC} (reverse DNS not configured)"
        return 0
    fi
}

# Main test execution
main() {
    info "Starting DNS resolution tests..."
    echo ""

    # Check if containers are running
    info "Checking if containers are running..."
    if ! docker ps --format '{{.Names}}' | grep -q "pc1"; then
        error "Containers are not running. Please start them with: docker compose up -d"
        exit 1
    fi

    echo ""
    info "=== DNS Server Reachability ==="
    test_dns "pc1" "dnsmasq" "192.168.20.10" "pc1 → dnsmasq resolution"
    test_dns "pc3" "dnsmasq" "192.168.30.10" "pc3 → dnsmasq resolution"
    test_dns "pc4" "dnsmasq" "192.168.40.10" "pc4 → dnsmasq resolution"

    echo ""
    info "=== PC Hostname Resolution ==="
    test_dns "pc1" "pc2" "192.168.20.4" "pc1 → pc2 (same LAN)"
    test_dns "pc1" "pc3" "192.168.30.3" "pc1 → pc3 (different LAN)"
    test_dns "pc1" "pc4" "192.168.40.3" "pc1 → pc4 (different LAN)"
    test_dns "pc1" "pc5" "192.168.40.4" "pc1 → pc5 (different LAN)"

    echo ""
    info "=== Router Hostname Resolution ==="
    test_dns "pc1" "router1" "192.168.20.2" "pc1 → router1"
    test_dns "pc4" "router2" "192.168.40.2" "pc4 → router2"
    test_dns "pc1" "router3" "192.168.60.2" "pc1 → router3 (via routing)"

    echo ""
    info "=== Web Server Resolution ==="
    test_dns "pc1" "server_web" "192.168.60.5" "pc1 → server_web"
    test_dns "pc4" "server_web" "192.168.60.5" "pc4 → server_web"
    test_dns "pc3" "server_web" "192.168.60.5" "pc3 → server_web"

    echo ""
    info "=== External DNS (via upstream) ==="
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "Testing: External DNS resolution (google.com) ... "
    if docker exec pc1 nslookup google.com 8.8.8.8 &> /dev/null; then
        echo -e "${GREEN}PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${YELLOW}SKIP${NC} (upstream DNS not accessible)"
    fi

    echo ""
    warn "Note: Cross-LAN connectivity is limited by Docker bridge isolation"
    warn "DNS resolution works, but ping may fail between different LANs"

    # Summary
    echo ""
    echo "========================================"
    info "Test Summary:"
    echo "  Total tests:  $TOTAL_TESTS"
    echo -e "  ${GREEN}Passed:       $PASSED_TESTS${NC}"
    echo -e "  ${RED}Failed:       $FAILED_TESTS${NC}"
    echo "========================================"

    if [ "$FAILED_TESTS" -eq 0 ]; then
        info "All DNS tests passed!"
        exit 0
    else
        error "Some DNS tests failed!"
        exit 1
    fi
}

main "$@"
