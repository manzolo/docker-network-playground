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
error() { echo -e "${RED}✗ $1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Test counter
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Test wrapper
check() {
    local description=$1
    shift
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    echo -n "$description... "

    if "$@" &>/dev/null; then
        echo -e "${GREEN}OK${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Diagnostic functions
check_docker() {
    command -v docker
}

check_compose_file() {
    test -f docker-compose.yml
}

check_containers_running() {
    local expected=10
    local running=$(docker ps -q | wc -l)
    [ "$running" -eq "$expected" ]
}

check_network_exists() {
    local network=$1
    docker network inspect "$network"
}

check_container_running() {
    local container=$1
    docker ps --format '{{.Names}}' | grep -q "^${container}$"
}

check_container_healthy() {
    local container=$1
    local health=$(docker inspect "$container" --format='{{.State.Health.Status}}' 2>/dev/null || echo "none")
    [ "$health" = "healthy" ] || [ "$health" = "none" ]
}

# Main diagnostic checks
run_diagnostics() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Network Playground - Troubleshooting Wizard${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""

    # System checks
    echo -e "${BLUE}=== System Checks ===${NC}"
    check "Docker installed" check_docker
    check "In project directory" check_compose_file
    echo ""

    # Container checks
    echo -e "${BLUE}=== Container Status ===${NC}"

    local containers=("pc1" "pc2" "pc3" "pc4" "pc5" "router1" "router2" "router3" "server_web" "dnsmasq")

    for container in "${containers[@]}"; do
        if check "$container is running" check_container_running "$container"; then
            # Check health if container is running
            check "  └─ $container is healthy" check_container_healthy "$container" || true
        fi
    done
    echo ""

    # Network checks
    echo -e "${BLUE}=== Network Configuration ===${NC}"
    local networks=("lan_20" "lan_30" "lan_40" "lan_60" "transit_12" "transit_23")

    for network in "${networks[@]}"; do
        check "$network network exists" check_network_exists "$network"
    done
    echo ""

    # Connectivity checks
    echo -e "${BLUE}=== Connectivity Tests ===${NC}"

    if docker ps --format '{{.Names}}' | grep -q "pc1"; then
        check "pc1 → router1 (gateway)" docker exec pc1 ping -c 1 -W 2 192.168.20.2
        check "pc1 → pc2 (same LAN)" docker exec pc1 ping -c 1 -W 2 192.168.20.4
        check "pc1 → pc3 (cross-LAN)" docker exec pc1 ping -c 1 -W 2 192.168.30.3
        check "pc1 → server_web (multi-hop)" docker exec pc1 ping -c 1 -W 2 192.168.60.5
    else
        warn "  Skipping connectivity tests (pc1 not running)"
    fi
    echo ""

    # DNS checks
    echo -e "${BLUE}=== DNS Resolution ===${NC}"

    if docker ps --format '{{.Names}}' | grep -q "pc1"; then
        check "DNS server reachable" docker exec pc1 ping -c 1 -W 2 192.168.20.10
        check "Resolve 'server_web'" docker exec pc1 nslookup server_web
        check "Resolve 'router1'" docker exec pc1 nslookup router1
    else
        warn "  Skipping DNS tests (pc1 not running)"
    fi
    echo ""

    # Service checks
    echo -e "${BLUE}=== Service Tests ===${NC}"

    if docker ps --format '{{.Names}}' | grep -q "server_web"; then
        check "Web server HTTP response" docker exec pc1 curl -f -s http://server_web 2>/dev/null || \
              warn "  Web server not responding (pc1 might not be running)"
    else
        warn "  Skipping web server test (server_web not running)"
    fi
    echo ""

    # Routing checks
    echo -e "${BLUE}=== Routing Configuration ===${NC}"

    if docker ps --format '{{.Names}}' | grep -q "router1"; then
        check "router1 IP forwarding enabled" docker exec router1 sh -c 'sysctl net.ipv4.ip_forward | grep -q "= 1"'
    fi

    if docker ps --format '{{.Names}}' | grep -q "router2"; then
        check "router2 IP forwarding enabled" docker exec router2 sh -c 'sysctl net.ipv4.ip_forward | grep -q "= 1"'
    fi

    if docker ps --format '{{.Names}}' | grep -q "router3"; then
        check "router3 IP forwarding enabled" docker exec router3 sh -c 'sysctl net.ipv4.ip_forward | grep -q "= 1"'
    fi
    echo ""
}

# Show summary
show_summary() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Diagnostic Summary${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""

    echo "Total checks: $TOTAL_CHECKS"
    success "Passed: $PASSED_CHECKS"
    error "Failed: $FAILED_CHECKS"

    echo ""

    if [ "$FAILED_CHECKS" -eq 0 ]; then
        success "All checks passed! Network is functioning correctly."
        echo ""
        info "Next steps:"
        echo "  • Run connectivity tests: ./scripts/test-connectivity.sh"
        echo "  • Run DNS tests: ./scripts/test-dns.sh"
        echo "  • View dashboard: http://localhost/dashboard/"
    else
        error "Some checks failed. Common issues:"
        echo ""
        echo "  If containers are not running:"
        echo "    → Run: docker compose up -d"
        echo ""
        echo "  If connectivity fails:"
        echo "    → Check routing: docker exec router1 ip route"
        echo "    → Check IP forwarding: docker exec router1 sysctl net.ipv4.ip_forward"
        echo ""
        echo "  If DNS fails:"
        echo "    → Check DNS server: docker logs dnsmasq"
        echo "    → Verify DNS config in containers: docker exec pc1 cat /etc/resolv.conf"
        echo ""
        echo "  For more help:"
        echo "    → See docs/TROUBLESHOOTING.md"
        echo "    → Run: docker compose logs"
    fi

    echo ""
}

# Offer fixes
offer_fixes() {
    if [ "$FAILED_CHECKS" -gt 0 ]; then
        echo ""
        read -p "Would you like to attempt automatic fixes? (y/n): " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Attempting automatic fixes..."
            echo ""

            # Check if containers need to be started
            local running=$(docker ps -q | wc -l)
            if [ "$running" -lt 10 ]; then
                info "Starting containers..."
                docker compose up -d
                sleep 5
            fi

            # Check IP forwarding on routers
            for router in router1 router2 router3; do
                if docker ps --format '{{.Names}}' | grep -q "$router"; then
                    info "Enabling IP forwarding on $router..."
                    docker exec "$router" sysctl -w net.ipv4.ip_forward=1 > /dev/null
                fi
            done

            echo ""
            info "Fixes applied. Re-running diagnostics..."
            sleep 2
            run_diagnostics
            show_summary
        fi
    fi
}

# Main execution
main() {
    run_diagnostics
    show_summary
    offer_fixes
}

main "$@"
