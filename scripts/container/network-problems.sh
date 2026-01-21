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
    error "This script must be run inside a container"
    echo "Usage: docker exec <container_name> /scripts/container/network-problems.sh <command>"
    exit 1
fi

# Show current tc settings
show_tc() {
    echo -e "${CYAN}=== Current Traffic Control Settings ===${NC}"
    echo ""

    # Get all network interfaces
    interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo")

    for iface in $interfaces; do
        echo -e "${BLUE}Interface: $iface${NC}"
        tc qdisc show dev "$iface"
        echo ""
    done
}

# Add latency to interface
add_latency() {
    local interface=$1
    local delay=$2
    local variation=${3:-0ms}

    info "Adding latency to interface $interface"
    info "  Delay: $delay"
    info "  Variation: $variation"

    # Remove existing qdisc if present
    tc qdisc del dev "$interface" root 2>/dev/null || true

    # Add latency with optional variation (jitter)
    if [ "$variation" != "0ms" ]; then
        tc qdisc add dev "$interface" root netem delay "$delay" "$variation"
        info "Latency with jitter applied: $delay ± $variation"
    else
        tc qdisc add dev "$interface" root netem delay "$delay"
        info "Latency applied: $delay"
    fi

    echo ""
    show_tc
}

# Add packet loss to interface
add_packet_loss() {
    local interface=$1
    local loss_percent=$2

    info "Adding packet loss to interface $interface"
    info "  Loss rate: $loss_percent%"

    # Remove existing qdisc if present
    tc qdisc del dev "$interface" root 2>/dev/null || true

    # Add packet loss
    tc qdisc add dev "$interface" root netem loss "$loss_percent%"

    info "Packet loss applied: $loss_percent%"
    echo ""
    show_tc
}

# Add bandwidth limit to interface
add_bandwidth_limit() {
    local interface=$1
    local rate=$2

    info "Adding bandwidth limit to interface $interface"
    info "  Rate: $rate"

    # Remove existing qdisc if present
    tc qdisc del dev "$interface" root 2>/dev/null || true

    # Add rate limiting using tbf (token bucket filter)
    tc qdisc add dev "$interface" root tbf rate "$rate" burst 32kbit latency 400ms

    info "Bandwidth limit applied: $rate"
    echo ""
    show_tc
}

# Add packet corruption to interface
add_corruption() {
    local interface=$1
    local corrupt_percent=$2

    info "Adding packet corruption to interface $interface"
    info "  Corruption rate: $corrupt_percent%"

    # Remove existing qdisc if present
    tc qdisc del dev "$interface" root 2>/dev/null || true

    # Add packet corruption
    tc qdisc add dev "$interface" root netem corrupt "$corrupt_percent%"

    info "Packet corruption applied: $corrupt_percent%"
    echo ""
    show_tc
}

# Add packet duplication to interface
add_duplication() {
    local interface=$1
    local duplicate_percent=$2

    info "Adding packet duplication to interface $interface"
    info "  Duplication rate: $duplicate_percent%"

    # Remove existing qdisc if present
    tc qdisc del dev "$interface" root 2>/dev/null || true

    # Add packet duplication
    tc qdisc add dev "$interface" root netem duplicate "$duplicate_percent%"

    info "Packet duplication applied: $duplicate_percent%"
    echo ""
    show_tc
}

# Simulate slow network (latency + packet loss + bandwidth limit)
simulate_slow_network() {
    local interface=$1
    local delay=${2:-100ms}
    local loss=${3:-5}
    local rate=${4:-1mbit}

    info "Simulating slow network on interface $interface"
    info "  Delay: $delay"
    info "  Packet loss: $loss%"
    info "  Bandwidth: $rate"

    # Remove existing qdisc if present
    tc qdisc del dev "$interface" root 2>/dev/null || true

    # Add combined effects: rate limit + netem (delay + loss)
    tc qdisc add dev "$interface" root handle 1: tbf rate "$rate" burst 32kbit latency 400ms
    tc qdisc add dev "$interface" parent 1:1 handle 10: netem delay "$delay" loss "$loss%"

    info "Slow network simulation applied"
    echo ""
    show_tc
}

# Simulate unstable network (high jitter + variable loss)
simulate_unstable_network() {
    local interface=$1

    info "Simulating unstable network on interface $interface"
    info "  High latency: 50ms ± 25ms (high jitter)"
    info "  Variable packet loss: 10%"

    # Remove existing qdisc if present
    tc qdisc del dev "$interface" root 2>/dev/null || true

    # Add high jitter and packet loss
    tc qdisc add dev "$interface" root netem delay 50ms 25ms loss 10%

    info "Unstable network simulation applied"
    echo ""
    show_tc
}

# Reset interface to normal (remove all tc rules)
reset_interface() {
    local interface=$1

    info "Resetting interface $interface to normal (removing all tc rules)"

    # Remove qdisc
    tc qdisc del dev "$interface" root 2>/dev/null || true

    info "Interface $interface reset to normal"
    echo ""
    show_tc
}

# Reset all interfaces
reset_all() {
    warn "Resetting all interfaces to normal..."

    # Get all network interfaces except lo
    interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo")

    for iface in $interfaces; do
        tc qdisc del dev "$iface" root 2>/dev/null || true
        info "Reset: $iface"
    done

    info "All interfaces reset to normal"
    echo ""
}

# Show help
show_help() {
    cat << EOF
${CYAN}=== Network Problems Simulation Script ===${NC}

Usage: $0 <command> <interface> [arguments]

Commands:
  show                                          - Show current tc settings
  reset <interface>                             - Reset specific interface to normal
  reset-all                                     - Reset all interfaces to normal

  latency <iface> <delay> [variation]           - Add latency (e.g., 100ms, 50ms 10ms)
  packet-loss <iface> <percent>                 - Add packet loss (e.g., 10)
  bandwidth <iface> <rate>                      - Limit bandwidth (e.g., 1mbit, 100kbit)
  corruption <iface> <percent>                  - Add packet corruption (e.g., 5)
  duplication <iface> <percent>                 - Add packet duplication (e.g., 2)

  slow-network <iface> [delay] [loss] [rate]    - Simulate slow network
  unstable-network <iface>                      - Simulate unstable network

Examples:
  # Show current settings
  $0 show

  # Add 100ms latency to eth0
  $0 latency eth0 100ms

  # Add 100ms latency with 10ms jitter to eth0
  $0 latency eth0 100ms 10ms

  # Add 10% packet loss to eth1
  $0 packet-loss eth1 10

  # Limit bandwidth to 1mbit on eth0
  $0 bandwidth eth0 1mbit

  # Simulate slow network (100ms delay, 5% loss, 1mbit bandwidth)
  $0 slow-network eth0 100ms 5 1mbit

  # Simulate unstable network (high jitter and packet loss)
  $0 unstable-network eth0

  # Reset eth0 to normal
  $0 reset eth0

  # Reset all interfaces
  $0 reset-all

${YELLOW}Prerequisites:${NC}
  - tc (traffic control) command must be available
  - iproute2 package installed (already included in router images)
  - Run inside container (router or PC)

${YELLOW}Notes:${NC}
  - Changes do not persist across container restarts
  - To see interface names, use: ip link show
  - Common interfaces: eth0, eth1, eth2
  - Use 'show' to verify rules are applied correctly
  - Use 'reset-all' to remove all simulations

${CYAN}Common Use Cases:${NC}
  - Test application behavior under high latency
  - Simulate unreliable network connections
  - Test packet loss recovery mechanisms
  - Benchmark application under bandwidth constraints
  - Educational demonstrations of network issues

${RED}WARNING:${NC}
  - These settings affect ALL traffic on the interface
  - Excessive packet loss or latency can break connectivity
  - Always use 'reset' or 'reset-all' when finished testing

EOF
}

# Get default interface
get_default_interface() {
    ip route | grep default | awk '{print $5}' | head -1
}

# Main execution
main() {
    # Check for tc command
    if ! command -v tc &> /dev/null; then
        error "tc (traffic control) is not available in this container"
        error "Please ensure iproute2 package is installed"
        exit 1
    fi

    # Parse command
    case "${1:-help}" in
        show)
            show_tc
            ;;
        reset)
            if [ -z "${2:-}" ]; then
                error "Missing interface name"
                echo "Usage: $0 reset <interface>"
                exit 1
            fi
            reset_interface "$2"
            ;;
        reset-all)
            reset_all
            ;;
        latency)
            if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
                error "Missing arguments"
                echo "Usage: $0 latency <interface> <delay> [variation]"
                exit 1
            fi
            add_latency "$2" "$3" "${4:-0ms}"
            ;;
        packet-loss)
            if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
                error "Missing arguments"
                echo "Usage: $0 packet-loss <interface> <percent>"
                exit 1
            fi
            add_packet_loss "$2" "$3"
            ;;
        bandwidth)
            if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
                error "Missing arguments"
                echo "Usage: $0 bandwidth <interface> <rate>"
                exit 1
            fi
            add_bandwidth_limit "$2" "$3"
            ;;
        corruption)
            if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
                error "Missing arguments"
                echo "Usage: $0 corruption <interface> <percent>"
                exit 1
            fi
            add_corruption "$2" "$3"
            ;;
        duplication)
            if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
                error "Missing arguments"
                echo "Usage: $0 duplication <interface> <percent>"
                exit 1
            fi
            add_duplication "$2" "$3"
            ;;
        slow-network)
            if [ -z "${2:-}" ]; then
                error "Missing interface name"
                echo "Usage: $0 slow-network <interface> [delay] [loss] [rate]"
                exit 1
            fi
            simulate_slow_network "$2" "${3:-100ms}" "${4:-5}" "${5:-1mbit}"
            ;;
        unstable-network)
            if [ -z "${2:-}" ]; then
                error "Missing interface name"
                echo "Usage: $0 unstable-network <interface>"
                exit 1
            fi
            simulate_unstable_network "$2"
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
