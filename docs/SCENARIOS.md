# Network Scenarios Guide

This document provides detailed information about pre-configured network scenarios in the Docker Network Playground.

## Overview

Scenarios are interactive, guided tutorials that demonstrate specific networking concepts and configurations. Each scenario is self-contained and includes step-by-step instructions, safety mechanisms, and verification steps.

## Available Scenarios

### 01 - Basic Firewall Configuration

**Location**: `scenarios/01-basic-firewall.sh`

**Objective**: Learn iptables firewall basics with practical examples.

**Prerequisites**:
- All containers running (`./menu.sh start`)
- Basic understanding of IP addresses and network traffic

**What You'll Learn**:
- Blocking ICMP (ping) traffic from specific hosts
- Implementing rate limiting to prevent DDoS attacks
- Port-based traffic filtering
- How iptables chains work (INPUT, OUTPUT, FORWARD)
- Auto-rollback safety mechanisms

**Running the Scenario**:
```bash
./menu.sh scenario 01-basic-firewall.sh
```

Or directly:
```bash
./scenarios/01-basic-firewall.sh
```

**Steps Covered**:

1. **Block ICMP from pc1**
   - Applies: `iptables -A INPUT -p icmp -s 192.168.20.3 -j DROP`
   - Tests before and after applying the rule
   - Demonstrates selective traffic blocking
   - Learning: How to block specific protocols from specific sources

2. **Rate Limiting (Anti-DDoS)**
   - Applies: `iptables -A INPUT -p icmp -m limit --limit 5/second -j ACCEPT`
   - Demonstrates protection against ping floods
   - Tests with rapid ping attempts
   - Learning: How to use iptables rate limiting modules

3. **Block Specific Port**
   - Applies: `iptables -A INPUT -p tcp --dport 22 -j DROP`
   - Blocks SSH access (port 22)
   - Tests port accessibility before/after
   - Learning: Port-based filtering techniques

**Safety Features**:
- **Auto-Rollback**: Rules automatically revert after 60 seconds if not confirmed
- **Backup**: Automatic iptables state backup before changes
- **Manual Restore**: Option to restore previous state at any time
- **Clear Warnings**: Prominent warnings before applying potentially disruptive rules

**Expected Output**:
```
═══════════════════════════════════════════════════════
  Basic Firewall Configuration Tutorial
═══════════════════════════════════════════════════════

This scenario demonstrates iptables firewall configuration
on router1 with AUTO-ROLLBACK safety features.

Press Enter to continue or Ctrl+C to exit...

═══ Step 1: Block ICMP from pc1 ═══
Before applying rule:
Testing ping from pc1 to router1...
PING 192.168.20.2 (192.168.20.2) 56(84) bytes of data.
64 bytes from 192.168.20.2: icmp_seq=1 ttl=64 time=0.089 ms
--- Router responds normally

⚠ AUTO-ROLLBACK SAFETY FEATURE ACTIVATED
⚠ Rules will revert in 60 seconds unless confirmed
⚠ Keep this terminal open!

Applied rule: iptables -A INPUT -p icmp -s 192.168.20.3 -j DROP

Testing after rule...
--- no response (blocked) ---

✓ ICMP from pc1 is now blocked

Keep the new rules? (y/n): _
```

**Common Issues**:
- **Rule doesn't block traffic**: Ensure you're testing from the correct source IP
- **Timeout during confirmation**: Rules auto-rolled back for safety - this is expected
- **Container can't be reached**: Use `./scripts/container/firewall-examples.sh reset` to clear all rules

**Related Documentation**:
- [Firewall Examples Script API](API.md#firewall-examples)
- [Networking Basics - Firewalls](NETWORKING-BASICS.md#firewalls)
- [Troubleshooting - Firewall Issues](TROUBLESHOOTING.md#firewall-rules)

---

### 04 - Traffic Generation

**Location**: `scenarios/04-traffic-generation.sh`

**Objective**: Generate various types of network traffic for testing and monitoring.

**Prerequisites**:
- All containers running
- Web server accessible (`curl http://server_web` works from any PC)
- Basic understanding of network protocols

**What You'll Learn**:
- Generating HTTP load for web server testing
- Creating continuous ping streams
- DNS query flooding for DNS server testing
- Mixed traffic patterns
- Using iperf3 for bandwidth testing
- Monitoring traffic impact with dashboard

**Running the Scenario**:
```bash
./menu.sh scenario 04-traffic-generation.sh
```

**Steps Covered**:

1. **HTTP Load Testing**
   - Sends 100 HTTP requests to web server
   - 0.5 second delay between requests
   - Monitors response times and success rate
   - Learning: Web server load testing basics

2. **Continuous Ping Stream**
   - Establishes continuous ICMP echo requests
   - Tests network latency and stability
   - Runs for configurable duration
   - Learning: Network connectivity monitoring

3. **DNS Query Flood**
   - Generates rapid DNS queries
   - Tests DNS server performance
   - Demonstrates DNS load patterns
   - Learning: DNS server stress testing

4. **Mixed Traffic**
   - Combines HTTP, ICMP, and DNS traffic
   - Simulates realistic network usage
   - Demonstrates traffic patterns
   - Learning: Complex traffic scenarios

5. **Bandwidth Testing with iperf3**
   - Measures actual throughput between nodes
   - Tests TCP and UDP performance
   - Identifies bottlenecks
   - Learning: Network performance analysis

**Usage Examples**:

Generate HTTP traffic:
```bash
# Inside the scenario, or manually:
docker exec pc1 /scripts/container/generate-traffic.sh http server_web 100 0.5
```

Run bandwidth test:
```bash
# Start iperf3 server on web server:
docker exec server_web iperf3 -s -D

# Run client test from pc1:
docker exec pc1 iperf3 -c 192.168.60.5 -t 30
```

Generate mixed traffic:
```bash
docker exec pc1 /scripts/container/generate-traffic.sh mixed 60
```

**Monitoring Traffic**:

While traffic is being generated, monitor it with:

1. **Dashboard**: Open http://localhost/dashboard/ to see real-time stats
2. **Network Stats**: Run `./menu.sh stats` for CLI statistics
3. **tcpdump**: Capture packets on any container
   ```bash
   docker exec router1 tcpdump -i eth0 -n
   ```

**Expected Output**:
```
═══════════════════════════════════════════════════════
  Traffic Generation Tutorial
═══════════════════════════════════════════════════════

This scenario demonstrates various types of traffic generation
for testing and monitoring purposes.

TIP: Open the dashboard (http://localhost/dashboard/) to
     visualize the traffic in real-time.

Press Enter to continue or Ctrl+C to exit...

═══ Step 1: HTTP Load Testing ═══
Generating 100 HTTP requests to server_web...

[1] Request time: 0.023s - Status: 200
[2] Request time: 0.019s - Status: 200
[3] Request time: 0.021s - Status: 200
...
[100] Request time: 0.018s - Status: 200

✓ Summary:
  Total Requests: 100
  Successful: 100
  Failed: 0
  Average Time: 0.020s
  Min Time: 0.015s
  Max Time: 0.031s
```

**Performance Metrics**:

After running scenarios, check:
- CPU usage on containers (dashboard)
- Network I/O statistics (dashboard)
- Memory consumption
- Packet loss (if any)

**Common Issues**:
- **iperf3 connection refused**: Server not started - run `docker exec server_web iperf3 -s` first
- **High latency**: Expected with high traffic load - this is what we're testing
- **DNS timeouts**: DNS server overwhelmed - reduce query rate
- **Containers becoming slow**: High CPU usage from traffic generation - this is expected

**Stopping Traffic**:

Most traffic generation scripts run for a defined duration. To stop early:
- Press Ctrl+C in the scenario terminal
- Or kill the process inside the container:
  ```bash
  docker exec pc1 pkill -f generate-traffic
  ```

**Related Documentation**:
- [Traffic Generation Script API](API.md#generate-traffic)
- [Networking Basics - Traffic Patterns](NETWORKING-BASICS.md#traffic-patterns)
- [Exercises - Performance Testing](EXERCISES.md#performance-testing)

---

## Creating Custom Scenarios

Want to create your own scenarios? Follow this template:

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
header() { echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"; }

# Check prerequisites
check_prerequisites() {
    if ! docker ps | grep -q "pc1"; then
        error "Containers not running. Run './menu.sh start' first."
    fi
}

# Main scenario
main() {
    header
    echo -e "${CYAN}  Your Scenario Name${NC}"
    header
    echo ""
    echo "Scenario description and objectives..."
    echo ""
    read -p "Press Enter to continue or Ctrl+C to exit..."

    check_prerequisites

    # Your scenario steps here
    step1_your_first_step
    step2_your_second_step

    echo ""
    header
    success "Scenario completed!"
    header
}

step1_your_first_step() {
    echo ""
    echo -e "${CYAN}═══ Step 1: Your Step Description ═══${NC}"

    # Your implementation
    info "Doing something..."
    docker exec pc1 some-command

    success "Step 1 complete"
}

main "$@"
```

### Scenario Best Practices

1. **Always include safety mechanisms**:
   - Auto-rollback for destructive changes
   - Clear warnings before risky operations
   - Backup of original state

2. **Make it educational**:
   - Explain what each command does
   - Show before/after comparisons
   - Include expected output in comments

3. **Test thoroughly**:
   - Verify prerequisites
   - Test each step independently
   - Ensure cleanup works properly

4. **Provide clear output**:
   - Use color codes for readability
   - Show progress indicators
   - Display results clearly

5. **Document well**:
   - Add scenario to this SCENARIOS.md file
   - Update menu.sh if needed
   - Include troubleshooting tips

---

## Scenario Roadmap

Planned future scenarios:

### 02 - NAT Gateway Setup
- SNAT (Source NAT / Masquerading)
- DNAT (Destination NAT / Port Forwarding)
- Full NAT gateway configuration
- Testing NAT with external connectivity simulation

### 03 - Network Problems Simulation
- Adding latency with tc/netem
- Simulating packet loss
- Bandwidth limiting
- Jitter and unstable connections
- Packet corruption

### 05 - VPN Tunneling (Advanced)
- Setting up a simple VPN tunnel between networks
- Encrypted traffic between PCs
- Testing tunnel performance

### 06 - Load Balancing
- Round-robin load distribution
- Weighted load balancing
- Health checks and failover

### 07 - Network Segmentation
- Creating DMZ zones
- Inter-zone firewall rules
- Traffic isolation patterns

### 08 - Intrusion Detection
- Detecting port scans
- Identifying suspicious traffic patterns
- Automated blocking of malicious sources

---

## Contributing Scenarios

We welcome contributions of new scenarios! To contribute:

1. Create your scenario in the `scenarios/` directory
2. Test it thoroughly
3. Document it in this file
4. Submit a pull request

Good scenario ideas:
- Real-world networking problems
- Common configuration tasks
- Security testing scenarios
- Performance optimization examples
- Troubleshooting exercises

---

## Frequently Asked Questions

**Q: Can I run multiple scenarios simultaneously?**
A: Generally no - scenarios may conflict with each other. Always run scenarios one at a time and ensure cleanup between runs.

**Q: How do I reset after a scenario?**
A: Most scenarios include cleanup steps. You can also restart containers with `./menu.sh clean` for a fresh state.

**Q: Can scenarios damage my system?**
A: No - all changes are contained within Docker containers. Even destructive operations only affect the containers, which can be easily recreated.

**Q: How long do scenarios take?**
A: Most scenarios complete in 5-10 minutes. Traffic generation scenarios can run longer depending on your configuration.

**Q: Can I modify existing scenarios?**
A: Yes! All scenarios are bash scripts. Feel free to customize them for your learning needs.

**Q: Why does auto-rollback exist?**
A: Safety first! Auto-rollback prevents you from accidentally locking yourself out or breaking connectivity. It's especially important for firewall rules.

---

## Next Steps

After completing scenarios, try:

1. **[Hands-on Exercises](EXERCISES.md)** - Put your knowledge to the test
2. **[Networking Basics](NETWORKING-BASICS.md)** - Deepen your understanding
3. **Create your own scenario** - Best way to learn is by doing!
4. **[Troubleshooting Guide](TROUBLESHOOTING.md)** - When things go wrong

---

**Happy Learning! 🚀**

For issues or questions, visit: [GitHub Issues](https://github.com/manzolo/net-playground/issues)
