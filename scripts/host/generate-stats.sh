#!/bin/bash
set -euo pipefail

# This script generates JSON files for the monitoring dashboard
# It should be run on the host (not inside containers)

# Output directory for JSON files
OUTPUT_DIR="monitoring/api"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Generate container status JSON
generate_status_json() {
    local containers=("pc1" "pc2" "pc3" "pc4" "pc5" "router1" "router2" "router3" "server_web" "dnsmasq")
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    echo "{"
    echo "  \"timestamp\": \"$timestamp\","
    echo "  \"containers\": ["

    local first=true
    for container in "${containers[@]}"; do
        if [ "$first" = false ]; then
            echo ","
        fi
        first=false

        # Check if container is running
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            local status="running"

            # Get health status
            local health=$(docker inspect "$container" --format='{{.State.Health.Status}}' 2>/dev/null || echo "none")
            if [ "$health" = "" ] || [ "$health" = "none" ]; then
                health="no_healthcheck"
            fi

            # Get uptime
            local started=$(docker inspect "$container" --format='{{.State.StartedAt}}' 2>/dev/null || echo "unknown")

            echo -n "    {"
            echo -n "\"name\": \"$container\", "
            echo -n "\"status\": \"$status\", "
            echo -n "\"health\": \"$health\", "
            echo -n "\"started_at\": \"$started\""
            echo -n "}"
        else
            echo -n "    {"
            echo -n "\"name\": \"$container\", "
            echo -n "\"status\": \"stopped\", "
            echo -n "\"health\": \"n/a\", "
            echo -n "\"started_at\": null"
            echo -n "}"
        fi
    done

    echo ""
    echo "  ]"
    echo "}"
}

# Generate resource stats JSON
generate_stats_json() {
    local containers=("pc1" "pc2" "pc3" "pc4" "pc5" "router1" "router2" "router3" "server_web" "dnsmasq")
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    echo "{"
    echo "  \"timestamp\": \"$timestamp\","
    echo "  \"stats\": ["

    local first=true
    for container in "${containers[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            if [ "$first" = false ]; then
                echo ","
            fi
            first=false

            # Get stats
            local stats=$(docker stats "$container" --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}|{{.NetIO}}|{{.BlockIO}}" 2>/dev/null || echo "0%|0B / 0B|0B / 0B|0B / 0B")

            IFS='|' read -r cpu mem net block <<< "$stats"

            echo -n "    {"
            echo -n "\"name\": \"$container\", "
            echo -n "\"cpu\": \"$cpu\", "
            echo -n "\"memory\": \"$mem\", "
            echo -n "\"network\": \"$net\", "
            echo -n "\"block_io\": \"$block\""
            echo -n "}"
        fi
    done

    echo ""
    echo "  ]"
    echo "}"
}

# Generate network info JSON
generate_network_json() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    echo "{"
    echo "  \"timestamp\": \"$timestamp\","
    echo "  \"networks\": ["

    # Get actual network names from docker
    local networks=$(docker network ls --format "{{.Name}}" | grep -E "(lan_|transit_)" | grep -v "bridge\|host\|none")

    local first=true
    for network in $networks; do
        if [ "$first" = false ]; then
            echo ","
        fi
        first=false

        local subnet=$(docker network inspect "$network" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || echo "N/A")
        local container_count=$(docker network inspect "$network" --format '{{range $k, $v := .Containers}}{{$k}} {{end}}' 2>/dev/null | wc -w)

        # Clean network name (remove project prefix)
        local clean_name=$(echo "$network" | sed 's/.*_\(lan_[0-9]*\|transit_[0-9]*\)/\1/')

        echo -n "    {"
        echo -n "\"name\": \"$clean_name\", "
        echo -n "\"subnet\": \"$subnet\", "
        echo -n "\"containers\": $container_count"
        echo -n "}"
    done

    echo ""
    echo "  ]"
    echo "}"
}

# Main execution
main() {
    # Check if docker is available
    if ! command -v docker &> /dev/null; then
        echo "ERROR: Docker is not installed or not in PATH" >&2
        exit 1
    fi

    # Check if we're in the project root
    if [ ! -f "docker-compose.yml" ]; then
        echo "ERROR: Not in project root directory" >&2
        exit 1
    fi

    # Generate JSON files
    echo "Generating monitoring data..."

    generate_status_json > "$OUTPUT_DIR/status.json"
    echo "  ✓ Generated $OUTPUT_DIR/status.json"

    generate_stats_json > "$OUTPUT_DIR/stats.json"
    echo "  ✓ Generated $OUTPUT_DIR/stats.json"

    generate_network_json > "$OUTPUT_DIR/network.json"
    echo "  ✓ Generated $OUTPUT_DIR/network.json"

    echo "Done! Dashboard data updated at $(date)"
}

# Support for continuous mode
if [ "${1:-}" = "--loop" ]; then
    echo "Running in continuous mode (Ctrl+C to stop)"
    while true; do
        main
        sleep 5
    done
else
    main "$@"
fi
