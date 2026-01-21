# API Documentation

This document describes the interfaces, parameters, and data formats for all scripts and services in the Docker Network Playground.

## Table of Contents

- [Host Scripts](#host-scripts)
- [Container Scripts](#container-scripts)
- [Dashboard API](#dashboard-api)
- [Menu System](#menu-system)
- [Environment Variables](#environment-variables)

---

## Host Scripts

Scripts that run on the Docker host (not inside containers).

### generate-stats.sh

**Location**: `scripts/host/generate-stats.sh`

**Purpose**: Generate JSON files for the monitoring dashboard.

**Usage**:
```bash
./scripts/host/generate-stats.sh [--loop]
```

**Parameters**:
- `--loop` (optional): Run continuously with 5-second intervals

**Output**:
- `monitoring/api/status.json` - Container status information
- `monitoring/api/stats.json` - Resource usage statistics
- `monitoring/api/network.json` - Network information

**Exit Codes**:
- `0`: Success
- `1`: Docker not available or not in project root

**Example**:
```bash
# Single run
./scripts/host/generate-stats.sh

# Continuous mode
./scripts/host/generate-stats.sh --loop
```

**Output**:
```
Generating monitoring data...
  ✓ Generated monitoring/api/status.json
  ✓ Generated monitoring/api/stats.json
  ✓ Generated monitoring/api/network.json
Done! Dashboard data updated at Tue Jan 21 12:00:00 UTC 2026
```

---

### network-stats.sh

**Location**: `scripts/host/network-stats.sh`

**Purpose**: Display network statistics in terminal.

**Usage**:
```bash
./scripts/host/network-stats.sh [--loop]
```

**Parameters**:
- `--loop` (optional): Run continuously with updates

**Output**: Formatted terminal display with:
- Container status and health
- Network interface statistics
- Resource usage

**Example**:
```bash
./scripts/host/network-stats.sh
```

---

## Container Scripts

Scripts that run inside Docker containers.

### firewall-examples.sh

**Location**: `scripts/container/firewall-examples.sh`

**Purpose**: Demonstrate and apply firewall rules with auto-rollback safety.

**Usage**:
```bash
/scripts/container/firewall-examples.sh <command> [parameters]
```

**Commands**:

#### help
Display usage information.

```bash
/scripts/container/firewall-examples.sh help
```

#### block-icmp
Block ICMP traffic from a specific source.

```bash
/scripts/container/firewall-examples.sh block-icmp <source_ip>
```

**Parameters**:
- `source_ip`: IP address to block

**Example**:
```bash
docker exec router1 /scripts/container/firewall-examples.sh block-icmp 192.168.20.3
```

**Auto-rollback**: 60 seconds unless confirmed

#### rate-limit
Apply rate limiting to connections.

```bash
/scripts/container/firewall-examples.sh rate-limit <rate>
```

**Parameters**:
- `rate`: Rate limit (e.g., "5/second", "100/minute")

**Example**:
```bash
docker exec router1 /scripts/container/firewall-examples.sh rate-limit 5/second
```

#### block-port
Block a specific TCP/UDP port.

```bash
/scripts/container/firewall-examples.sh block-port <protocol> <port>
```

**Parameters**:
- `protocol`: tcp or udp
- `port`: Port number

**Example**:
```bash
docker exec router1 /scripts/container/firewall-examples.sh block-port tcp 22
```

#### reset
Remove all custom firewall rules and restore defaults.

```bash
/scripts/container/firewall-examples.sh reset
```

**Exit Codes**:
- `0`: Success
- `1`: Invalid parameters or iptables error

---

### nat-setup.sh

**Location**: `scripts/container/nat-setup.sh`

**Purpose**: Configure NAT (Network Address Translation).

**Usage**:
```bash
/scripts/container/nat-setup.sh <command> [parameters]
```

**Commands**:

#### help
Display usage information.

```bash
/scripts/container/nat-setup.sh help
```

#### snat
Configure Source NAT (masquerading).

```bash
/scripts/container/nat-setup.sh snat <interface>
```

**Parameters**:
- `interface`: Output interface (e.g., eth0, eth1)

**Example**:
```bash
docker exec router1 /scripts/container/nat-setup.sh snat eth2
```

**Effect**: All traffic leaving specified interface has source IP changed to interface IP.

#### dnat
Configure Destination NAT (port forwarding).

```bash
/scripts/container/nat-setup.sh dnat <external_port> <internal_ip> <internal_port>
```

**Parameters**:
- `external_port`: Port to listen on
- `internal_ip`: IP to forward to
- `internal_port`: Port to forward to

**Example**:
```bash
docker exec router2 /scripts/container/nat-setup.sh dnat 8080 192.168.60.5 80
```

**Effect**: Traffic to router on external_port is forwarded to internal_ip:internal_port.

#### full-nat
Configure complete NAT gateway (SNAT + DNAT + forwarding).

```bash
/scripts/container/nat-setup.sh full-nat <external_interface> <internal_network>
```

**Parameters**:
- `external_interface`: Interface facing "Internet"
- `internal_network`: Network to NAT (CIDR notation)

**Example**:
```bash
docker exec router1 /scripts/container/nat-setup.sh full-nat eth2 192.168.20.0/28
```

#### show
Display current NAT rules.

```bash
/scripts/container/nat-setup.sh show
```

#### reset
Remove all NAT rules.

```bash
/scripts/container/nat-setup.sh reset
```

---

### network-problems.sh

**Location**: `scripts/container/network-problems.sh`

**Purpose**: Simulate network problems for testing.

**Usage**:
```bash
/scripts/container/network-problems.sh <command> <interface> [parameters]
```

**Commands**:

#### latency
Add network latency.

```bash
/scripts/container/network-problems.sh latency <interface> <delay> [jitter]
```

**Parameters**:
- `interface`: Network interface (e.g., eth0)
- `delay`: Latency to add (e.g., "50ms", "100ms")
- `jitter` (optional): Variation (e.g., "10ms")

**Example**:
```bash
docker exec pc1 /scripts/container/network-problems.sh latency eth0 50ms 10ms
```

**Effect**: All traffic on interface delayed by delay ± jitter.

#### packet-loss
Simulate packet loss.

```bash
/scripts/container/network-problems.sh packet-loss <interface> <percentage>
```

**Parameters**:
- `interface`: Network interface
- `percentage`: Loss percentage (0-100)

**Example**:
```bash
docker exec router1 /scripts/container/network-problems.sh packet-loss eth0 10
```

**Effect**: 10% of packets randomly dropped.

#### bandwidth
Limit bandwidth.

```bash
/scripts/container/network-problems.sh bandwidth <interface> <rate>
```

**Parameters**:
- `interface`: Network interface
- `rate`: Maximum bandwidth (e.g., "1mbit", "100kbit")

**Example**:
```bash
docker exec pc1 /scripts/container/network-problems.sh bandwidth eth0 1mbit
```

**Effect**: Interface limited to specified bandwidth.

#### corruption
Simulate packet corruption.

```bash
/scripts/container/network-problems.sh corruption <interface> <percentage>
```

**Parameters**:
- `interface`: Network interface
- `percentage`: Corruption percentage (0-100)

**Example**:
```bash
docker exec router1 /scripts/container/network-problems.sh corruption eth0 5
```

#### unstable
Simulate unstable connection (high jitter + packet loss).

```bash
/scripts/container/network-problems.sh unstable <interface>
```

**Parameters**:
- `interface`: Network interface

**Example**:
```bash
docker exec pc1 /scripts/container/network-problems.sh unstable eth0
```

**Effect**: Combines latency (100ms), jitter (50ms), and packet loss (10%).

#### show
Display current tc (traffic control) configuration.

```bash
/scripts/container/network-problems.sh show <interface>
```

#### reset
Remove all traffic control rules.

```bash
/scripts/container/network-problems.sh reset <interface>
```

**Example**:
```bash
docker exec pc1 /scripts/container/network-problems.sh reset eth0
```

---

### generate-traffic.sh

**Location**: `scripts/container/generate-traffic.sh`

**Purpose**: Generate various types of network traffic.

**Usage**:
```bash
/scripts/container/generate-traffic.sh <type> [parameters]
```

**Types**:

#### http
Generate HTTP requests.

```bash
/scripts/container/generate-traffic.sh http <target> <count> [delay]
```

**Parameters**:
- `target`: Target hostname or IP
- `count`: Number of requests
- `delay` (optional): Delay between requests in seconds (default: 0.5)

**Example**:
```bash
docker exec pc1 /scripts/container/generate-traffic.sh http server_web 100 0.5
```

**Output**: Response times and status codes for each request.

#### ping
Generate continuous ping traffic.

```bash
/scripts/container/generate-traffic.sh ping <target> [duration]
```

**Parameters**:
- `target`: Target hostname or IP
- `duration` (optional): Duration in seconds (default: 60)

**Example**:
```bash
docker exec pc1 /scripts/container/generate-traffic.sh ping 192.168.60.5 30
```

#### dns
Generate DNS queries.

```bash
/scripts/container/generate-traffic.sh dns <target> <count> [delay]
```

**Parameters**:
- `target`: Hostname to resolve
- `count`: Number of queries
- `delay` (optional): Delay between queries (default: 0.1)

**Example**:
```bash
docker exec pc1 /scripts/container/generate-traffic.sh dns server_web 1000 0.1
```

#### mixed
Generate mixed traffic (HTTP + ICMP + DNS).

```bash
/scripts/container/generate-traffic.sh mixed [duration]
```

**Parameters**:
- `duration` (optional): Duration in seconds (default: 60)

**Example**:
```bash
docker exec pc1 /scripts/container/generate-traffic.sh mixed 120
```

---

### connectivity-check.sh

**Location**: `scripts/container/connectivity-check.sh`

**Purpose**: Check connectivity from within a container.

**Usage**:
```bash
/scripts/container/connectivity-check.sh [target]
```

**Parameters**:
- `target` (optional): Target to test (default: server_web)

**Example**:
```bash
docker exec pc1 /scripts/container/connectivity-check.sh 192.168.60.5
```

**Output**:
```
Connectivity Check
══════════════════════════════════════
Testing connectivity to 192.168.60.5

✓ Gateway reachable: 192.168.20.2
✓ DNS resolution: server_web → 192.168.60.5
✓ Ping successful: avg 0.234ms
✓ HTTP accessible: 200 OK

All tests passed!
```

**Exit Codes**:
- `0`: All tests passed
- `1`: One or more tests failed

---

## Dashboard API

The dashboard fetches data from JSON files served by the web server.

### JSON Endpoints

All endpoints are relative to: `http://localhost/dashboard/api/`

#### status.json

**Endpoint**: `GET /dashboard/api/status.json`

**Purpose**: Container status and health information.

**Update Frequency**: On-demand (run `generate-stats.sh`)

**Format**:
```json
{
  "timestamp": "2026-01-21T12:00:00Z",
  "containers": [
    {
      "name": "pc1",
      "status": "running",
      "health": "healthy",
      "started_at": "2026-01-21T10:00:00Z"
    },
    {
      "name": "pc2",
      "status": "stopped",
      "health": "n/a",
      "started_at": null
    }
  ]
}
```

**Fields**:
- `timestamp` (string): ISO 8601 timestamp of data generation
- `containers` (array): Array of container objects
  - `name` (string): Container name
  - `status` (string): "running", "stopped", "restarting", "paused"
  - `health` (string): "healthy", "unhealthy", "no_healthcheck", "n/a"
  - `started_at` (string|null): ISO 8601 timestamp of start time

---

#### stats.json

**Endpoint**: `GET /dashboard/api/stats.json`

**Purpose**: Resource usage statistics.

**Format**:
```json
{
  "timestamp": "2026-01-21T12:00:00Z",
  "stats": [
    {
      "name": "pc1",
      "cpu": "0.50%",
      "memory": "15.31MiB / 31.18GiB",
      "network": "21kB / 20kB",
      "block_io": "14.7MB / 0B"
    }
  ]
}
```

**Fields**:
- `timestamp` (string): ISO 8601 timestamp
- `stats` (array): Array of statistics objects (only running containers)
  - `name` (string): Container name
  - `cpu` (string): CPU usage percentage
  - `memory` (string): Memory usage (used / total)
  - `network` (string): Network I/O (received / sent)
  - `block_io` (string): Block I/O (read / written)

---

#### network.json

**Endpoint**: `GET /dashboard/api/network.json`

**Purpose**: Network configuration and topology.

**Format**:
```json
{
  "timestamp": "2026-01-21T12:00:00Z",
  "networks": [
    {
      "name": "lan_20",
      "subnet": "192.168.20.0/28",
      "containers": 4
    },
    {
      "name": "transit_12",
      "subnet": "192.168.100.0/29",
      "containers": 2
    }
  ]
}
```

**Fields**:
- `timestamp` (string): ISO 8601 timestamp
- `networks` (array): Array of network objects
  - `name` (string): Network name (cleaned, without project prefix)
  - `subnet` (string): Network subnet in CIDR notation
  - `containers` (number): Number of containers connected

---

#### topology.json

**Endpoint**: `GET /dashboard/api/topology.json`

**Purpose**: Static network topology definition.

**Format**:
```json
{
  "nodes": [
    {
      "id": "pc1",
      "type": "pc",
      "networks": ["lan_20"],
      "ips": ["192.168.20.3"]
    },
    {
      "id": "router1",
      "type": "router",
      "networks": ["lan_20", "lan_30", "transit_12"],
      "ips": ["192.168.20.2", "192.168.30.2", "192.168.100.2"]
    }
  ],
  "links": [
    {
      "source": "pc1",
      "target": "router1",
      "network": "lan_20"
    }
  ]
}
```

**Fields**:
- `nodes` (array): Network nodes
  - `id` (string): Unique node identifier
  - `type` (string): "pc", "router", "server", "dns"
  - `networks` (array): Networks this node connects to
  - `ips` (array): IP addresses assigned
- `links` (array): Network connections
  - `source` (string): Source node ID
  - `target` (string): Target node ID
  - `network` (string): Network name

---

### Dashboard JavaScript API

**Location**: `monitoring/dashboard.js`

#### Configuration

```javascript
const CONFIG = {
    refreshInterval: 10000,  // Auto-refresh interval (ms)
    apiPath: '/dashboard/api/',  // API base path
    endpoints: {
        status: 'status.json',
        stats: 'stats.json',
        network: 'network.json',
        topology: 'topology.json'
    }
};
```

#### Functions

##### fetchJSON(endpoint)

Fetch JSON data from API.

**Parameters**:
- `endpoint` (string): Endpoint name (e.g., "status")

**Returns**: Promise<Object> - Parsed JSON data

**Example**:
```javascript
const data = await fetchJSON('status');
console.log(data.containers);
```

##### updateContainerStatus()

Fetch and render container status table.

**Returns**: Promise<void>

##### updateResourceUsage()

Fetch and render resource usage table.

**Returns**: Promise<void>

##### updateNetworkInfo()

Fetch and render network information table.

**Returns**: Promise<void>

##### updateLastRefresh()

Update timestamp display.

**Returns**: void

##### startAutoRefresh()

Start automatic data refresh.

**Returns**: void

---

## Menu System

### menu.sh

**Location**: `./menu.sh`

**Purpose**: Interactive and CLI interface for managing the playground.

**Usage**:
```bash
./menu.sh [command] [options]
```

### Commands

#### Container Management

```bash
./menu.sh build               # Build all Docker images
./menu.sh start               # Start all containers
./menu.sh stop                # Stop all containers
./menu.sh restart             # Restart all containers
./menu.sh clean               # Clean restart (down + rm + up)
./menu.sh status              # Show container status
./menu.sh logs [container]    # Show logs
```

#### Testing

```bash
./menu.sh test-connectivity   # Run connectivity tests
./menu.sh test-dns            # Run DNS resolution tests
./menu.sh test-all            # Run all tests
./menu.sh troubleshoot        # Run diagnostic wizard
```

#### Monitoring

```bash
./menu.sh stats               # Show network statistics
./menu.sh monitor             # Generate monitoring data
./menu.sh dashboard           # View dashboard URL
```

#### Scenarios

```bash
./menu.sh scenario <name>     # Run a scenario
./menu.sh list-scenarios      # List available scenarios
```

#### Container Access

```bash
./menu.sh enter <name>        # Enter a container
```

**Example**:
```bash
./menu.sh enter pc1
# Opens bash shell in pc1 container
```

### Interactive Mode

Run without arguments for interactive menu:

```bash
./menu.sh
```

**Navigation**:
- Choose option by letter/number
- Press Enter to confirm
- Ctrl+C to exit

---

## Environment Variables

### Docker Compose Environment Variables

Defined in `docker-compose.yml`:

#### ROUTES

Comma-separated list of routes to configure.

**Format**: `<network> via <gateway>[,<network> via <gateway>...]`

**Example**:
```yaml
environment:
  ROUTES: "192.168.40.0/28 via 192.168.100.3,192.168.60.0/28 via 192.168.100.3"
```

**Applied By**: `scripts/router-setup.sh` or `scripts/pc-setup.sh`

#### DNS_SERVERS

Comma-separated list of DNS server IPs (for PCs).

**Example**:
```yaml
environment:
  DNS_SERVERS: "192.168.20.10,8.8.8.8"
```

---

## Script Exit Codes

Standard exit codes used across all scripts:

- `0`: Success
- `1`: General error (invalid parameters, command failed)
- `2`: Missing prerequisites (Docker not running, etc.)
- `3`: User cancellation
- `126`: Permission denied
- `127`: Command not found

---

## Error Handling

All scripts follow consistent error handling:

```bash
#!/bin/bash
set -euo pipefail

# e: Exit on error
# u: Error on undefined variable
# o pipefail: Pipeline fails if any command fails

error() { echo -e "${RED}✗ ERROR: $1${NC}" >&2; exit 1; }
```

**Usage**:
```bash
if ! docker ps >/dev/null 2>&1; then
    error "Docker is not running"
fi
```

---

## Contributing

When creating new scripts or APIs:

1. **Follow existing patterns**: Use the same structure and error handling
2. **Document parameters**: Clear descriptions and examples
3. **Add to this document**: Update API.md with new interfaces
4. **Include help**: All scripts should support `-h` or `help`
5. **Test thoroughly**: Verify all parameters and edge cases

---

## Version History

- **v1.0** (2026-01-21): Initial API documentation

---

For implementation details, see source code in `scripts/` directory.

For usage examples, see:
- [SCENARIOS.md](SCENARIOS.md) - Guided tutorials
- [EXERCISES.md](EXERCISES.md) - Hands-on challenges
- [README.md](../README.md) - Quick start and examples
