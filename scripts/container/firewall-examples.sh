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
    echo "Usage: docker exec <container_name> /scripts/container/firewall-examples.sh <command>"
    exit 1
fi

# Backup file for iptables rules
BACKUP_FILE="/tmp/iptables-backup-$(date +%s).rules"
ROLLBACK_TIMEOUT=60

# Backup current iptables rules
backup_iptables() {
    info "Backing up current iptables rules to $BACKUP_FILE..."
    iptables-save > "$BACKUP_FILE"
    info "Backup complete"
}

# Restore iptables rules from backup
restore_iptables() {
    if [ -f "$BACKUP_FILE" ]; then
        info "Restoring iptables rules from backup..."
        iptables-restore < "$BACKUP_FILE"
        info "Rules restored"
        rm -f "$BACKUP_FILE"
    else
        warn "No backup file found"
    fi
}

# Auto-rollback function with timeout
apply_with_rollback() {
    local description=$1

    backup_iptables

    warn "═══════════════════════════════════════════════════════"
    warn "AUTO-ROLLBACK SAFETY FEATURE ACTIVATED"
    warn "═══════════════════════════════════════════════════════"
    echo ""
    warn "The firewall rules will be automatically ROLLED BACK"
    warn "in $ROLLBACK_TIMEOUT seconds unless you confirm them."
    echo ""
    warn "To confirm and keep the rules, press 'y' within $ROLLBACK_TIMEOUT seconds"
    warn "To rollback immediately, press 'n' or wait for timeout"
    echo ""

    # Start countdown
    local confirmed=false

    # Read with timeout
    if read -t "$ROLLBACK_TIMEOUT" -n 1 -p "Keep the new rules? (y/n): " response; then
        echo ""
        if [[ "$response" =~ ^[Yy]$ ]]; then
            confirmed=true
            info "Rules confirmed and saved!"
            rm -f "$BACKUP_FILE"
        fi
    else
        echo ""
        warn "Timeout reached!"
    fi

    if [ "$confirmed" = false ]; then
        error "Rolling back to previous rules..."
        restore_iptables
        error "Rollback complete. No changes were made permanent."
        exit 1
    fi
}

# Show current rules
show_rules() {
    echo -e "${CYAN}=== Current iptables Rules ===${NC}"
    echo ""
    echo "Filter table:"
    iptables -L -n -v --line-numbers
    echo ""
    echo "NAT table:"
    iptables -t nat -L -n -v --line-numbers
}

# Block ICMP (ping) from specific source
block_icmp() {
    local source_ip=$1

    info "Blocking ICMP from $source_ip"

    iptables -A INPUT -p icmp -s "$source_ip" -j DROP

    info "Rule applied: ICMP from $source_ip will be dropped"
    show_rules

    apply_with_rollback "Block ICMP from $source_ip"
}

# Block specific port
block_port() {
    local port=$1
    local protocol=${2:-tcp}

    info "Blocking $protocol port $port"

    iptables -A INPUT -p "$protocol" --dport "$port" -j DROP

    info "Rule applied: $protocol port $port is now blocked"
    show_rules

    apply_with_rollback "Block $protocol port $port"
}

# Rate limiting (protection against ping flood)
rate_limit_icmp() {
    local rate=${1:-5/second}

    info "Applying rate limit to ICMP: $rate"

    # Allow established connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Rate limit ICMP
    iptables -A INPUT -p icmp -m limit --limit "$rate" --limit-burst 10 -j ACCEPT
    iptables -A INPUT -p icmp -j DROP

    info "Rule applied: ICMP rate limited to $rate"
    show_rules

    apply_with_rollback "Rate limit ICMP to $rate"
}

# Allow only specific IP
allow_only() {
    local allowed_ip=$1
    local port=${2:-all}

    info "Configuring firewall to allow only $allowed_ip"

    # Default policy DROP
    iptables -P INPUT DROP
    iptables -P FORWARD DROP

    # Allow loopback
    iptables -A INPUT -i lo -j ACCEPT

    # Allow established connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    if [ "$port" = "all" ]; then
        # Allow all from specific IP
        iptables -A INPUT -s "$allowed_ip" -j ACCEPT
    else
        # Allow specific port from specific IP
        iptables -A INPUT -s "$allowed_ip" -p tcp --dport "$port" -j ACCEPT
    fi

    info "Rule applied: Only $allowed_ip is allowed"
    show_rules

    apply_with_rollback "Allow only $allowed_ip"
}

# Clear all rules (reset to default)
clear_rules() {
    warn "Clearing all iptables rules and setting default policies to ACCEPT"

    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT

    info "All rules cleared, firewall is now open"
    show_rules
}

# Display help
show_help() {
    cat << EOF
${CYAN}=== Firewall Examples Script ===${NC}

Usage: $0 <command> [arguments]

Commands:
  show                          - Show current iptables rules
  clear                         - Clear all rules (reset to default)
  block-icmp <source_ip>        - Block ICMP from specific source
  block-port <port> [protocol]  - Block specific port (default: tcp)
  rate-limit [rate]             - Rate limit ICMP (default: 5/second)
  allow-only <ip> [port]        - Allow only specific IP (optionally on specific port)

Examples:
  $0 show
  $0 block-icmp 192.168.20.3
  $0 block-port 80 tcp
  $0 block-port 53 udp
  $0 rate-limit 10/second
  $0 allow-only 192.168.20.3
  $0 allow-only 192.168.20.3 80
  $0 clear

${YELLOW}Safety Features:${NC}
  - All changes automatically back up current rules
  - Auto-rollback after $ROLLBACK_TIMEOUT seconds unless confirmed
  - Use 'clear' to reset to default open policy

${RED}WARNING:${NC}
  - These rules do not persist across container restarts
  - Incorrectly blocking traffic can break connectivity
  - Always test in a safe environment first

EOF
}

# Main execution
main() {
    # Check for iptables
    if ! command -v iptables &> /dev/null; then
        error "iptables is not available in this container"
        exit 1
    fi

    # Parse command
    case "${1:-help}" in
        show)
            show_rules
            ;;
        clear)
            clear_rules
            ;;
        block-icmp)
            if [ -z "${2:-}" ]; then
                error "Missing source IP"
                echo "Usage: $0 block-icmp <source_ip>"
                exit 1
            fi
            block_icmp "$2"
            ;;
        block-port)
            if [ -z "${2:-}" ]; then
                error "Missing port number"
                echo "Usage: $0 block-port <port> [protocol]"
                exit 1
            fi
            block_port "$2" "${3:-tcp}"
            ;;
        rate-limit)
            rate_limit_icmp "${2:-5/second}"
            ;;
        allow-only)
            if [ -z "${2:-}" ]; then
                error "Missing IP address"
                echo "Usage: $0 allow-only <ip> [port]"
                exit 1
            fi
            allow_only "$2" "${3:-all}"
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
