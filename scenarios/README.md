# Network Scenarios

This directory contains pre-configured network scenarios that demonstrate various networking concepts and configurations.

## Available Scenarios

### 01-basic-firewall.sh
Demonstrates basic firewall configuration using iptables:
- Block ICMP from specific hosts
- Rate limiting for DoS protection
- Port filtering

**Use case**: Learn firewall basics, test network security configurations

### 02-nat-gateway.sh
Sets up Network Address Translation (NAT):
- Configure router as NAT gateway
- Port forwarding examples
- SNAT and DNAT configurations

**Use case**: Understand NAT, simulate internet gateway scenarios

### 03-network-problems.sh
Simulates various network issues:
- High latency scenarios
- Packet loss simulation
- Bandwidth constraints
- Unstable network conditions

**Use case**: Test application resilience, demonstrate network problems

### 04-traffic-generation.sh
Generates network traffic for testing:
- HTTP requests to web server
- Continuous ping tests
- Bandwidth testing with iperf3
- DNS query generation

**Use case**: Load testing, bandwidth measurement, connectivity verification

## Running Scenarios

All scenario scripts are designed to be run from the project root:

```bash
# Make scripts executable (if needed)
chmod +x scenarios/*.sh

# Run a scenario
./scenarios/01-basic-firewall.sh

# Or use the menu
./menu.sh
# Select: Network Scenarios → Choose scenario
```

## Important Notes

1. **Container State**: All configurations are temporary and reset when containers restart
2. **Safety**: Scenarios include safety features like auto-rollback and confirmation prompts
3. **Prerequisites**: Ensure all containers are running before executing scenarios
4. **Cleanup**: Each scenario provides instructions for cleanup/reset

## Creating Custom Scenarios

To create your own scenario:

1. Copy an existing scenario as a template
2. Modify the configuration commands
3. Update the description and help text
4. Test thoroughly before sharing

## Scenario Structure

Each scenario follows this structure:

```bash
#!/bin/bash
# Scenario description and metadata

# Safety checks (containers running, etc.)
# Main scenario logic
# Cleanup instructions
# Help/documentation
```

## Educational Value

These scenarios are designed for:
- Hands-on learning of networking concepts
- Testing network configurations safely
- Demonstrating troubleshooting techniques
- Providing reproducible network setups

## Contributing

To contribute new scenarios:
1. Follow the existing naming convention (##-description.sh)
2. Include comprehensive help/documentation
3. Add safety checks and cleanup instructions
4. Test in a clean environment
