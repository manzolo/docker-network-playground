#!/bin/bash
set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Helper functions
error() { echo -e "${RED}✗ ERROR: $1${NC}" >&2; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }
header() { echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"; }

# Build all Docker images
build_images() {
    header
    echo -e "${CYAN}  Building Docker Images${NC}"
    header
    echo ""

    local images=(
        "manzolo/ubuntu-network-playground-pc:images/ubuntu-network-playground-pc/Dockerfile"
        "manzolo/ubuntu-network-playground-router:images/ubuntu-network-playground-router/Dockerfile"
        "manzolo/ubuntu-network-playground-webserver:images/ubuntu-network-playground-webserver/Dockerfile"
    )

    for img in "${images[@]}"; do
        IFS=':' read -r name dockerfile <<< "$img"
        info "Building $name..."
        if docker build -t "$name:latest" -f "$dockerfile" . ; then
            success "Built $name"
        else
            error "Failed to build $name"
            exit 1
        fi
        echo ""
    done

    success "All images built successfully!"
}

# Start containers
start_containers() {
    header
    echo -e "${CYAN}  Starting Docker Network Playground${NC}"
    header
    echo ""

    info "Starting containers with Docker Compose..."
    docker compose up -d

    echo ""
    success "All containers started!"
    info "Run './menu.sh status' to check container health"
}

# Stop containers
stop_containers() {
    header
    echo -e "${CYAN}  Stopping Docker Network Playground${NC}"
    header
    echo ""

    info "Stopping containers..."
    docker compose down

    echo ""
    success "All containers stopped!"
}

# Restart containers
restart_containers() {
    header
    echo -e "${CYAN}  Restarting Docker Network Playground${NC}"
    header
    echo ""

    info "Restarting containers..."
    docker compose restart

    echo ""
    success "All containers restarted!"
}

# Clean restart (down + rm + up)
clean_restart() {
    header
    echo -e "${CYAN}  Clean Restart${NC}"
    header
    echo ""

    info "Stopping containers..."
    docker compose down

    info "Removing containers..."
    docker compose rm -f

    info "Starting fresh containers..."
    docker compose up -d

    echo ""
    success "Clean restart complete!"
}

# Show logs
show_logs() {
    local container=${1:-}

    if [ -n "$container" ]; then
        info "Showing logs for $container (Ctrl+C to exit)..."
        docker compose logs -f "$container"
    else
        info "Showing all logs (Ctrl+C to exit)..."
        docker compose logs -f
    fi
}

# Show container status
show_status() {
    header
    echo -e "${CYAN}  Container Status${NC}"
    header
    echo ""

    docker compose ps

    echo ""
    info "Health Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.State}}"
}

# Enter container
enter_container() {
    local container=$1

    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        error "Container '$container' is not running"
        exit 1
    fi

    info "Entering container: $container"
    docker exec -it "$container" /bin/bash
}

# Run connectivity tests
run_connectivity_tests() {
    header
    echo -e "${CYAN}  Running Connectivity Tests${NC}"
    header
    echo ""

    ./scripts/test-connectivity.sh
}

# Run DNS tests
run_dns_tests() {
    header
    echo -e "${CYAN}  Running DNS Tests${NC}"
    header
    echo ""

    ./scripts/test-dns.sh
}

# Run all tests
run_all_tests() {
    header
    echo -e "${CYAN}  Running All Tests${NC}"
    header
    echo ""

    info "Running connectivity tests..."
    ./scripts/test-connectivity.sh

    echo ""
    info "Running DNS tests..."
    ./scripts/test-dns.sh

    echo ""
    success "All tests complete!"
}

# Show network stats
show_network_stats() {
    ./scripts/host/network-stats.sh
}

# Generate monitoring data
generate_monitoring_data() {
    info "Generating monitoring data..."
    ./scripts/host/generate-stats.sh
    success "Monitoring data generated!"
    info "View dashboard at: http://localhost/dashboard/"
}

# Run troubleshoot
run_troubleshoot() {
    ./scripts/troubleshoot.sh
}

# Run scenario
run_scenario() {
    local scenario=$1

    if [ ! -f "scenarios/$scenario" ]; then
        error "Scenario not found: $scenario"
        echo ""
        info "Available scenarios:"
        ls -1 scenarios/*.sh | xargs -n1 basename
        exit 1
    fi

    "./scenarios/$scenario"
}

# Show help
show_help() {
    cat << EOF
${CYAN}═══════════════════════════════════════════════════════${NC}
${CYAN}  Docker Network Playground - Menu${NC}
${CYAN}═══════════════════════════════════════════════════════${NC}

${YELLOW}Usage:${NC}
  ./menu.sh [command] [options]

${YELLOW}Commands:${NC}

  ${GREEN}Container Management:${NC}
    build              Build all Docker images
    start              Start all containers
    stop               Stop all containers
    restart            Restart all containers
    clean              Clean restart (down + rm + up)
    status             Show container status
    logs [container]   Show logs (optional: specific container)

  ${GREEN}Testing:${NC}
    test-connectivity  Run connectivity tests
    test-dns           Run DNS resolution tests
    test-all           Run all tests
    troubleshoot       Run diagnostic wizard

  ${GREEN}Monitoring:${NC}
    stats              Show network statistics
    monitor            Generate monitoring data for dashboard
    dashboard          Open dashboard URL

  ${GREEN}Scenarios:${NC}
    scenario <name>    Run a scenario (e.g., 01-basic-firewall.sh)
    list-scenarios     List available scenarios

  ${GREEN}Container Access:${NC}
    enter <name>       Enter a container (pc1, router1, etc.)

  ${GREEN}Help:${NC}
    help               Show this help message
    (no arguments)     Start interactive menu

${YELLOW}Examples:${NC}
  ./menu.sh build
  ./menu.sh start
  ./menu.sh test-all
  ./menu.sh enter pc1
  ./menu.sh scenario 01-basic-firewall.sh
  ./menu.sh logs router1

${YELLOW}Container Names:${NC}
  pc1, pc2, pc3, pc4, pc5
  router1, router2, router3
  server_web, dns

EOF
}

# Interactive main menu
interactive_menu() {
    while true; do
        clear
        header
        echo -e "${CYAN}  Docker Network Playground - Interactive Menu${NC}"
        header
        echo ""
        echo -e "${YELLOW}Container Management:${NC}"
        echo "  b) Build Images"
        echo "  s) Start Containers"
        echo "  x) Stop Containers"
        echo "  r) Restart Containers"
        echo "  c) Clean Restart"
        echo "  v) View Status"
        echo "  l) Show Logs"
        echo ""
        echo -e "${YELLOW}Testing & Monitoring:${NC}"
        echo "  t) Testing Menu →"
        echo "  m) Monitoring Menu →"
        echo ""
        echo -e "${YELLOW}Scenarios & Containers:${NC}"
        echo "  n) Network Scenarios →"
        echo "  e) Enter Container →"
        echo ""
        echo "  h) Help"
        echo "  q) Quit"
        echo ""
        read -p "Choose an option: " choice

        case $choice in
            b) build_images; read -p "Press Enter to continue..." ;;
            s) start_containers; read -p "Press Enter to continue..." ;;
            x) stop_containers; read -p "Press Enter to continue..." ;;
            r) restart_containers; read -p "Press Enter to continue..." ;;
            c) clean_restart; read -p "Press Enter to continue..." ;;
            v) show_status; read -p "Press Enter to continue..." ;;
            l)
                echo ""
                read -p "Container name (Enter for all): " container
                show_logs "$container"
                ;;
            t) testing_menu ;;
            m) monitoring_menu ;;
            n) scenarios_menu ;;
            e) containers_menu ;;
            h) show_help; read -p "Press Enter to continue..." ;;
            q) echo ""; success "Goodbye!"; exit 0 ;;
            *) error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Testing submenu
testing_menu() {
    while true; do
        clear
        header
        echo -e "${CYAN}  Testing & Diagnostics${NC}"
        header
        echo ""
        echo "  1) Run Connectivity Tests"
        echo "  2) Run DNS Tests"
        echo "  3) Run All Tests"
        echo "  4) Run Troubleshoot Wizard"
        echo ""
        echo "  b) Back to Main Menu"
        echo ""
        read -p "Choose an option: " choice

        case $choice in
            1) run_connectivity_tests; read -p "Press Enter to continue..." ;;
            2) run_dns_tests; read -p "Press Enter to continue..." ;;
            3) run_all_tests; read -p "Press Enter to continue..." ;;
            4) run_troubleshoot; read -p "Press Enter to continue..." ;;
            b) return ;;
            *) error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Monitoring submenu
monitoring_menu() {
    while true; do
        clear
        header
        echo -e "${CYAN}  Monitoring & Statistics${NC}"
        header
        echo ""
        echo "  1) Show Network Stats"
        echo "  2) Generate Monitoring Data"
        echo "  3) Open Dashboard"
        echo ""
        echo "  b) Back to Main Menu"
        echo ""
        read -p "Choose an option: " choice

        case $choice in
            1) show_network_stats; read -p "Press Enter to continue..." ;;
            2) generate_monitoring_data; read -p "Press Enter to continue..." ;;
            3)
                info "Dashboard URL: http://localhost/dashboard/"
                info "Opening in browser..."
                xdg-open "http://localhost/dashboard/" 2>/dev/null || open "http://localhost/dashboard/" 2>/dev/null || echo "Please open: http://localhost/dashboard/"
                read -p "Press Enter to continue..."
                ;;
            b) return ;;
            *) error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Scenarios submenu
scenarios_menu() {
    while true; do
        clear
        header
        echo -e "${CYAN}  Network Scenarios${NC}"
        header
        echo ""
        echo "  1) Basic Firewall Configuration"
        echo "  2) NAT Gateway Setup"
        echo "  3) Network Problems Simulation"
        echo "  4) Traffic Generation"
        echo ""
        echo "  b) Back to Main Menu"
        echo ""
        read -p "Choose an option: " choice

        case $choice in
            1) run_scenario "01-basic-firewall.sh"; read -p "Press Enter to continue..." ;;
            2) warn "Scenario not yet created"; sleep 1 ;;
            3) warn "Scenario not yet created"; sleep 1 ;;
            4) run_scenario "04-traffic-generation.sh"; read -p "Press Enter to continue..." ;;
            b) return ;;
            *) error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Containers submenu
containers_menu() {
    while true; do
        clear
        header
        echo -e "${CYAN}  Enter Container${NC}"
        header
        echo ""
        echo -e "${YELLOW}PCs:${NC}"
        echo "  1) pc1    2) pc2    3) pc3    4) pc4    5) pc5"
        echo ""
        echo -e "${YELLOW}Routers:${NC}"
        echo "  r1) router1    r2) router2    r3) router3"
        echo ""
        echo -e "${YELLOW}Services:${NC}"
        echo "  w) server_web    d) dns"
        echo ""
        echo "  b) Back to Main Menu"
        echo ""
        read -p "Choose a container: " choice

        case $choice in
            1) enter_container "pc1" ;;
            2) enter_container "pc2" ;;
            3) enter_container "pc3" ;;
            4) enter_container "pc4" ;;
            5) enter_container "pc5" ;;
            r1) enter_container "router1" ;;
            r2) enter_container "router2" ;;
            r3) enter_container "router3" ;;
            w) enter_container "server_web" ;;
            d) enter_container "dns" ;;
            b) return ;;
            *) error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Main execution
main() {
    # Check if running in project directory
    if [ ! -f "docker-compose.yml" ]; then
        error "Please run this script from the project root directory"
        exit 1
    fi

    # If no arguments, start interactive menu
    if [ $# -eq 0 ]; then
        interactive_menu
        exit 0
    fi

    # Parse command line arguments
    case "${1}" in
        build)
            build_images
            ;;
        start)
            start_containers
            ;;
        stop)
            stop_containers
            ;;
        restart)
            restart_containers
            ;;
        clean)
            clean_restart
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "${2:-}"
            ;;
        test-connectivity)
            run_connectivity_tests
            ;;
        test-dns)
            run_dns_tests
            ;;
        test-all)
            run_all_tests
            ;;
        troubleshoot)
            run_troubleshoot
            ;;
        stats)
            show_network_stats
            ;;
        monitor)
            generate_monitoring_data
            ;;
        dashboard)
            info "Dashboard URL: http://localhost/dashboard/"
            ;;
        scenario)
            if [ -z "${2:-}" ]; then
                error "Please specify a scenario name"
                echo "Usage: ./menu.sh scenario <name>"
                exit 1
            fi
            run_scenario "$2"
            ;;
        list-scenarios)
            info "Available scenarios:"
            ls -1 scenarios/*.sh | xargs -n1 basename
            ;;
        enter)
            if [ -z "${2:-}" ]; then
                error "Please specify a container name"
                echo "Usage: ./menu.sh enter <container>"
                exit 1
            fi
            enter_container "$2"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
