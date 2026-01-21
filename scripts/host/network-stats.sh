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

# Get container stats
get_container_stats() {
    local container=$1

    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "NOT_RUNNING"
        return
    fi

    # Get basic stats (CPU, Memory, Network I/O)
    docker stats "$container" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | tail -n 1
}

# Get container health status
get_health_status() {
    local container=$1

    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "NOT_RUNNING"
        return
    fi

    # Get health status
    health=$(docker inspect "$container" --format='{{.State.Health.Status}}' 2>/dev/null || echo "none")

    if [ "$health" = "none" ]; then
        # If no health check, check if running
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            echo "running"
        else
            echo "stopped"
        fi
    else
        echo "$health"
    fi
}

# Display stats for all containers
display_all_stats() {
    info "Network Playground - Container Statistics"
    echo ""

    # Container list
    containers=("pc1" "pc2" "pc3" "pc4" "pc5" "router1" "router2" "router3" "server_web" "dnsmasq")

    echo -e "${CYAN}=== Container Health Status ===${NC}"
    echo ""
    printf "%-15s %-15s\n" "Container" "Health Status"
    echo "----------------------------------------"

    for container in "${containers[@]}"; do
        health=$(get_health_status "$container")

        case "$health" in
            "healthy")
                status_color="${GREEN}"
                status_symbol="✓"
                ;;
            "unhealthy")
                status_color="${RED}"
                status_symbol="✗"
                ;;
            "running")
                status_color="${BLUE}"
                status_symbol="●"
                ;;
            "NOT_RUNNING")
                status_color="${RED}"
                status_symbol="○"
                health="stopped"
                ;;
            *)
                status_color="${YELLOW}"
                status_symbol="?"
                ;;
        esac

        printf "%-15s ${status_color}%-15s${NC} %s\n" "$container" "$health" "$status_symbol"
    done

    echo ""
    echo -e "${CYAN}=== Container Resource Usage ===${NC}"
    echo ""

    # Check if any container is running
    if ! docker ps -q | head -1 > /dev/null 2>&1; then
        warn "No containers are currently running"
        return
    fi

    # Display stats header
    printf "%-15s %-10s %-25s %-20s\n" "Container" "CPU %" "Memory" "Network I/O"
    echo "--------------------------------------------------------------------------------"

    for container in "${containers[@]}"; do
        stats=$(get_container_stats "$container")
        if [ "$stats" != "NOT_RUNNING" ]; then
            echo "$stats"
        else
            printf "%-15s ${RED}%-10s${NC}\n" "$container" "STOPPED"
        fi
    done

    echo ""
}

# Display network information
display_network_info() {
    echo -e "${CYAN}=== Network Information ===${NC}"
    echo ""

    # Get network list
    networks=("lan_20" "lan_30" "lan_40" "lan_60" "transit_12" "transit_23")

    printf "%-15s %-20s %-10s\n" "Network" "Subnet" "Containers"
    echo "--------------------------------------------------------"

    for network in "${networks[@]}"; do
        if docker network inspect "$network" &>/dev/null; then
            subnet=$(docker network inspect "$network" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || echo "N/A")
            container_count=$(docker network inspect "$network" --format '{{range $k, $v := .Containers}}{{$k}} {{end}}' 2>/dev/null | wc -w)
            printf "%-15s %-20s %-10s\n" "$network" "$subnet" "$container_count"
        fi
    done

    echo ""
}

# Display connectivity matrix
display_connectivity_matrix() {
    echo -e "${CYAN}=== Quick Connectivity Check ===${NC}"
    echo ""

    info "Running quick ping tests..."

    # Test key paths
    tests=(
        "pc1:192.168.20.4:pc2 (same LAN)"
        "pc1:192.168.40.3:pc4 (cross-LAN)"
        "pc1:192.168.60.5:web (multi-hop)"
    )

    for test in "${tests[@]}"; do
        IFS=':' read -r from_container to_ip description <<< "$test"

        if docker ps --format '{{.Names}}' | grep -q "^${from_container}$"; then
            echo -n "  $from_container → $description: "
            if docker exec "$from_container" ping -c 1 -W 1 "$to_ip" &>/dev/null; then
                echo -e "${GREEN}✓ OK${NC}"
            else
                echo -e "${RED}✗ FAIL${NC}"
            fi
        fi
    done

    echo ""
}

# Main function
main() {
    # Check if docker is available
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
        exit 1
    fi

    # Check if running from correct location
    if [ ! -f "docker-compose.yml" ]; then
        warn "Not in project root directory. Results may be incomplete."
    fi

    clear
    display_all_stats
    display_network_info
    display_connectivity_matrix

    info "Statistics refreshed at: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "Tip: Run this script again to refresh stats"
    echo "     Or use: watch -n 5 ./scripts/host/network-stats.sh"
}

# Run if called with --loop flag for continuous monitoring
if [ "${1:-}" = "--loop" ]; then
    while true; do
        main
        sleep 5
    done
else
    main "$@"
fi
