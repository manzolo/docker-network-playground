# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker-based network simulation environment for educational purposes. It simulates a multi-router network topology with multiple LANs, transit networks, client PCs, DNS services, and a web server.

**Version**: 2.0 - Complete Educational Platform
**Last Updated**: 2026-01-21

## Quick Start

### For Users

```bash
# Build images
./menu.sh build

# Start environment
./menu.sh start

# Run all tests (should pass 27/27)
./menu.sh test-all

# Generate monitoring data
./menu.sh monitor

# Access dashboard
# Open http://localhost/dashboard/ in browser

# Enter a container
./menu.sh enter pc1
```

### For Developers

```bash
# Build specific image
docker build -t manzolo/ubuntu-network-playground-pc:latest -f images/ubuntu-network-playground-pc/Dockerfile .

# Start specific container
docker compose up -d pc1

# View logs
docker compose logs -f pc1

# Test script
docker exec pc1 /scripts/container/connectivity-check.sh
```

## Network Architecture

### Topology

The network consists of three routers interconnecting four LANs with various services:

- **3 Routers** (router1, router2, router3) - Ubuntu-based with IP forwarding enabled
- **5 Client PCs** (pc1-pc5) - Ubuntu-based with network utilities (ping, traceroute, tcpdump, curl, iperf3, dnsutils)
- **1 Web Server** (server_web) - Nginx 1.27 serving dashboard on host port 80
- **1 DNS Server** (dnsmasq) - Multi-homed across all LANs

### Network Segments

**LANs** (Subnets: /28 - 14 usable hosts):
- `lan_20`: 192.168.20.0/28 (hosts: pc1, pc2, router1, dnsmasq)
- `lan_30`: 192.168.30.0/28 (hosts: pc3, router1, dnsmasq)
- `lan_40`: 192.168.40.0/28 (hosts: pc4, pc5, router2, dnsmasq)
- `lan_60`: 192.168.60.0/28 (hosts: server_web, router3, dnsmasq)

**Transit Networks** (Subnets: /29 - 6 usable hosts):
- `transit_12`: 192.168.100.0/29 (router1 ↔ router2)
- `transit_23`: 192.168.200.0/29 (router2 ↔ router3)

### IP Addressing Scheme

| Host | IP Address(es) | Role | Network(s) |
|------|---------------|------|-----------|
| **pc1** | 192.168.20.3 | Client PC | LAN 20 |
| **pc2** | 192.168.20.4 | Client PC | LAN 20 |
| **pc3** | 192.168.30.3 | Client PC | LAN 30 |
| **pc4** | 192.168.40.3 | Client PC | LAN 40 |
| **pc5** | 192.168.40.4 | Client PC | LAN 40 |
| **router1** | 192.168.20.2, 192.168.30.2, 192.168.100.2 | Router | LAN 20, LAN 30, Transit 12 |
| **router2** | 192.168.40.2, 192.168.100.3, 192.168.200.2 | Router | LAN 40, Transit 12, Transit 23 |
| **router3** | 192.168.60.2, 192.168.200.3 | Router | LAN 60, Transit 23 |
| **server_web** | 192.168.60.5 | Nginx Web Server | LAN 60 |
| **dnsmasq** | 192.168.20.10, 192.168.30.10, 192.168.40.10, 192.168.60.10 | DNS Server (multi-homed) | All LANs |

### Routing Configuration

Routing is configured via environment variables in `docker-compose.yml` and applied by setup scripts:

- **router1**: Routes to lan_40 and lan_60 via router2 (192.168.100.3)
- **router2**: Routes to lan_20/lan_30 via router1 (192.168.100.2), lan_60 via router3 (192.168.200.3)
- **router3**: Routes to lan_20/lan_30/lan_40 via router2 (192.168.200.2)
- **PCs**: Default gateway points to their respective router

Routes are defined in the `ROUTES` environment variable as comma-separated entries:
```yaml
ROUTES: "192.168.40.0/28 via 192.168.100.3,192.168.60.0/28 via 192.168.100.3"
```

### DNS Configuration

The dnsmasq service is multi-homed (connected to all LANs) and provides:
- DNS resolution for all hosts via `/etc/dnsmasq.hosts` file
- Domain-based resolution for lan_20, lan_30, lan_40, lan_60
- Upstream DNS via Google DNS (8.8.8.8, 8.8.4.4)
- Host file mapping in `dnsmasq.hosts`

## Project Structure

```
net-playground/
├── README.md                          # Main documentation with badges, Mermaid diagrams
├── CLAUDE.md                          # This file - developer guidance
├── docker-compose.yml                 # Container orchestration with health checks
├── dnsmasq.hosts                      # DNS hostname mappings
├── menu.sh                            # Interactive and CLI menu system
├── .gitattributes                     # Git attributes for script permissions
│
├── images/                            # Docker image definitions
│   ├── ubuntu-network-playground-pc/
│   │   └── Dockerfile                 # PC image (Ubuntu + network tools)
│   ├── ubuntu-network-playground-router/
│   │   └── Dockerfile                 # Router image (Ubuntu + routing tools)
│   └── ubuntu-network-playground-webserver/
│       └── Dockerfile                 # Web server image (Nginx + tools)
│
├── scripts/                           # Setup and utility scripts
│   ├── pc-setup.sh                    # PC container initialization
│   ├── router-setup.sh                # Router container initialization
│   ├── web-setup.sh                   # Web server initialization
│   ├── test-connectivity.sh           # Network connectivity tests
│   ├── test-dns.sh                    # DNS resolution tests
│   ├── troubleshoot.sh                # Automated diagnostics wizard
│   │
│   ├── host/                          # Scripts run on Docker host
│   │   ├── generate-stats.sh          # Generate dashboard JSON data
│   │   └── network-stats.sh           # Terminal network statistics
│   │
│   └── container/                     # Scripts run inside containers
│       ├── firewall-examples.sh       # Firewall demos with auto-rollback
│       ├── nat-setup.sh               # NAT configuration helpers
│       ├── network-problems.sh        # Network simulation (latency, loss)
│       ├── generate-traffic.sh        # Traffic generation for testing
│       └── connectivity-check.sh      # Container connectivity verification
│
├── monitoring/                        # Web dashboard
│   ├── index.html                     # Dashboard HTML
│   ├── dashboard.css                  # Dashboard styling
│   ├── dashboard.js                   # Dashboard logic (vanilla JS)
│   └── api/                           # JSON data files (generated)
│       ├── status.json                # Container status
│       ├── stats.json                 # Resource usage
│       ├── network.json               # Network information
│       └── topology.json              # Network topology (static)
│
├── scenarios/                         # Pre-configured network scenarios
│   ├── README.md                      # Scenarios overview
│   ├── 01-basic-firewall.sh          # Firewall configuration tutorial
│   └── 04-traffic-generation.sh      # Traffic generation tutorial
│
├── docs/                              # Documentation
│   ├── SCENARIOS.md                   # Detailed scenario descriptions
│   ├── NETWORKING-BASICS.md           # Networking concepts explained
│   ├── TROUBLESHOOTING.md             # Problem diagnosis and fixes
│   ├── EXERCISES.md                   # Hands-on tutorials and challenges
│   └── API.md                         # Script interfaces and JSON formats
│
└── doc/                               # Assets
    └── image.png                      # Topology diagram
```

## Key Features

### 1. Safety Mechanisms

- **Auto-rollback**: Firewall rules automatically revert after 60 seconds if not confirmed
- **Backup**: Automatic iptables state backup before changes
- **Reset scripts**: Easy restoration to clean state
- **Non-destructive**: All changes contained within containers

### 2. Monitoring Dashboard

- **Location**: http://localhost/dashboard/
- **Technology**: Static HTML/CSS/JS (no frameworks)
- **Data Source**: JSON files generated by `generate-stats.sh`
- **Auto-refresh**: Every 10 seconds (configurable)
- **Sections**:
  - Container Status (health, uptime)
  - Resource Usage (CPU, memory, network I/O)
  - Network Information (subnets, container counts)

### 3. Test Automation

- **Connectivity tests**: `./menu.sh test-connectivity` (27 tests)
- **DNS tests**: `./menu.sh test-dns` (10 tests)
- **Full suite**: `./menu.sh test-all` (runs all)
- **Troubleshoot wizard**: `./menu.sh troubleshoot` (automated diagnostics)

### 4. Network Scenarios

Pre-configured tutorials demonstrating:
- Firewall configuration with iptables
- NAT (SNAT, DNAT, port forwarding)
- Traffic generation and load testing
- Network problem simulation

### 5. Interactive Menu

Dual-mode interface:
- **Interactive**: `./menu.sh` (menu-driven)
- **CLI**: `./menu.sh <command>` (automation-friendly)

Commands: build, start, stop, restart, clean, status, logs, test-*, monitor, scenario, enter

## Container Setup Scripts

All containers execute setup scripts on startup:

### router-setup.sh
- Enables IP forwarding: `sysctl -w net.ipv4.ip_forward=1`
- Applies routes from `$ROUTES` environment variable
- Configures iptables FORWARD policy for routing
- Applied to: router1, router2, router3

### pc-setup.sh
- Applies routes from `$ROUTES` environment variable (typically default gateway)
- Applied to: pc1, pc2, pc3, pc4, pc5

### web-setup.sh
- Applies routes
- Starts nginx in foreground mode
- Serves dashboard from `/usr/share/nginx/html/dashboard/`
- Applied to: server_web

Routes are parsed from comma-separated `$ROUTES` environment variable and applied using `ip route replace`.

## Image Structure

### PC Image (manzolo/ubuntu-network-playground-pc:latest)

**Base**: ubuntu:24.04

**Packages**:
- Network utilities: iproute2, iputils-ping, traceroute, tcpdump, dnsutils
- HTTP client: curl, wget
- Performance testing: iperf3
- Editors: nano

**Scripts**: Includes all scripts from `scripts/container/`

### Router Image (manzolo/ubuntu-network-playground-router:latest)

**Base**: ubuntu:24.04

**Packages**:
- All PC packages plus:
- Firewall: iptables
- Traffic control: tc (part of iproute2)

**Special**: IP forwarding enabled by default

### Web Server Image (manzolo/ubuntu-network-playground-webserver:latest)

**Base**: nginx:1.27

**Packages**:
- Network utilities: iproute2, iputils-ping, net-tools

**Volume Mount**: `./monitoring:/usr/share/nginx/html/dashboard:ro`

**Port Mapping**: 80:80

## Important Notes

### Docker Bridge Network Isolation

**Critical limitation**: Docker bridge networks are isolated by design.

This means:
- ✅ **Works**: Same-LAN communication (pc1 ↔ pc2)
- ✅ **Works**: PC to gateway router
- ✅ **Works**: Router to router (via transit networks)
- ✅ **Works**: PC to services via routing
- ⚠️ **Limited**: Direct cross-LAN PC-to-PC may not work without specific iptables rules

This is **expected behavior** and demonstrates network segmentation.

### Network Naming

Docker Compose prefixes network names with project directory name:
- Logical name: `lan_20`
- Actual name: `net-playgound_lan_20`

Scripts must handle this:
```bash
# Dynamic discovery
docker network ls --format "{{.Name}}" | grep -E "(lan_|transit_)"

# Strip prefix for display
echo "$network" | sed 's/.*_\(lan_[0-9]*\|transit_[0-9]*\)/\1/'
```

### Health Checks

All containers have health checks defined in `docker-compose.yml`:

**PCs and Routers**: `ping -c 1 127.0.0.1`
**Web Server**: `curl -f http://localhost:80/`
**DNS**: `nslookup localhost localhost`

Check health:
```bash
docker ps
./menu.sh status
```

### Permissions

Scripts must be executable. `.gitattributes` preserves this:

```
* text=auto
*.sh text eol=lf executable
```

If permissions are lost:
```bash
chmod +x scripts/*.sh
chmod +x scripts/host/*.sh
chmod +x scripts/container/*.sh
chmod +x scenarios/*.sh
chmod +x menu.sh
```

## Development Guidelines

### Adding New Scripts

1. **Choose location**:
   - Host scripts: `scripts/host/`
   - Container scripts: `scripts/container/`
   - Setup scripts: `scripts/` (root)

2. **Follow template**:
```bash
#!/bin/bash
set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Helper functions
error() { echo -e "${RED}✗ ERROR: $1${NC}" >&2; exit 1; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Main logic
main() {
    # Your code here
}

main "$@"
```

3. **Add help option**:
```bash
if [ "${1:-}" = "help" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    show_help
    exit 0
fi
```

4. **Document**: Update `docs/API.md` with interface specification

5. **Test**: Verify all parameters and edge cases

### Adding New Scenarios

1. **Create script**: `scenarios/XX-scenario-name.sh`

2. **Use template**: See `scenarios/01-basic-firewall.sh` as reference

3. **Key elements**:
   - Interactive with clear explanations
   - Step-by-step with pauses
   - Safety features (auto-rollback for destructive changes)
   - Verification steps
   - Cleanup function

4. **Document**: Add detailed section to `docs/SCENARIOS.md`

5. **Integrate**: Add to `menu.sh` scenarios menu

6. **Test**: Run multiple times to ensure reliability

### Modifying Network Topology

To add/remove networks or containers:

1. **Edit `docker-compose.yml`**:
   - Add network definitions
   - Add container definitions
   - Configure IP addresses
   - Set up routes via `ROUTES` environment variable

2. **Update `dnsmasq.hosts`**: Add hostname mappings

3. **Update documentation**:
   - README.md (topology diagram, network table)
   - This file (IP addressing scheme)
   - docs/NETWORKING-BASICS.md (if concepts change)

4. **Update test scripts**:
   - `scripts/test-connectivity.sh`
   - `scripts/test-dns.sh`

5. **Update monitoring**:
   - `scripts/host/generate-stats.sh` (container list)
   - `monitoring/api/topology.json` (if using)

6. **Rebuild and test**:
```bash
./menu.sh build
./menu.sh clean
./menu.sh test-all
```

## Testing

### Manual Testing Checklist

After making changes:

```bash
# 1. Build images
./menu.sh build

# 2. Clean start
./menu.sh clean

# 3. Check status
./menu.sh status
# All containers should be healthy

# 4. Run tests
./menu.sh test-all
# Should pass 27/27 tests

# 5. Generate monitoring data
./menu.sh monitor

# 6. Check dashboard
# Open http://localhost/dashboard/
# Verify all sections display data

# 7. Test scenarios
./menu.sh scenario 01-basic-firewall.sh

# 8. Test entering containers
./menu.sh enter pc1
# Inside: ping 192.168.60.5
# exit

# 9. Check logs for errors
./menu.sh logs | grep -i error
```

### Automated Testing

All tests in `scripts/test-connectivity.sh` and `scripts/test-dns.sh` should pass:

```bash
./menu.sh test-all

# Expected output:
# Connectivity Tests: 27/27 PASSED
# DNS Tests: 10/10 PASSED
# Overall: 37/37 PASSED
```

## Troubleshooting

### Common Issues

**Containers not starting**:
```bash
./menu.sh logs <container_name>
# Check for errors in setup scripts
```

**Dashboard not loading**:
```bash
# Check web server
docker ps | grep server_web
curl http://localhost/

# Regenerate data
./menu.sh monitor
```

**Network connectivity issues**:
```bash
# Run diagnostics
./menu.sh troubleshoot

# Check routing
docker exec pc1 ip route
docker exec router1 ip route

# Check forwarding
docker exec router1 sysctl net.ipv4.ip_forward
```

**DNS issues**:
```bash
# Check DNS container
docker ps | grep dnsmasq
docker logs dnsmasq

# Check DNS configuration
docker exec pc1 cat /etc/resolv.conf

# Test DNS
docker exec pc1 nslookup server_web
```

### Complete Reset

Nuclear option:

```bash
docker compose down
docker rm -f $(docker ps -aq)
docker network prune -f
./menu.sh build
./menu.sh start
./menu.sh test-all
```

## Documentation

### User Documentation

- **README.md**: Quick start, features, use cases, FAQ
- **docs/SCENARIOS.md**: Detailed scenario guides
- **docs/NETWORKING-BASICS.md**: Networking concepts explained
- **docs/TROUBLESHOOTING.md**: Problem diagnosis and solutions
- **docs/EXERCISES.md**: 15 hands-on exercises (beginner to advanced)

### Developer Documentation

- **This file (CLAUDE.md)**: Developer guidance
- **docs/API.md**: Script interfaces and JSON formats
- Inline comments in scripts

## Educational Value

This project is designed for:

- **Networking courses**: Practical lab for theory
- **Certification prep**: CCNA, CompTIA Network+, etc.
- **Self-learning**: Hands-on networking practice
- **DevOps training**: Container networking concepts
- **Security training**: Firewall and NAT configuration
- **Interview prep**: Demonstrate networking knowledge

### Learning Path

1. **Start**: Complete Quick Start guide
2. **Understand**: Read docs/NETWORKING-BASICS.md
3. **Practice**: Work through docs/EXERCISES.md (beginner → advanced)
4. **Explore**: Try scenarios (docs/SCENARIOS.md)
5. **Create**: Build your own scenarios and exercises

## Contributing

### Contribution Ideas

- Additional network scenarios (VPN, VLANs, QoS)
- More exercises and tutorials
- Dashboard enhancements (graphs, alerts)
- Additional network tools
- Documentation improvements
- Bug fixes and optimizations
- Performance testing scripts

### Pull Request Guidelines

1. Follow existing code patterns
2. Update relevant documentation
3. Test thoroughly (all tests must pass)
4. Add new tests for new features
5. Update CHANGELOG (if exists)

## License

MIT License - See LICENSE file for details

## Support

- **Issues**: [GitHub Issues](https://github.com/manzolo/net-playground/issues)
- **Discussions**: [GitHub Discussions](https://github.com/manzolo/net-playground/discussions)
- **Documentation**: [docs/](docs/)

## Version History

### v2.0 (2026-01-21)
- Complete educational platform transformation
- Added monitoring dashboard
- Added test automation
- Added network scenarios
- Added comprehensive documentation
- Restructured menu system (interactive + CLI)
- Added safety features (auto-rollback)
- Added 15 hands-on exercises
- Added troubleshooting wizard

### v1.0 (Initial)
- Basic multi-router topology
- Docker Compose setup
- Basic networking capabilities

---

**For usage questions**, refer to README.md and docs/.

**For implementation details**, refer to this file and docs/API.md.

**For learning networking**, start with docs/NETWORKING-BASICS.md and docs/EXERCISES.md.
