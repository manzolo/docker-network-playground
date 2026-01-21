# Troubleshooting Guide

This guide helps you diagnose and fix common issues in the Docker Network Playground.

## Table of Contents

- [Quick Diagnostic](#quick-diagnostic)
- [Docker Issues](#docker-issues)
- [Container Issues](#container-issues)
- [Network Connectivity Issues](#network-connectivity-issues)
- [DNS Resolution Issues](#dns-resolution-issues)
- [Firewall Issues](#firewall-issues)
- [Dashboard Issues](#dashboard-issues)
- [Performance Issues](#performance-issues)
- [Advanced Diagnostics](#advanced-diagnostics)

---

## Quick Diagnostic

Before diving into specific issues, run the automated troubleshoot wizard:

```bash
./menu.sh troubleshoot
```

This checks:
- ✅ Docker installation and status
- ✅ Container health
- ✅ Network configuration
- ✅ Connectivity between nodes
- ✅ DNS resolution
- ✅ Service availability
- ✅ Routing tables

The wizard will identify most common problems and suggest fixes.

---

## Docker Issues

### Docker Daemon Not Running

**Symptoms**:
```
Cannot connect to the Docker daemon
```

**Diagnosis**:
```bash
sudo systemctl status docker
```

**Solution**:
```bash
# Start Docker service
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker

# Check status
sudo systemctl status docker
```

### Permission Denied

**Symptoms**:
```
Got permission denied while trying to connect to the Docker daemon socket
```

**Diagnosis**:
```bash
groups | grep docker
```

**Solution**:
```bash
# Add your user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or use:
newgrp docker

# Verify
docker ps
```

### Docker Compose Not Found

**Symptoms**:
```
docker compose: command not found
```

**Solution**:
```bash
# Install Docker Compose (Ubuntu/Debian)
sudo apt update
sudo apt install docker-compose-plugin

# Verify
docker compose version
```

### Disk Space Issues

**Symptoms**:
```
no space left on device
```

**Diagnosis**:
```bash
df -h
docker system df
```

**Solution**:
```bash
# Clean up unused Docker resources
docker system prune -a

# Remove unused volumes
docker volume prune

# Remove specific containers
docker rm $(docker ps -aq)

# Remove unused images
docker image prune -a
```

---

## Container Issues

### Containers Not Starting

**Symptoms**:
```
./menu.sh start
# Some containers show "Exit 1" or "Restarting"
```

**Diagnosis**:
```bash
# Check container status
./menu.sh status

# View logs for failing container
./menu.sh logs <container_name>

# Check specific container
docker ps -a | grep <container_name>
```

**Common Causes and Solutions**:

**1. Port already in use**:
```bash
# Check if port 80 is in use
sudo lsof -i :80

# Kill the process or change docker-compose.yml port mapping
```

**2. Image build failed**:
```bash
# Rebuild images
./menu.sh build

# Check for build errors in output
```

**3. Volume mount issues**:
```bash
# Check if paths exist
ls -la monitoring/
ls -la scripts/

# Verify permissions
chmod -R 755 scripts/
```

### Container Keeps Restarting

**Symptoms**:
```
docker ps shows "Restarting (1) 5 seconds ago"
```

**Diagnosis**:
```bash
# View logs for crash details
docker logs <container_name>

# Check last 50 lines
docker logs --tail 50 <container_name>

# Follow logs in real-time
docker logs -f <container_name>
```

**Solutions**:

**If router container crashes**:
```bash
# Check if setup script has errors
docker exec router1 cat /scripts/router-setup.sh

# Manually enter container
docker run -it --rm manzolo/ubuntu-network-playground-router:latest /bin/bash

# Test setup script
/scripts/router-setup.sh
```

**If PC container crashes**:
```bash
# Similar approach for PC
docker run -it --rm manzolo/ubuntu-network-playground-pc:latest /bin/bash
```

### Unhealthy Container Status

**Symptoms**:
```
docker ps shows "unhealthy" status
```

**Diagnosis**:
```bash
# Check health check details
docker inspect <container_name> --format='{{json .State.Health}}' | jq

# View health check logs
docker inspect <container_name> | grep -A 20 Health
```

**Solution**:
```bash
# Restart unhealthy container
docker restart <container_name>

# If persistent, recreate container
docker compose up -d --force-recreate <container_name>

# Clean restart entire environment
./menu.sh clean
```

---

## Network Connectivity Issues

### Cannot Ping Between Containers

**Symptoms**:
```bash
docker exec pc1 ping 192.168.30.3
# No response or "Destination Host Unreachable"
```

**Diagnosis**:

**1. Check if containers are running**:
```bash
./menu.sh status
```

**2. Verify IP addresses**:
```bash
docker exec pc1 ip addr
docker exec pc3 ip addr
```

**3. Check routing tables**:
```bash
docker exec pc1 ip route
docker exec pc3 ip route
```

**4. Test connectivity step by step**:
```bash
# Same LAN (should work)
docker exec pc1 ping 192.168.20.2   # Router1

# Cross-router (requires routing)
docker exec pc1 ping 192.168.100.3  # Router2 via Router1
```

**Solutions**:

**If same-LAN ping fails**:
```bash
# Check Docker network
docker network inspect net-playgound_lan_20

# Ensure both containers connected
docker network ls
docker compose down && docker compose up -d
```

**If cross-LAN ping fails**:
```bash
# Check routing on source
docker exec pc1 ip route

# Should show default gateway
default via 192.168.20.2 dev eth0

# Check routing on routers
docker exec router1 ip route
docker exec router2 ip route

# Verify IP forwarding enabled
docker exec router1 sysctl net.ipv4.ip_forward
# Should show: net.ipv4.ip_forward = 1
```

**If routers can't forward**:
```bash
# Enter router and enable forwarding
docker exec -it router1 /bin/bash
sysctl -w net.ipv4.ip_forward=1

# Check iptables FORWARD chain
iptables -L FORWARD -v -n

# If all dropped, add rule
iptables -P FORWARD ACCEPT
```

### Docker Bridge Network Isolation

**Important**: Docker bridge networks are isolated by design. Direct PC-to-PC communication across different LANs (e.g., pc1 on lan_20 to pc3 on lan_30) may not work.

**What Works**:
- ✅ Same-LAN communication (pc1 ↔ pc2)
- ✅ PC to its gateway router
- ✅ Router to router (via transit networks)
- ✅ PC to services accessible via routers

**What May Not Work**:
- ❌ Direct cross-LAN PC-to-PC (without router forwarding)

**This is expected behavior** and demonstrates network segmentation.

### Traceroute Shows Incomplete Path

**Symptoms**:
```bash
docker exec pc1 traceroute 192.168.60.5
# Shows only 1-2 hops instead of full path
```

**Cause**: ICMP handling or iptables rules blocking traceroute packets.

**Workaround**:
```bash
# Use TCP traceroute instead
docker exec pc1 traceroute -T -p 80 192.168.60.5

# Or check routing tables directly
docker exec pc1 ip route
docker exec router1 ip route
docker exec router2 ip route
docker exec router3 ip route
```

---

## DNS Resolution Issues

### Cannot Resolve Hostnames

**Symptoms**:
```bash
docker exec pc1 nslookup server_web
# Connection timed out or no servers could be reached
```

**Diagnosis**:

**1. Check DNS container**:
```bash
docker ps | grep dnsmasq
./menu.sh logs dnsmasq
```

**2. Check DNS configuration**:
```bash
docker exec pc1 cat /etc/resolv.conf
# Should show: nameserver 192.168.20.10
```

**3. Test DNS connectivity**:
```bash
# Can we reach DNS server?
docker exec pc1 ping 192.168.20.10

# Can we query DNS directly?
docker exec pc1 nslookup server_web 192.168.20.10
```

**Solutions**:

**If DNS container not running**:
```bash
docker compose up -d dnsmasq
./menu.sh logs dnsmasq
```

**If DNS unreachable**:
```bash
# Check DNS has correct IPs on all networks
docker exec dnsmasq ip addr

# Should show:
# eth0: 192.168.20.10
# eth1: 192.168.30.10
# eth2: 192.168.40.10
# eth3: 192.168.60.10

# Recreate if wrong
docker compose up -d --force-recreate dnsmasq
```

**If DNS configuration wrong in container**:
```bash
# Check what Docker set
docker exec pc1 cat /etc/resolv.conf

# Manually add (temporary)
docker exec pc1 bash -c 'echo "nameserver 192.168.20.10" > /etc/resolv.conf'

# Permanent fix: check docker-compose.yml dns setting
```

### Resolves to Wrong IP

**Symptoms**:
```bash
docker exec pc1 nslookup router3
# Returns wrong IP (e.g., 192.168.100.4 instead of 192.168.60.2)
```

**Diagnosis**:
```bash
# Check dnsmasq hosts file
cat dnsmasq.hosts | grep router3
```

**Solution**:
```bash
# Edit dnsmasq.hosts with correct mappings
nano dnsmasq.hosts

# Restart DNS container
docker compose restart dnsmasq

# Verify
docker exec pc1 nslookup router3
```

### DNS Queries Slow

**Symptoms**:
DNS resolution takes several seconds.

**Diagnosis**:
```bash
# Time DNS query
docker exec pc1 time nslookup server_web

# Check DNS server load
docker stats dnsmasq
```

**Solution**:
```bash
# Check dnsmasq logs for errors
docker logs dnsmasq

# Restart DNS to clear cache
docker compose restart dnsmasq

# Reduce upstream DNS timeout in dnsmasq config if needed
```

---

## Firewall Issues

### Accidentally Locked Out

**Symptoms**:
Applied firewall rule and now can't connect to container.

**Solution**:

**Auto-rollback feature**: Wait 60 seconds. Rules automatically revert if not confirmed.

**Manual fix**:
```bash
# Restart container (clears iptables)
docker restart router1

# Or force recreate
docker compose up -d --force-recreate router1

# Verify clean state
docker exec router1 iptables -L -v -n
```

### Firewall Rule Not Working

**Symptoms**:
Applied iptables rule but traffic not blocked.

**Diagnosis**:
```bash
# Check rule is present
docker exec router1 iptables -L -v -n

# Check packet counters
docker exec router1 iptables -L -v -n | grep <your_rule>

# See if packets matching
```

**Common Issues**:

**1. Wrong chain**:
```bash
# INPUT: traffic TO this router
# OUTPUT: traffic FROM this router
# FORWARD: traffic THROUGH this router

# Example: blocking traffic between PCs needs FORWARD, not INPUT
iptables -A FORWARD -s 192.168.20.3 -d 192.168.60.5 -j DROP
```

**2. Rule order**:
```bash
# Rules processed top-down, first match wins
# Check if earlier rule accepting traffic

docker exec router1 iptables -L INPUT -n --line-numbers
```

**3. Wrong interface or IP**:
```bash
# Verify IP addresses
docker exec pc1 ip addr

# Check interface names
docker exec router1 ip link
```

### Can't Remove Firewall Rule

**Symptoms**:
```bash
iptables -D INPUT 1
# iptables: Index of deletion too big
```

**Solution**:
```bash
# List rules with line numbers
docker exec router1 iptables -L INPUT -n --line-numbers

# Delete by line number
docker exec router1 iptables -D INPUT <line_number>

# Or flush entire chain
docker exec router1 iptables -F INPUT

# Or use firewall script reset
docker exec router1 /scripts/container/firewall-examples.sh reset
```

---

## Dashboard Issues

### Dashboard Not Loading

**Symptoms**:
Browser shows "Unable to connect" or "Connection refused" at http://localhost/dashboard/

**Diagnosis**:
```bash
# Check web server running
docker ps | grep server_web

# Check port 80 exposed
docker port server_web

# Test from host
curl http://localhost
```

**Solutions**:

**If server_web not running**:
```bash
docker compose up -d server_web
docker logs server_web
```

**If port 80 in use**:
```bash
# Find what's using port 80
sudo lsof -i :80

# Kill the process or change docker-compose.yml port
# Change: "80:80" to "8080:80"
# Access at: http://localhost:8080/dashboard/
```

**If nginx not serving dashboard**:
```bash
# Check volume mount
docker inspect server_web | grep -A 10 Mounts

# Should show monitoring directory mounted

# Check files exist
ls -la monitoring/
ls -la monitoring/api/

# Recreate with volume
docker compose up -d --force-recreate server_web
```

### Dashboard Loads But Shows No Data

**Symptoms**:
Dashboard HTML loads but sections show "No data available" or spinner keeps spinning.

**Diagnosis**:
```bash
# Check JSON files exist
ls -la monitoring/api/
cat monitoring/api/status.json
cat monitoring/api/stats.json
cat monitoring/api/network.json
```

**Solution**:
```bash
# Generate fresh data
./menu.sh monitor

# Or manually
./scripts/host/generate-stats.sh

# Verify JSON files updated
cat monitoring/api/network.json

# Should show networks array with data
```

### Dashboard Shows 404 for Assets

**Symptoms**:
Browser console shows:
```
GET http://localhost/dashboard/dashboard.css 404
GET http://localhost/dashboard/dashboard.js 404
```

**Diagnosis**:
```bash
# Check files exist
ls -la monitoring/dashboard.css
ls -la monitoring/dashboard.js
ls -la monitoring/index.html
```

**Solution**:
```bash
# Verify volume mount in docker-compose.yml
docker compose config | grep -A 5 "server_web:"

# Should show:
#   volumes:
#     - ./monitoring:/usr/share/nginx/html/dashboard:ro

# Restart web server
docker compose restart server_web
```

### Dashboard Not Auto-Refreshing

**Symptoms**:
Data doesn't update automatically.

**Diagnosis**:
Check browser console for JavaScript errors.

**Solution**:
```bash
# Generate monitoring data in loop
./scripts/host/generate-stats.sh --loop

# This updates JSON files every 5 seconds
# Dashboard auto-refreshes every 10 seconds

# Or manually refresh in browser
```

---

## Performance Issues

### High CPU Usage

**Symptoms**:
```bash
docker stats
# Shows containers using 50-100% CPU
```

**Diagnosis**:
```bash
# Check which container
docker stats --no-stream

# Check processes inside container
docker exec router1 top
```

**Common Causes**:

**1. Traffic generation running**:
```bash
# Stop traffic generation
docker exec pc1 pkill -f generate-traffic

# Verify stopped
docker exec pc1 ps aux | grep generate
```

**2. Network problem simulation active**:
```bash
# Reset network conditions
docker exec pc1 /scripts/container/network-problems.sh reset eth0
```

**3. iperf3 server running**:
```bash
# Stop iperf3
docker exec server_web pkill iperf3
```

### High Memory Usage

**Symptoms**:
```bash
docker stats
# Shows containers using excessive memory
```

**Diagnosis**:
```bash
# Check memory per container
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}"

# Check container processes
docker exec <container> ps aux --sort=-%mem
```

**Solution**:
```bash
# Restart high-memory container
docker restart <container_name>

# Set memory limits in docker-compose.yml
# Add under service definition:
#   mem_limit: 512m

# Apply changes
docker compose up -d
```

### Slow Network Performance

**Symptoms**:
High latency or low throughput between containers.

**Diagnosis**:
```bash
# Test latency
docker exec pc1 ping -c 10 192.168.60.5

# Test throughput
docker exec server_web iperf3 -s -D
docker exec pc1 iperf3 -c 192.168.60.5 -t 10
```

**Possible Causes**:

**1. Network problem simulation active**:
```bash
# Check for tc rules
docker exec pc1 tc qdisc show

# Reset if found
docker exec pc1 /scripts/container/network-problems.sh reset eth0
```

**2. Host system overloaded**:
```bash
# Check host resources
top
df -h

# Close other applications
# Free disk space
```

**3. Too many containers**:
```bash
# Stop unused containers
docker stop <unused_container>

# Or scale down in docker-compose.yml
```

---

## Advanced Diagnostics

### Enable Debug Logging

**For Docker**:
```bash
# Edit Docker daemon config
sudo nano /etc/docker/daemon.json

# Add:
{
  "debug": true,
  "log-level": "debug"
}

# Restart Docker
sudo systemctl restart docker

# View debug logs
sudo journalctl -u docker -f
```

**For Containers**:
```bash
# Run commands with verbose output
docker exec router1 bash -x /scripts/router-setup.sh

# Enable iptables logging
docker exec router1 iptables -A INPUT -j LOG --log-prefix "IPTABLES-INPUT: "

# View kernel logs
docker exec router1 dmesg | tail
```

### Packet Capture for Deep Analysis

```bash
# Capture on router interface
docker exec router1 tcpdump -i eth0 -w /tmp/capture.pcap

# Generate traffic
docker exec pc1 ping -c 5 192.168.30.3

# Stop capture (Ctrl+C)

# Copy capture file to host
docker cp router1:/tmp/capture.pcap ./capture.pcap

# Analyze with Wireshark on host
wireshark capture.pcap
```

### Systematic Network Debug

**Step-by-step network troubleshooting**:

```bash
# 1. Layer 2 - Link status
docker exec pc1 ip link show

# 2. Layer 3 - IP configuration
docker exec pc1 ip addr show

# 3. Layer 3 - Routing
docker exec pc1 ip route show

# 4. Layer 3 - Gateway reachability
docker exec pc1 ping -c 3 192.168.20.2

# 5. Layer 3 - End-to-end connectivity
docker exec pc1 ping -c 3 192.168.60.5

# 6. Layer 3 - Path tracing
docker exec pc1 traceroute 192.168.60.5

# 7. Layer 4 - Port connectivity
docker exec pc1 nc -zv 192.168.60.5 80

# 8. Layer 7 - Application
docker exec pc1 curl http://192.168.60.5
```

### Reset to Clean State

**Nuclear option** - reset everything:

```bash
# Stop all containers
docker compose down

# Remove all containers
docker rm -f $(docker ps -aq)

# Remove all networks (except defaults)
docker network prune -f

# Remove all volumes
docker volume prune -f

# Rebuild images
./menu.sh build

# Start fresh
./menu.sh start

# Verify
./menu.sh test-all
```

---

## Getting Help

If you've tried the above and still have issues:

### Collect Diagnostic Information

```bash
# Run full diagnostic
./menu.sh troubleshoot > diagnostic.txt

# Collect logs
docker compose logs > docker-logs.txt

# System info
docker version >> diagnostic.txt
docker compose version >> diagnostic.txt
uname -a >> diagnostic.txt
```

### Report Issues

Visit [GitHub Issues](https://github.com/manzolo/net-playground/issues) with:

1. Description of the problem
2. Steps to reproduce
3. Expected vs actual behavior
4. Output of diagnostic commands
5. Your environment (OS, Docker version)

### Community Support

- [GitHub Discussions](https://github.com/manzolo/net-playground/discussions)
- Check [existing issues](https://github.com/manzolo/net-playground/issues)
- Read other documentation: [SCENARIOS.md](SCENARIOS.md), [NETWORKING-BASICS.md](NETWORKING-BASICS.md)

---

## Prevention Tips

### Before Making Changes

1. **Backup current state**: `docker commit <container> backup-name`
2. **Test in one container first**: Don't apply changes to all routers at once
3. **Use auto-rollback features**: Let firewall rules revert automatically
4. **Document your changes**: Keep notes on what you modified

### Regular Maintenance

```bash
# Weekly: Clean up Docker resources
docker system prune

# After major changes: Rebuild images
./menu.sh build

# After config changes: Recreate containers
./menu.sh clean

# Regular testing: Run test suite
./menu.sh test-all
```

### Know Your Baseline

```bash
# Save baseline test results
./menu.sh test-all > baseline-tests.txt

# After changes, compare
./menu.sh test-all > current-tests.txt
diff baseline-tests.txt current-tests.txt
```

---

**Remember**: This is a learning environment. Breaking things and fixing them is part of the learning process!

For more learning resources, see:
- [Exercises](EXERCISES.md) - Hands-on challenges
- [Scenarios](SCENARIOS.md) - Guided tutorials
- [Networking Basics](NETWORKING-BASICS.md) - Fundamental concepts

---

Happy troubleshooting! 🔧
