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

# Detect context
if [ ! -f /.dockerenv ]; then
    error "This script should be run inside a container"
    echo "Usage: docker exec <container_name> /scripts/container/generate-traffic.sh <command>"
    exit 1
fi

# Generate HTTP traffic
generate_http_traffic() {
    local target=${1:-server_web}
    local requests=${2:-10}
    local interval=${3:-1}

    info "Generating HTTP traffic to $target"
    info "  Requests: $requests"
    info "  Interval: ${interval}s"
    echo ""

    local success=0
    local failed=0

    for ((i=1; i<=$requests; i++)); do
        echo -n "Request $i/$requests: "
        if response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://$target" 2>/dev/null); then
            if [ "$response" -ge 200 ] && [ "$response" -lt 400 ]; then
                echo -e "${GREEN}HTTP $response${NC}"
                ((success++))
            else
                echo -e "${YELLOW}HTTP $response${NC}"
                ((failed++))
            fi
        else
            echo -e "${RED}FAILED${NC}"
            ((failed++))
        fi
        sleep "$interval"
    done

    echo ""
    info "Summary: $success successful, $failed failed"
}

# Generate continuous ping traffic
generate_ping_traffic() {
    local target=${1:-192.168.60.5}
    local count=${2:-20}
    local interval=${3:-0.5}

    info "Generating continuous ping traffic to $target"
    info "  Count: $count"
    info "  Interval: ${interval}s"
    echo ""

    ping -c "$count" -i "$interval" "$target"
}

# Generate DNS queries
generate_dns_traffic() {
    local queries=${1:-20}
    local interval=${2:-0.5}

    info "Generating DNS queries"
    info "  Queries: $queries"
    info "  Interval: ${interval}s"
    echo ""

    local hosts=("pc1" "pc2" "pc3" "pc4" "pc5" "router1" "router2" "router3" "server_web" "dnsmasq")
    local success=0
    local failed=0

    for ((i=1; i<=$queries; i++)); do
        local host="${hosts[$((RANDOM % ${#hosts[@]}))]}"
        echo -n "Query $i/$queries ($host): "

        if resolved=$(nslookup "$host" 2>/dev/null | grep -A1 "Name:" | grep "Address" | awk '{print $2}' | head -1); then
            echo -e "${GREEN}$resolved${NC}"
            ((success++))
        else
            echo -e "${RED}FAILED${NC}"
            ((failed++))
        fi

        sleep "$interval"
    done

    echo ""
    info "Summary: $success successful, $failed failed"
}

# Generate UDP traffic (using ping to simulate)
generate_udp_traffic() {
    local target=${1:-192.168.60.5}
    local duration=${2:-10}

    info "Generating UDP-like traffic (using ICMP) to $target for ${duration}s"
    echo ""

    timeout "$duration" ping -i 0.1 "$target" || true
    echo ""
}

# Generate mixed traffic (HTTP + ICMP + DNS)
generate_mixed_traffic() {
    local duration=${1:-30}

    info "Generating mixed traffic for ${duration}s"
    info "  HTTP requests to server_web"
    info "  Continuous ping to 192.168.60.5"
    info "  Random DNS queries"
    echo ""

    # Start background processes
    (
        while true; do
            curl -s http://server_web > /dev/null 2>&1 || true
            sleep 2
        done
    ) &
    local http_pid=$!

    (
        ping -i 0.5 192.168.60.5 > /dev/null 2>&1 || true
    ) &
    local ping_pid=$!

    (
        local hosts=("pc1" "pc2" "pc3" "router1" "server_web")
        while true; do
            local host="${hosts[$((RANDOM % ${#hosts[@]}))]}"
            nslookup "$host" > /dev/null 2>&1 || true
            sleep 1
        done
    ) &
    local dns_pid=$!

    # Show progress
    for ((i=1; i<=$duration; i++)); do
        echo -ne "\rRunning... ${i}/${duration}s"
        sleep 1
    done
    echo ""

    # Stop background processes
    kill $http_pid $ping_pid $dns_pid 2>/dev/null || true
    wait $http_pid $ping_pid $dns_pid 2>/dev/null || true

    info "Mixed traffic generation complete"
}

# Stress test - high volume traffic
stress_test() {
    local duration=${1:-10}

    warn "Running stress test for ${duration}s"
    warn "This will generate high volume traffic!"
    echo ""

    read -p "Continue? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warn "Cancelled"
        return
    fi

    info "Starting stress test..."

    # Flood ping
    (
        ping -f 192.168.60.5 > /dev/null 2>&1 || true
    ) &
    local flood_pid=$!

    # Rapid HTTP requests
    (
        while true; do
            curl -s http://server_web > /dev/null 2>&1 || true
        done
    ) &
    local http_pid=$!

    # Progress
    for ((i=1; i<=$duration; i++)); do
        echo -ne "\rStress testing... ${i}/${duration}s"
        sleep 1
    done
    echo ""

    # Cleanup
    kill $flood_pid $http_pid 2>/dev/null || true
    wait $flood_pid $http_pid 2>/dev/null || true

    info "Stress test complete"
}

# Show help
show_help() {
    cat << EOF
${CYAN}=== Traffic Generation Script ===${NC}

Usage: $0 <command> [arguments]

Commands:
  http [target] [requests] [interval]     - Generate HTTP traffic
  ping [target] [count] [interval]        - Generate ping traffic
  dns [queries] [interval]                - Generate DNS queries
  udp [target] [duration]                 - Generate UDP-like traffic
  mixed [duration]                        - Generate mixed traffic
  stress [duration]                       - High volume stress test

Examples:
  # Generate 20 HTTP requests to server_web (1s interval)
  $0 http server_web 20 1

  # Generate 50 pings to 192.168.60.5 (0.5s interval)
  $0 ping 192.168.60.5 50 0.5

  # Generate 30 DNS queries (0.3s interval)
  $0 dns 30 0.3

  # Generate mixed traffic for 60 seconds
  $0 mixed 60

  # Stress test for 15 seconds
  $0 stress 15

${YELLOW}Notes:${NC}
  - Run this script inside a container (PC or router)
  - Useful for testing network monitoring, load testing
  - Stress test generates high CPU and network usage

${BLUE}Use cases:${NC}
  - Testing monitoring systems
  - Load testing web server
  - Demonstrating network traffic
  - Educational purposes

EOF
}

# Main execution
main() {
    case "${1:-help}" in
        http)
            generate_http_traffic "${2:-server_web}" "${3:-10}" "${4:-1}"
            ;;
        ping)
            generate_ping_traffic "${2:-192.168.60.5}" "${3:-20}" "${4:-0.5}"
            ;;
        dns)
            generate_dns_traffic "${2:-20}" "${3:-0.5}"
            ;;
        udp)
            generate_udp_traffic "${2:-192.168.60.5}" "${3:-10}"
            ;;
        mixed)
            generate_mixed_traffic "${2:-30}"
            ;;
        stress)
            stress_test "${2:-10}"
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
