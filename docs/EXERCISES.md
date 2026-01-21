# Hands-On Exercises and Challenges

This document contains practical exercises and challenge problems to help you master networking concepts using the Docker Network Playground.

## How to Use This Guide

Each exercise includes:
- **Objective**: What you'll learn
- **Difficulty**: Beginner, Intermediate, or Advanced
- **Prerequisites**: Required knowledge/completed exercises
- **Steps**: Detailed instructions
- **Verification**: How to confirm success
- **Solution**: Hidden solution (try first!)

## Difficulty Levels

- 🟢 **Beginner**: Basic commands and concepts
- 🟡 **Intermediate**: Multiple steps, requires understanding
- 🔴 **Advanced**: Complex scenarios, troubleshooting required

---

## Table of Contents

### Beginner Exercises
1. [Network Discovery](#exercise-1-network-discovery-🟢)
2. [Basic Connectivity Testing](#exercise-2-basic-connectivity-testing-🟢)
3. [DNS Exploration](#exercise-3-dns-exploration-🟢)
4. [Routing Table Analysis](#exercise-4-routing-table-analysis-🟢)
5. [Web Server Access](#exercise-5-web-server-access-🟢)

### Intermediate Exercises
6. [Multi-Hop Communication](#exercise-6-multi-hop-communication-🟡)
7. [Firewall Configuration](#exercise-7-firewall-configuration-🟡)
8. [NAT Setup](#exercise-8-nat-setup-🟡)
9. [Traffic Analysis](#exercise-9-traffic-analysis-🟡)
10. [Network Performance Testing](#exercise-10-network-performance-testing-🟡)

### Advanced Exercises
11. [Complex Firewall Policy](#exercise-11-complex-firewall-policy-🔴)
12. [Load Balancing](#exercise-12-load-balancing-🔴)
13. [Network Troubleshooting Challenge](#exercise-13-network-troubleshooting-challenge-🔴)
14. [Secure Communication Path](#exercise-14-secure-communication-path-🔴)
15. [Build Your Own Scenario](#exercise-15-build-your-own-scenario-🔴)

---

## Beginner Exercises

### Exercise 1: Network Discovery 🟢

**Objective**: Discover all hosts in the network and document the topology.

**Prerequisites**: Containers running (`./menu.sh start`)

**Tasks**:

1. Find the IP address of all PCs (pc1-pc5)
2. Find the IP addresses of all router interfaces
3. Identify which LAN each PC belongs to
4. List all transit networks

**Steps**:

```bash
# 1. Check PC IP addresses
docker exec pc1 ip addr show eth0 | grep inet
docker exec pc2 ip addr show eth0 | grep inet
docker exec pc3 ip addr show eth0 | grep inet
docker exec pc4 ip addr show eth0 | grep inet
docker exec pc5 ip addr show eth0 | grep inet

# 2. Check router interfaces
docker exec router1 ip addr | grep "inet "
docker exec router2 ip addr | grep "inet "
docker exec router3 ip addr | grep "inet "

# 3. Check server and DNS
docker exec server_web ip addr show eth0 | grep inet
docker exec dnsmasq ip addr | grep "inet "
```

**Verification**:

Create a table like this:

| Host | IP Address(es) | Network(s) |
|------|----------------|-----------|
| pc1 | ? | ? |
| pc2 | ? | ? |
| ... | ... | ... |

<details>
<summary>Solution</summary>

| Host | IP Address(es) | Network(s) |
|------|----------------|-----------|
| pc1 | 192.168.20.3 | LAN 20 |
| pc2 | 192.168.20.4 | LAN 20 |
| pc3 | 192.168.30.3 | LAN 30 |
| pc4 | 192.168.40.3 | LAN 40 |
| pc5 | 192.168.40.4 | LAN 40 |
| router1 | 192.168.20.2, 192.168.30.2, 192.168.100.2 | LAN 20, LAN 30, Transit 12 |
| router2 | 192.168.40.2, 192.168.100.3, 192.168.200.2 | LAN 40, Transit 12, Transit 23 |
| router3 | 192.168.60.2, 192.168.200.3 | LAN 60, Transit 23 |
| server_web | 192.168.60.5 | LAN 60 |
| dnsmasq | 192.168.20.10, 192.168.30.10, 192.168.40.10, 192.168.60.10 | All LANs (multi-homed) |

</details>

---

### Exercise 2: Basic Connectivity Testing 🟢

**Objective**: Test network connectivity within and across LANs.

**Prerequisites**: Exercise 1 completed

**Tasks**:

1. Test same-LAN connectivity (pc1 → pc2)
2. Test connectivity to local router (pc1 → router1)
3. Test connectivity to another router (pc1 → router2)
4. Test connectivity to web server (pc1 → server_web)

**Steps**:

```bash
# 1. Same LAN
docker exec pc1 ping -c 3 192.168.20.4

# 2. Local router
docker exec pc1 ping -c 3 192.168.20.2

# 3. Remote router (via transit)
docker exec pc1 ping -c 3 192.168.100.3

# 4. Web server (multi-hop)
docker exec pc1 ping -c 3 192.168.60.5
```

**Verification**:

All pings should succeed with low latency (<1ms typically).

**Challenge**: Which tests work and why? Document the path each packet takes.

<details>
<summary>Solution</summary>

1. **pc1 → pc2**: Works directly (same LAN)
2. **pc1 → router1**: Works directly (default gateway)
3. **pc1 → router2**: Works via router1 (routing)
   - Path: pc1 → router1 → router2
4. **pc1 → server_web**: Works via router1 → router2 → router3
   - Path: pc1 → router1 → router2 → router3 → server_web

</details>

---

### Exercise 3: DNS Exploration 🟢

**Objective**: Understand DNS resolution in the network.

**Prerequisites**: Exercise 1 completed

**Tasks**:

1. Resolve all PC hostnames to IPs
2. Resolve router hostnames
3. Test reverse DNS lookup
4. Identify the DNS server IP for each LAN

**Steps**:

```bash
# 1. Resolve hostnames
docker exec pc1 nslookup pc1
docker exec pc1 nslookup pc2
docker exec pc1 nslookup pc3
docker exec pc1 nslookup server_web

# 2. Resolve routers
docker exec pc1 nslookup router1
docker exec pc1 nslookup router2
docker exec pc1 nslookup router3

# 3. Reverse lookup
docker exec pc1 nslookup 192.168.60.5

# 4. Find DNS server
docker exec pc1 cat /etc/resolv.conf
docker exec pc3 cat /etc/resolv.conf
docker exec pc4 cat /etc/resolv.conf
```

**Verification**:

- All hostnames resolve to correct IPs
- Reverse lookup works
- Each PC uses its local DNS IP (192.168.X.10)

**Challenge**: Why is DNS multi-homed? What advantage does this provide?

<details>
<summary>Solution</summary>

DNS is multi-homed (connected to all LANs) so:
- Each PC can reach DNS directly on its local network
- No routing required for DNS queries
- Reduces latency and points of failure
- DNS remains accessible even if routers fail

Each LAN sees DNS at:
- LAN 20: 192.168.20.10
- LAN 30: 192.168.30.10
- LAN 40: 192.168.40.10
- LAN 60: 192.168.60.10

</details>

---

### Exercise 4: Routing Table Analysis 🟢

**Objective**: Understand routing tables and how packets are forwarded.

**Prerequisites**: Exercise 1 completed

**Tasks**:

1. View routing table on pc1
2. View routing table on router1
3. Identify the default gateway for each PC
4. Determine next hop for traffic from pc1 to server_web

**Steps**:

```bash
# 1. PC routing table
docker exec pc1 ip route

# 2. Router routing table
docker exec router1 ip route

# 3. Check all PCs' default gateways
docker exec pc1 ip route | grep default
docker exec pc2 ip route | grep default
docker exec pc3 ip route | grep default
docker exec pc4 ip route | grep default
docker exec pc5 ip route | grep default

# 4. Trace the path
docker exec pc1 traceroute 192.168.60.5
```

**Verification**:

- PCs have default gateway pointing to their local router
- Routers have routes to all networks
- Traceroute shows complete path

**Challenge**: Draw a diagram showing the path from pc1 to server_web.

<details>
<summary>Solution</summary>

**PC routing tables** (simplified):
```
pc1: default via 192.168.20.2 (router1)
pc3: default via 192.168.30.2 (router1)
pc4: default via 192.168.40.2 (router2)
pc5: default via 192.168.40.2 (router2)
```

**Router1 routing table**:
```
192.168.20.0/28 → direct (eth0)
192.168.30.0/28 → direct (eth1)
192.168.40.0/28 → via 192.168.100.3 (router2)
192.168.60.0/28 → via 192.168.100.3 (router2)
192.168.100.0/29 → direct (eth2)
```

**Path pc1 → server_web**:
```
pc1 (192.168.20.3)
  ↓ default gateway
router1 (192.168.20.2)
  ↓ route to 192.168.60.0/28 via 192.168.100.3
router2 (192.168.100.3)
  ↓ route to 192.168.60.0/28 via 192.168.200.3
router3 (192.168.200.3)
  ↓ directly connected
server_web (192.168.60.5)
```

</details>

---

### Exercise 5: Web Server Access 🟢

**Objective**: Access the web server from different network locations.

**Prerequisites**: Exercises 1-4 completed

**Tasks**:

1. Access web server from pc1 using IP
2. Access web server from pc1 using hostname
3. Access web server from your host machine
4. View web server logs

**Steps**:

```bash
# 1. From pc1 using IP
docker exec pc1 curl http://192.168.60.5

# 2. From pc1 using hostname
docker exec pc1 curl http://server_web

# 3. From host machine
curl http://localhost

# 4. View server logs
docker logs server_web
```

**Verification**:

- All requests return nginx default page
- Hostname resolution works
- Server logs show all requests

**Challenge**: Can you determine the difference in how requests from pc1 and the host machine reach the server?

<details>
<summary>Solution</summary>

**From pc1**:
- Request goes through: pc1 → router1 → router2 → router3 → server_web
- Uses internal routing
- Source IP: 192.168.20.3

**From host**:
- Request goes through: host → Docker bridge → server_web
- Uses Docker port mapping (80:80)
- Direct container access (no routing needed)
- Source IP: Docker bridge IP

**Server logs** show different source IPs for each request type.

</details>

---

## Intermediate Exercises

### Exercise 6: Multi-Hop Communication 🟡

**Objective**: Analyze multi-hop packet flow and understand routing decisions.

**Prerequisites**: All beginner exercises completed

**Tasks**:

1. Trace the complete path from pc2 to pc5
2. Calculate the number of hops
3. Capture packets at each hop
4. Measure latency at each hop

**Steps**:

```bash
# 1. Trace route
docker exec pc2 traceroute 192.168.40.4

# 2. Count hops
docker exec pc2 traceroute 192.168.40.4 | wc -l

# 3. Capture at each point
# Terminal 1: Capture on router1
docker exec router1 tcpdump -i any icmp -n

# Terminal 2: Capture on router2
docker exec router2 tcpdump -i any icmp -n

# Terminal 3: Send pings
docker exec pc2 ping -c 5 192.168.40.4

# 4. Measure latency
docker exec pc2 ping -c 10 192.168.40.4
```

**Verification**:

- Traceroute shows: pc2 → router1 → router2 → pc5
- tcpdump shows packets passing through each router
- Latency is low and consistent

**Challenge**:

1. What happens if router1 goes down? Test by stopping router1.
2. Can you create an alternative path?

<details>
<summary>Solution</summary>

**Normal path pc2 → pc5**:
```
pc2 (192.168.20.4)
  ↓ default gateway
router1 (192.168.20.2)
  ↓ route to 192.168.40.0/28 via 192.168.100.3
router2 (192.168.100.3)
  ↓ directly connected to 192.168.40.0/28
pc5 (192.168.40.4)
```

**Hops**: 3 router hops + 1 destination = 4 total

**If router1 goes down**:
```bash
docker stop router1
docker exec pc2 ping 192.168.40.4
# FAILS - no alternative path configured
```

This demonstrates the importance of redundancy in production networks. In a real network, dynamic routing protocols (OSPF, BGP) would find alternative paths automatically.

**To restore**:
```bash
docker start router1
```

</details>

---

### Exercise 7: Firewall Configuration 🟡

**Objective**: Configure iptables firewall rules to control traffic.

**Prerequisites**: Understanding of iptables basics

**Tasks**:

1. Block ICMP from pc1 to router1
2. Allow only HTTP traffic to server_web
3. Implement rate limiting on router1
4. Create a stateful firewall rule

**Steps**:

```bash
# 1. Block ICMP from pc1
docker exec router1 iptables -A INPUT -p icmp -s 192.168.20.3 -j DROP

# Test
docker exec pc1 ping -c 3 192.168.20.2  # Should fail
docker exec pc2 ping -c 3 192.168.20.2  # Should work

# 2. Allow only HTTP to server (on router3)
docker exec router3 iptables -A FORWARD -d 192.168.60.5 -p tcp --dport 80 -j ACCEPT
docker exec router3 iptables -A FORWARD -d 192.168.60.5 -j DROP

# Test
docker exec pc1 curl http://192.168.60.5  # Should work
docker exec pc1 curl http://192.168.60.5:443  # Should fail

# 3. Rate limiting (5 ICMP per second)
docker exec router1 iptables -A INPUT -p icmp -m limit --limit 5/second -j ACCEPT
docker exec router1 iptables -A INPUT -p icmp -j DROP

# Test with rapid pings
docker exec pc2 ping -f -c 100 192.168.20.2

# 4. Stateful firewall
docker exec router1 iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
docker exec router1 iptables -A INPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT
docker exec router1 iptables -A INPUT -j DROP
```

**Verification**:

- pc1 cannot ping router1, but pc2 can
- Only HTTP traffic reaches server_web
- Rate limiting allows 5 pings/sec, drops excess
- Established connections work, new connections allowed only to port 80

**Challenge**: Create a firewall rule that blocks traffic from pc1 to any host in LAN 40.

<details>
<summary>Solution</summary>

To block pc1 from reaching LAN 40, add rule on router1 or router2:

**On router1** (preferred - blocks early):
```bash
docker exec router1 iptables -A FORWARD -s 192.168.20.3 -d 192.168.40.0/28 -j DROP
```

Test:
```bash
docker exec pc1 ping -c 3 192.168.40.3  # Should fail
docker exec pc1 ping -c 3 192.168.40.4  # Should fail
docker exec pc2 ping -c 3 192.168.40.3  # Should work
```

**To reset all rules**:
```bash
docker exec router1 iptables -F
docker exec router1 iptables -P INPUT ACCEPT
docker exec router1 iptables -P FORWARD ACCEPT
docker exec router1 iptables -P OUTPUT ACCEPT
```

Or use the script:
```bash
docker exec router1 /scripts/container/firewall-examples.sh reset
```

</details>

---

### Exercise 8: NAT Setup 🟡

**Objective**: Configure SNAT and DNAT to modify packet addressing.

**Prerequisites**: Understanding of NAT concepts

**Tasks**:

1. Set up SNAT (masquerading) on router1
2. Configure DNAT to forward port 8080 to server_web:80
3. Verify NAT is working
4. View NAT connection tracking

**Steps**:

```bash
# 1. SNAT setup on router1
docker exec router1 iptables -t nat -A POSTROUTING -o eth2 -j MASQUERADE

# Enable forwarding if not already enabled
docker exec router1 sysctl -w net.ipv4.ip_forward=1

# Test - traffic from LAN 20/30 to transit network is NATed
docker exec router1 tcpdump -i eth2 -n &
docker exec pc1 ping -c 3 192.168.100.3

# 2. DNAT setup on router2
docker exec router2 iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 192.168.60.5:80

# Enable forwarding
docker exec router2 sysctl -w net.ipv4.ip_forward=1

# Test from pc4 (same router)
docker exec pc4 curl http://192.168.40.2:8080

# 3. Verify NAT rules
docker exec router1 iptables -t nat -L -v -n
docker exec router2 iptables -t nat -L -v -n

# 4. View connection tracking
docker exec router1 cat /proc/net/nf_conntrack
```

**Verification**:

- SNAT changes source IP of packets leaving router1 eth2
- Port 8080 on router2 forwards to server_web:80
- Connection tracking shows active NAT sessions

**Challenge**: Set up a complete NAT gateway so pc1 can "access the Internet" (simulate with pc5 as Internet host).

<details>
<summary>Solution</summary>

**Complete NAT gateway on router1**:

```bash
# 1. Enable forwarding
docker exec router1 sysctl -w net.ipv4.ip_forward=1

# 2. SNAT for LAN 20 and LAN 30
docker exec router1 iptables -t nat -A POSTROUTING -s 192.168.20.0/28 -o eth2 -j MASQUERADE
docker exec router1 iptables -t nat -A POSTROUTING -s 192.168.30.0/28 -o eth2 -j MASQUERADE

# 3. Allow forwarding
docker exec router1 iptables -A FORWARD -i eth0 -o eth2 -j ACCEPT
docker exec router1 iptables -A FORWARD -i eth1 -o eth2 -j ACCEPT
docker exec router1 iptables -A FORWARD -i eth2 -o eth0 -m state --state ESTABLISHED,RELATED -j ACCEPT
docker exec router1 iptables -A FORWARD -i eth2 -o eth1 -m state --state ESTABLISHED,RELATED -j ACCEPT

# 4. Verify
docker exec router1 iptables -t nat -L -v -n

# Test: pc1 traffic appears to come from router1
docker exec pc1 ping -c 3 192.168.100.3
```

**On router2, capture to see NAT**:
```bash
docker exec router2 tcpdump -i eth1 -n icmp
# Shows source IP as 192.168.100.2 (router1), not 192.168.20.3 (pc1)
```

**DNAT complete setup**:
```bash
# Forward external port 8080 to server_web:80
docker exec router2 iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 192.168.60.5:80

# SNAT for return traffic
docker exec router2 iptables -t nat -A POSTROUTING -d 192.168.60.5 -p tcp --dport 80 -j MASQUERADE

# Allow forwarding
docker exec router2 iptables -A FORWARD -p tcp --dport 80 -d 192.168.60.5 -j ACCEPT

# Test
docker exec pc4 curl http://192.168.40.2:8080
```

**Cleanup**:
```bash
docker exec router1 iptables -t nat -F
docker exec router2 iptables -t nat -F
```

</details>

---

### Exercise 9: Traffic Analysis 🟡

**Objective**: Capture and analyze network traffic using tcpdump.

**Prerequisites**: Basic tcpdump knowledge

**Tasks**:

1. Capture HTTP traffic between pc1 and server_web
2. Analyze TCP three-way handshake
3. Identify all protocols in captured traffic
4. Find the busiest network segment

**Steps**:

```bash
# 1. Capture HTTP traffic
docker exec router3 tcpdump -i eth0 'port 80' -w /tmp/http.pcap &
TCPDUMP_PID=$!

# Generate HTTP traffic
docker exec pc1 curl http://192.168.60.5
docker exec pc1 curl http://192.168.60.5
docker exec pc1 curl http://192.168.60.5

# Stop capture
kill $TCPDUMP_PID

# Read capture
docker exec router3 tcpdump -r /tmp/http.pcap -n

# 2. Analyze handshake
docker exec router3 tcpdump -r /tmp/http.pcap -n 'tcp[tcpflags] & (tcp-syn) != 0'

# 3. Identify protocols
docker exec router1 tcpdump -i any -c 100 -n

# Generate various traffic
docker exec pc1 ping -c 5 192.168.60.5 &
docker exec pc1 curl http://192.168.60.5 &
docker exec pc1 nslookup server_web &

# 4. Monitor all routers
docker exec router1 tcpdump -i any -c 50 -n &
docker exec router2 tcpdump -i any -c 50 -n &
docker exec router3 tcpdump -i any -c 50 -n &

# Generate traffic
./scripts/container/generate-traffic.sh http server_web 50 0.1
```

**Verification**:

- HTTP capture shows requests and responses
- Three-way handshake visible: SYN, SYN-ACK, ACK
- Multiple protocols identified: ICMP, TCP (HTTP), UDP (DNS)
- Busiest segment identified based on packet count

**Challenge**: Identify which router handles the most traffic and explain why.

<details>
<summary>Solution</summary>

**TCP Three-Way Handshake** in capture:
```
1. Client → Server: [S] (SYN)           # Initiate connection
2. Server → Client: [S.] (SYN-ACK)      # Acknowledge and sync
3. Client → Server: [.] (ACK)           # Complete handshake
4. Client → Server: [P.] (PSH-ACK)      # Send HTTP request
5. Server → Client: [.] (ACK)           # Acknowledge request
6. Server → Client: [P.] (PSH-ACK)      # Send HTTP response
7. Client → Server: [.] (ACK)           # Acknowledge response
8. Client → Server: [F.] (FIN-ACK)      # Close connection
9. Server → Client: [F.] (FIN-ACK)      # Acknowledge and close
10. Client → Server: [.] (ACK)          # Final ACK
```

**Protocols observed**:
- **ICMP**: Ping traffic
- **TCP port 80**: HTTP traffic
- **UDP port 53**: DNS queries
- **TCP handshakes**: Connection establishment

**Busiest router**: Typically **router2** because:
- It's in the middle of the topology
- Forwards traffic between:
  - LAN 20/30 (via router1) → LAN 60 (via router3)
  - LAN 40 → LAN 60 (direct to router3)
  - LAN 40 → LAN 20/30 (via router1)
- Handles most inter-LAN traffic

Verify with:
```bash
docker exec router1 iptables -L -v -n | grep "Chain FORWARD"
docker exec router2 iptables -L -v -n | grep "Chain FORWARD"
docker exec router3 iptables -L -v -n | grep "Chain FORWARD"
```

</details>

---

### Exercise 10: Network Performance Testing 🟡

**Objective**: Measure network performance using iperf3 and analyze results.

**Prerequisites**: Understanding of bandwidth concepts

**Tasks**:

1. Measure bandwidth between pc1 and server_web
2. Test TCP vs UDP performance
3. Measure latency and jitter
4. Identify bottlenecks

**Steps**:

```bash
# 1. TCP bandwidth test
docker exec server_web iperf3 -s -D

# From pc1 to server (10 second test)
docker exec pc1 iperf3 -c 192.168.60.5 -t 10

# 2. UDP performance
docker exec pc1 iperf3 -c 192.168.60.5 -u -b 100M -t 10

# 3. Reverse test (server sends to client)
docker exec pc1 iperf3 -c 192.168.60.5 -R -t 10

# 4. Multiple parallel streams
docker exec pc1 iperf3 -c 192.168.60.5 -P 4 -t 10

# 5. Latency test with ping
docker exec pc1 ping -c 100 192.168.60.5 > /tmp/ping-results.txt

# Analyze results
docker exec pc1 cat /tmp/ping-results.txt | tail -2
```

**Verification**:

- Bandwidth measurements are consistent
- UDP shows higher throughput than TCP (no congestion control)
- Latency is low (<1ms for virtual network)
- Multiple streams increase total throughput

**Challenge**: Add latency using tc and remeasure. How does 50ms latency affect throughput?

<details>
<summary>Solution</summary>

**Baseline measurements** (no latency):
```bash
docker exec pc1 iperf3 -c 192.168.60.5 -t 10

# Expected results:
# TCP: ~1-10 Gbps (Docker virtual network is fast)
# UDP: ~100 Mbps (with -b 100M limit)
# Latency: ~0.1-0.5 ms
```

**Add latency** (50ms):
```bash
docker exec pc1 /scripts/container/network-problems.sh latency eth0 50ms
```

**Remeasure**:
```bash
# TCP test
docker exec pc1 iperf3 -c 192.168.60.5 -t 10

# Ping test
docker exec pc1 ping -c 20 192.168.60.5
```

**Expected impact**:
- **Ping latency**: Increases to ~50-51ms
- **TCP throughput**: **Significantly reduced** due to:
  - Larger RTT (Round Trip Time)
  - TCP window size limits
  - Slower congestion control response

**Formula**:
```
Max TCP Throughput = Window Size / RTT

With 50ms RTT and default 64KB window:
Max = 65536 bytes / 0.05 sec = ~10 Mbps

This is why high-latency links (satellite, etc.)
need larger TCP windows for good performance!
```

**Cleanup**:
```bash
docker exec pc1 /scripts/container/network-problems.sh reset eth0
docker exec server_web pkill iperf3
```

**Analysis**:
- Latency has major impact on TCP performance
- UDP less affected (no acknowledgments)
- Real-world lesson: Network latency is critical for application performance

</details>

---

## Advanced Exercises

### Exercise 11: Complex Firewall Policy 🔴

**Objective**: Implement a multi-rule firewall policy with logging.

**Scenario**: Configure router2 as a security gateway with:
- LAN 40 (trusted) can access everything
- Transit networks can only access port 80/443
- All access to server_web is logged
- Rate limiting for ICMP
- Stateful connection tracking

**Tasks**:

1. Design the firewall policy
2. Implement the rules in correct order
3. Test each rule
4. Monitor logs

**Steps**:

```bash
# 1. Start fresh
docker exec router2 iptables -F
docker exec router2 iptables -X
docker exec router2 iptables -t nat -F

# 2. Set default policies
docker exec router2 iptables -P INPUT ACCEPT
docker exec router2 iptables -P FORWARD DROP
docker exec router2 iptables -P OUTPUT ACCEPT

# 3. Stateful rules first
docker exec router2 iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# 4. Logging for server_web access
docker exec router2 iptables -A FORWARD -d 192.168.60.5 -j LOG --log-prefix "WEB-ACCESS: " --log-level 4

# 5. Allow LAN 40 (trusted) to everywhere
docker exec router2 iptables -A FORWARD -s 192.168.40.0/28 -j ACCEPT

# 6. Allow transit networks only HTTP/HTTPS
docker exec router2 iptables -A FORWARD -s 192.168.100.0/29 -p tcp -m multiport --dports 80,443 -j ACCEPT
docker exec router2 iptables -A FORWARD -s 192.168.200.0/29 -p tcp -m multiport --dports 80,443 -j ACCEPT

# 7. Rate limit ICMP
docker exec router2 iptables -A FORWARD -p icmp -m limit --limit 10/second --limit-burst 20 -j ACCEPT
docker exec router2 iptables -A FORWARD -p icmp -j DROP

# 8. Drop and log everything else
docker exec router2 iptables -A FORWARD -j LOG --log-prefix "BLOCKED: " --log-level 4
docker exec router2 iptables -A FORWARD -j DROP

# Test cases
# From pc4 (LAN 40 - trusted)
docker exec pc4 ping -c 3 192.168.60.5  # Should work
docker exec pc4 curl http://192.168.60.5  # Should work

# From pc1 (via transit - restricted)
docker exec pc1 curl http://192.168.60.5  # Should work (HTTP)
docker exec pc1 ping -c 3 192.168.60.5  # Should be rate-limited

# View logs
docker exec router2 dmesg | grep "WEB-ACCESS"
docker exec router2 dmesg | grep "BLOCKED"
```

**Verification**:

- LAN 40 has full access
- Transit can only use HTTP/HTTPS
- ICMP is rate-limited
- All access logged

**Challenge**: Add a rule to allow SSH (port 22) only from pc4 to server_web.

<details>
<summary>Solution</summary>

**Complete firewall policy**:

```bash
#!/bin/bash
# Complex Firewall Policy for router2

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F

# Set default policies
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Rule 1: Allow established connections
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Rule 2: Allow loopback
iptables -A FORWARD -i lo -j ACCEPT

# Rule 3: SSH only from pc4 to server_web
iptables -A FORWARD -s 192.168.40.3 -d 192.168.60.5 -p tcp --dport 22 -j ACCEPT

# Rule 4: Log all web server access
iptables -A FORWARD -d 192.168.60.5 -p tcp -m multiport --dports 80,443 -j LOG --log-prefix "WEB: "

# Rule 5: Allow LAN 40 to everywhere
iptables -A FORWARD -s 192.168.40.0/28 -j ACCEPT

# Rule 6: Allow transit networks HTTP/HTTPS only
iptables -A FORWARD -s 192.168.100.0/29 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -A FORWARD -s 192.168.200.0/29 -p tcp -m multiport --dports 80,443 -j ACCEPT

# Rule 7: Rate limit ICMP
iptables -A FORWARD -p icmp -m limit --limit 10/second --limit-burst 20 -j ACCEPT
iptables -A FORWARD -p icmp -j LOG --log-prefix "ICMP-LIMIT: "
iptables -A FORWARD -p icmp -j DROP

# Rule 8: Log and drop everything else
iptables -A FORWARD -j LOG --log-prefix "BLOCKED: " --log-level 4
iptables -A FORWARD -j DROP

echo "Firewall policy applied successfully"
```

**Test script**:
```bash
#!/bin/bash
echo "Testing firewall policy..."

echo -n "1. pc4 → server_web (ping): "
docker exec pc4 ping -c 1 -W 2 192.168.60.5 >/dev/null 2>&1 && echo "PASS" || echo "FAIL"

echo -n "2. pc4 → server_web (HTTP): "
docker exec pc4 curl -s -o /dev/null -w "%{http_code}" http://192.168.60.5 | grep -q 200 && echo "PASS" || echo "FAIL"

echo -n "3. pc1 → server_web (HTTP): "
docker exec pc1 curl -s -o /dev/null -w "%{http_code}" http://192.168.60.5 | grep -q 200 && echo "PASS" || echo "FAIL"

echo -n "4. pc1 → server_web (ping, rate-limited): "
docker exec pc1 ping -c 25 -i 0.05 192.168.60.5 2>&1 | grep -q "packet loss" && echo "PASS" || echo "FAIL"

echo "Firewall logs:"
docker exec router2 dmesg | tail -20
```

**Why this works**:
- Rules processed top-to-bottom
- ESTABLISHED/RELATED first (performance)
- Specific rules (SSH from pc4) before general rules
- Trusted networks (LAN 40) before restricted
- Rate limiting prevents abuse
- Logging provides audit trail
- Default DROP ensures security

</details>

---

### Exercise 12: Load Balancing 🔴

**Objective**: Implement simple load balancing across multiple servers.

**Scenario**: Set up load balancing so requests to router3 are distributed between multiple backend services.

**Tasks**:

1. Start multiple "web servers" (use PCs as mock servers)
2. Configure iptables to balance traffic
3. Test the distribution
4. Measure performance

**Steps**:

```bash
# 1. Set up mock web servers on pc4 and pc5
docker exec pc4 bash -c 'while true; do echo -e "HTTP/1.1 200 OK\r\nContent-Length: 20\r\n\r\nResponse from PC4\n" | nc -l -p 8080 -q 1; done' &
docker exec pc5 bash -c 'while true; do echo -e "HTTP/1.1 200 OK\r\nContent-Length: 20\r\n\r\nResponse from PC5\n" | nc -l -p 8080 -q 1; done' &

# 2. Set up load balancing on router2 using iptables
# This uses statistic module for round-robin

docker exec router2 iptables -t nat -A PREROUTING -p tcp --dport 9000 -m statistic --mode nth --every 2 --packet 0 -j DNAT --to-destination 192.168.40.3:8080

docker exec router2 iptables -t nat -A PREROUTING -p tcp --dport 9000 -j DNAT --to-destination 192.168.40.4:8080

docker exec router2 iptables -t nat -A POSTROUTING -j MASQUERADE

# 3. Test from pc1
for i in {1..10}; do
  docker exec pc1 curl http://192.168.40.2:9000
  sleep 1
done

# 4. Measure distribution
docker exec pc4 netstat -an | grep :8080 | wc -l
docker exec pc5 netstat -an | grep :8080 | wc -l
```

**Verification**:

- Requests alternate between pc4 and pc5
- Distribution is roughly 50/50
- Both servers handle requests successfully

**Challenge**: Implement weighted load balancing (70% to pc4, 30% to pc5).

<details>
<summary>Solution</summary>

**Round-robin load balancing**:

The iptables statistic module can do round-robin or weighted distribution:

```bash
# Round-robin (50/50)
iptables -t nat -A PREROUTING -p tcp --dport 9000 -m statistic --mode random --probability 0.5 -j DNAT --to-destination 192.168.40.3:8080

iptables -t nat -A PREROUTING -p tcp --dport 9000 -j DNAT --to-destination 192.168.40.4:8080
```

**Weighted load balancing (70/30)**:

```bash
# 70% to pc4, 30% to pc5
iptables -t nat -A PREROUTING -p tcp --dport 9000 -m statistic --mode random --probability 0.70 -j DNAT --to-destination 192.168.40.3:8080

iptables -t nat -A PREROUTING -p tcp --dport 9000 -j DNAT --to-destination 192.168.40.4:8080
```

**Test script**:
```bash
#!/bin/bash

# Test load balancing distribution
PC4_COUNT=0
PC5_COUNT=0
TOTAL=100

echo "Testing load balancing with $TOTAL requests..."

for i in $(seq 1 $TOTAL); do
  RESPONSE=$(docker exec pc1 curl -s http://192.168.40.2:9000)

  if echo "$RESPONSE" | grep -q "PC4"; then
    PC4_COUNT=$((PC4_COUNT + 1))
  elif echo "$RESPONSE" | grep -q "PC5"; then
    PC5_COUNT=$((PC5_COUNT + 1))
  fi

  # Progress indicator
  if [ $((i % 10)) -eq 0 ]; then
    echo -n "."
  fi
done

echo ""
echo "Results:"
echo "  PC4: $PC4_COUNT requests ($(($PC4_COUNT * 100 / $TOTAL))%)"
echo "  PC5: $PC5_COUNT requests ($(($PC5_COUNT * 100 / $TOTAL))%)"
```

**Advanced: Health Check**:

Real load balancers check backend health. Here's a simple health check approach:

```bash
#!/bin/bash
# health-check.sh

check_backend() {
  local backend=$1
  local port=$2

  if docker exec pc1 nc -zv -w 2 $backend $port >/dev/null 2>&1; then
    return 0  # Healthy
  else
    return 1  # Unhealthy
  fi
}

# Remove unhealthy backends
if ! check_backend 192.168.40.3 8080; then
  echo "PC4 unhealthy - removing from load balancer"
  docker exec router2 iptables -t nat -D PREROUTING -p tcp --dport 9000 -m statistic --mode random --probability 0.70 -j DNAT --to-destination 192.168.40.3:8080
fi

if ! check_backend 192.168.40.4 8080; then
  echo "PC5 unhealthy - removing from load balancer"
  docker exec router2 iptables -t nat -D PREROUTING -p tcp --dport 9000 -j DNAT --to-destination 192.168.40.4:8080
fi
```

**Cleanup**:
```bash
docker exec router2 iptables -t nat -F
docker exec pc4 pkill nc
docker exec pc5 pkill nc
```

**Note**: Production load balancers (HAProxy, Nginx, etc.) provide much more sophisticated features like:
- Health checks
- Session persistence (sticky sessions)
- SSL termination
- Content-based routing

This exercise demonstrates the basic concept using iptables.

</details>

---

### Exercise 13: Network Troubleshooting Challenge 🔴

**Objective**: Diagnose and fix a broken network configuration.

**Scenario**: Your coworker configured the network but something is wrong. Fix the issues!

**Setup** (run this to break things):

```bash
# This intentionally breaks things - DON'T LOOK AT THE COMMANDS!
docker exec router1 iptables -A FORWARD -s 192.168.20.0/28 -j DROP
docker exec router2 ip route del 192.168.60.0/28
docker exec pc3 ip route del default
docker exec dnsmasq pkill dnsmasq
```

**Symptoms**:

1. pc1 cannot reach server_web
2. pc3 cannot reach anything outside its LAN
3. DNS resolution fails
4. Some connectivity works, some doesn't

**Your Tasks**:

1. Identify all issues
2. Document the root cause of each
3. Fix each problem
4. Verify everything works

**Diagnostic Approach**:

```bash
# Start with connectivity tests
./menu.sh test-connectivity

# Check DNS
./menu.sh test-dns

# Use systematic debugging
./menu.sh troubleshoot
```

**Do NOT look at the solution until you've tried!**

<details>
<summary>Hints</summary>

1. **Issue 1**: Check firewall rules on routers
2. **Issue 2**: Check routing tables on router2
3. **Issue 3**: Check default gateway on pc3
4. **Issue 4**: Check if DNS service is running

Use:
- `iptables -L -v -n` for firewalls
- `ip route` for routing
- `docker ps` for services
- `docker logs dnsmasq` for DNS issues

</details>

<details>
<summary>Solution</summary>

**Diagnosis and Fixes**:

**Issue 1: pc1 cannot reach server_web**

Diagnose:
```bash
docker exec pc1 ping -c 1 192.168.20.2  # Works - gateway reachable
docker exec pc1 ping -c 1 192.168.100.3  # Fails - can't reach router2

# Check firewall
docker exec router1 iptables -L FORWARD -v -n
# Shows: DROP rule for 192.168.20.0/28
```

Fix:
```bash
docker exec router1 iptables -D FORWARD -s 192.168.20.0/28 -j DROP
```

**Issue 2: Traffic reaches router2 but not router3**

Diagnose:
```bash
docker exec pc1 ping -c 1 192.168.100.3  # Now works
docker exec pc1 ping -c 1 192.168.200.3  # Fails

# Check router2 routing
docker exec router2 ip route
# Missing route to 192.168.60.0/28
```

Fix:
```bash
docker exec router2 ip route add 192.168.60.0/28 via 192.168.200.3
```

**Issue 3: pc3 cannot leave its LAN**

Diagnose:
```bash
docker exec pc3 ping -c 1 192.168.30.2  # Works
docker exec pc3 ping -c 1 192.168.20.3  # Fails

# Check routing
docker exec pc3 ip route
# Missing default route
```

Fix:
```bash
docker exec pc3 ip route add default via 192.168.30.2
```

**Issue 4: DNS resolution fails**

Diagnose:
```bash
docker exec pc1 nslookup server_web
# Times out

# Check DNS container
docker ps | grep dnsmasq
docker logs dnsmasq
# dnsmasq process not running
```

Fix:
```bash
# Restart dnsmasq service inside container
docker exec dnsmasq dnsmasq --conf-file=/etc/dnsmasq.conf

# Or restart container
docker restart dnsmasq
```

**Verification**:
```bash
# Run full test suite
./menu.sh test-all

# All tests should now pass
```

**Lessons learned**:
- Systematic debugging: start with layer 3 connectivity
- Check every hop in the path
- Verify both forward and return paths
- Don't assume services are running
- Firewall rules can silently drop traffic

</details>

---

### Exercise 14: Secure Communication Path 🔴

**Objective**: Implement a secure communication channel between two PCs.

**Scenario**: pc1 needs to communicate securely with server_web. Create an encrypted tunnel.

**Tasks**:

1. Set up SSH tunnel from pc1 to server_web
2. Configure port forwarding through the tunnel
3. Verify traffic is encrypted
4. Measure performance impact

**Steps**:

```bash
# 1. Install SSH server on server_web (if not already)
docker exec server_web apt-get update
docker exec server_web apt-get install -y openssh-server

# Start SSH
docker exec server_web service ssh start

# 2. Generate SSH key on pc1 (no password for testing)
docker exec pc1 ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N ""

# 3. Copy key to server_web (for passwordless login)
docker exec pc1 cat /root/.ssh/id_rsa.pub | docker exec -i server_web tee -a /root/.ssh/authorized_keys

# Set permissions
docker exec server_web chmod 600 /root/.ssh/authorized_keys
docker exec server_web chmod 700 /root/.ssh

# 4. Create SSH tunnel with local port forwarding
# Forward local port 8080 to server_web:80 through encrypted tunnel
docker exec -d pc1 ssh -N -L 0.0.0.0:8080:localhost:80 root@192.168.60.5

# 5. Test the tunnel
docker exec pc1 curl http://localhost:8080

# 6. Capture traffic to verify encryption
docker exec router1 tcpdump -i any -n -A 'host 192.168.20.3 and host 192.168.60.5 and port 22'

# 7. Compare with unencrypted HTTP
docker exec router1 tcpdump -i any -n -A 'host 192.168.20.3 and host 192.168.60.5 and port 80'
```

**Verification**:

- SSH tunnel established successfully
- HTTP requests through tunnel work
- tcpdump shows encrypted SSH traffic (unreadable)
- Direct HTTP traffic is plaintext (readable)

**Challenge**: Create a reverse tunnel and measure the latency impact of encryption.

<details>
<summary>Solution</summary>

**Complete secure tunnel setup**:

```bash
#!/bin/bash
# secure-tunnel.sh - Set up encrypted communication

echo "Setting up secure tunnel pc1 → server_web"

# 1. Ensure SSH server running
docker exec server_web bash -c '
  apt-get update -qq
  apt-get install -y openssh-server >/dev/null 2>&1
  mkdir -p /var/run/sshd
  /usr/sbin/sshd
'

# 2. Generate key pair on pc1
docker exec pc1 bash -c '
  mkdir -p /root/.ssh
  ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N "" -q
'

# 3. Install public key on server
PUB_KEY=$(docker exec pc1 cat /root/.ssh/id_rsa.pub)
docker exec server_web bash -c "
  mkdir -p /root/.ssh
  echo '$PUB_KEY' >> /root/.ssh/authorized_keys
  chmod 700 /root/.ssh
  chmod 600 /root/.ssh/authorized_keys
"

# 4. Test SSH connection
echo "Testing SSH connection..."
docker exec pc1 ssh -o StrictHostKeyChecking=no root@192.168.60.5 'echo SSH connection successful'

# 5. Create local port forward tunnel
echo "Creating SSH tunnel (local port 8080 → server_web:80)..."
docker exec -d pc1 ssh -o StrictHostKeyChecking=no -N -L 0.0.0.0:8080:localhost:80 root@192.168.60.5

sleep 2

# 6. Test tunnel
echo "Testing tunnel..."
docker exec pc1 curl -s http://localhost:8080 | head -5

echo "Tunnel established successfully!"
```

**Reverse tunnel** (server can access pc1):

```bash
# On pc1, create reverse tunnel
# Server port 9090 → pc1:80
docker exec -d pc1 ssh -o StrictHostKeyChecking=no -N -R 9090:localhost:80 root@192.168.60.5

# Now from server_web:
docker exec server_web curl http://localhost:9090
# This reaches pc1!
```

**Performance comparison**:

```bash
# Test latency - Direct HTTP
echo "Direct HTTP latency:"
docker exec pc1 bash -c 'for i in {1..10}; do
  time curl -s http://192.168.60.5 >/dev/null
done' 2>&1 | grep real

# Test latency - Through tunnel
echo "Tunneled HTTP latency:"
docker exec pc1 bash -c 'for i in {1..10}; do
  time curl -s http://localhost:8080 >/dev/null
done' 2>&1 | grep real

# Test throughput - Direct
docker exec server_web iperf3 -s -D
docker exec pc1 iperf3 -c 192.168.60.5 -t 10

# Test throughput - Through tunnel (need iperf on pc1)
# More complex - tunneled iperf requires additional setup
```

**Expected results**:
- **Latency increase**: ~5-10% due to encryption/decryption overhead
- **Throughput decrease**: ~10-20% due to SSH processing
- **Security gain**: Traffic completely encrypted, unreadable to sniffers

**Verify encryption**:

```bash
# Terminal 1: Capture traffic
docker exec router1 tcpdump -i any -n -A 'port 22' -w /tmp/ssh-traffic.pcap

# Terminal 2: Send data through tunnel
docker exec pc1 curl http://localhost:8080

# Terminal 3: Capture direct HTTP
docker exec router1 tcpdump -i any -n -A 'port 80' -w /tmp/http-traffic.pcap

# Terminal 2: Send data directly
docker exec pc1 curl http://192.168.60.5

# Compare captures:
docker exec router1 tcpdump -r /tmp/ssh-traffic.pcap -A
# Shows garbled encrypted data

docker exec router1 tcpdump -r /tmp/http-traffic.pcap -A
# Shows clear text "GET / HTTP/1.1"
```

**Cleanup**:
```bash
docker exec pc1 pkill ssh
docker exec server_web pkill sshd
```

**Real-world applications**:
- VPN tunnels
- Secure database connections
- Remote administration
- Bypassing firewalls (not recommended for malicious purposes!)

</details>

---

### Exercise 15: Build Your Own Scenario 🔴

**Objective**: Design and implement a complete network scenario from scratch.

**Your Mission**: Create a reusable, educational scenario that demonstrates a networking concept of your choice.

**Requirements**:

1. Choose a networking concept (NAT, QoS, VPN, IDS, etc.)
2. Write a scenario script following the template
3. Include educational explanations
4. Add safety features (auto-rollback where appropriate)
5. Test thoroughly
6. Document in SCENARIOS.md

**Scenario Ideas**:

- **QoS (Quality of Service)**: Prioritize HTTP traffic over ICMP
- **Simple IDS**: Detect and block port scans
- **Traffic Shaping**: Limit bandwidth per application
- **Multi-WAN**: Simulate two Internet connections with failover
- **VLAN Simulation**: Create logical network segments
- **Packet Filtering**: Advanced layer 7 filtering
- **Connection Tracking**: Monitor and limit concurrent connections

**Template** (use this structure):

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

# Scenario metadata
SCENARIO_NAME="Your Scenario Name"
SCENARIO_OBJECTIVE="What the user will learn"
SCENARIO_DIFFICULTY="Beginner/Intermediate/Advanced"

# Prerequisites check
check_prerequisites() {
    header
    echo -e "${CYAN}  $SCENARIO_NAME${NC}"
    echo -e "${CYAN}  Objective: $SCENARIO_OBJECTIVE${NC}"
    echo -e "${CYAN}  Difficulty: $SCENARIO_DIFFICULTY${NC}"
    header
    echo ""

    # Check containers running
    if ! docker ps | grep -q "pc1"; then
        error "Containers not running. Run './menu.sh start' first."
    fi

    # Add any other prerequisites

    echo "Press Enter to start or Ctrl+C to exit..."
    read
}

# Cleanup function
cleanup() {
    warn "Cleaning up..."
    # Add cleanup commands
    success "Cleanup complete"
}

# Trap cleanup on exit
trap cleanup EXIT

# Scenario steps
step1_introduction() {
    echo ""
    echo -e "${CYAN}═══ Step 1: Introduction ═══${NC}"
    echo ""
    echo "Explanation of what this step does..."
    info "Technical details and learning points"
    echo ""
    read -p "Press Enter to continue..."

    # Your commands here

    success "Step 1 complete"
}

step2_your_step() {
    echo ""
    echo -e "${CYAN}═══ Step 2: Your Step Description ═══${NC}"
    echo ""

    # More steps...

    success "Step 2 complete"
}

step3_verification() {
    echo ""
    echo -e "${CYAN}═══ Step 3: Verification ═══${NC}"
    echo ""

    info "Verifying the configuration..."

    # Verification commands

    success "Verification complete"
}

# Main execution
main() {
    check_prerequisites
    step1_introduction
    step2_your_step
    step3_verification

    echo ""
    header
    success "Scenario completed successfully!"
    header
    echo ""
    info "What you learned:"
    echo "  • Learning point 1"
    echo "  • Learning point 2"
    echo "  • Learning point 3"
    echo ""
    info "Next steps:"
    echo "  • Try exercise X"
    echo "  • Read documentation Y"
    echo ""
}

main "$@"
```

**Deliverables**:

1. Working scenario script in `scenarios/XX-your-scenario.sh`
2. Documentation in `docs/SCENARIOS.md`
3. Test results showing it works
4. Optional: Add to menu.sh

**Evaluation Criteria**:

- ✅ Follows template structure
- ✅ Includes clear explanations
- ✅ Has verification steps
- ✅ Implements safety features
- ✅ Tested and working
- ✅ Well documented

**Example: Simple IDS (Intrusion Detection)**

<details>
<summary>Example Solution</summary>

```bash
#!/bin/bash
set -euo pipefail

# Simple Intrusion Detection System
# Detects and blocks port scans

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

error() { echo -e "${RED}✗ ERROR: $1${NC}" >&2; exit 1; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }
header() { echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"; }

check_prerequisites() {
    header
    echo -e "${CYAN}  Simple Intrusion Detection System${NC}"
    echo -e "${CYAN}  Objective: Detect and block port scans${NC}"
    echo -e "${CYAN}  Difficulty: Advanced${NC}"
    header
    echo ""

    if ! docker ps | grep -q "router1"; then
        error "Containers not running"
    fi

    echo "Press Enter to start..."
    read
}

step1_setup_detection() {
    echo ""
    echo -e "${CYAN}═══ Step 1: Set Up Port Scan Detection ═══${NC}"
    echo ""
    echo "We'll use iptables recent module to detect multiple connection attempts"
    echo ""

    # Detect rapid SYN packets (port scan signature)
    docker exec router1 iptables -A INPUT -p tcp --syn -m recent --name portscan --set

    docker exec router1 iptables -A INPUT -p tcp --syn -m recent --name portscan --update --seconds 60 --hitcount 10 -j LOG --log-prefix "PORT SCAN DETECTED: "

    docker exec router1 iptables -A INPUT -p tcp --syn -m recent --name portscan --update --seconds 60 --hitcount 10 -j DROP

    success "Port scan detection configured"
    info "Any IP making 10+ SYN attempts in 60 seconds will be blocked"
}

step2_demonstrate_scan() {
    echo ""
    echo -e "${CYAN}═══ Step 2: Demonstrate Port Scan ═══${NC}"
    echo ""
    echo "Starting port scan from pc1 to router1..."
    echo ""

    # Normal connection (should work)
    docker exec pc1 nc -zv 192.168.20.2 80 2>&1 | head -1

    sleep 1

    # Port scan (rapid connections)
    info "Scanning ports 1-50 rapidly..."
    for port in {1..50}; do
        docker exec pc1 nc -zv -w 1 192.168.20.2 $port 2>&1 &
    done

    sleep 3

    warn "Port scan completed - IDS should have detected it"
}

step3_verify_blocking() {
    echo ""
    echo -e "${CYAN}═══ Step 3: Verify Blocking ═══${NC}"
    echo ""

    info "Checking IDS logs..."
    docker exec router1 dmesg | grep "PORT SCAN DETECTED" | tail -5

    echo ""
    info "Testing if pc1 is blocked..."

    if docker exec pc1 ping -c 1 -W 2 192.168.20.2 >/dev/null 2>&1; then
        warn "pc1 not blocked - scan may not have triggered threshold"
    else
        success "pc1 is blocked by IDS!"
    fi

    echo ""
    info "Blocked IPs can be unblocked after 60 seconds, or manually:"
    echo "  docker exec router1 iptables -D INPUT -p tcp --syn -m recent --name portscan --update --seconds 60 --hitcount 10 -j DROP"
}

cleanup() {
    warn "Removing IDS rules..."
    docker exec router1 iptables -F INPUT 2>/dev/null || true
    success "Cleanup complete"
}

trap cleanup EXIT

main() {
    check_prerequisites
    step1_setup_detection
    step2_demonstrate_scan
    step3_verify_blocking

    echo ""
    header
    success "IDS Scenario Complete!"
    header
    echo ""
    info "You learned:"
    echo "  • How to detect port scans with iptables"
    echo "  • Using the 'recent' module for rate limiting"
    echo "  • Automatic threat response (blocking)"
    echo "  • IDS logging and monitoring"
    echo ""
}

main "$@"
```

**Save as**: `scenarios/06-simple-ids.sh`

**Add to menu.sh**:
```bash
# In scenarios_menu function:
6) run_scenario "06-simple-ids.sh"; read -p "Press Enter..." ;;
```

**Document in SCENARIOS.md** with full description, objectives, and usage.

</details>

---

## Conclusion

Congratulations! You've completed the exercises. Continue learning by:

1. **Creating your own scenarios** - Best way to solidify understanding
2. **Reading documentation** - [NETWORKING-BASICS.md](NETWORKING-BASICS.md), [SCENARIOS.md](SCENARIOS.md)
3. **Contributing** - Share your scenarios with the community
4. **Experimenting** - Break things and fix them!

## Additional Resources

- [Docker Networking Documentation](https://docs.docker.com/network/)
- [iptables Tutorial](https://www.netfilter.org/documentation/HOWTO/packet-filtering-HOWTO.html)
- [Linux Advanced Routing & Traffic Control HOWTO](https://lartc.org/)
- [TCP/IP Illustrated by W. Richard Stevens](https://www.amazon.com/TCP-Illustrated-Vol-Addison-Wesley-Professional/dp/0201633469)

---

**Happy Learning! 🎓**

For questions or to share your solutions, visit: [GitHub Discussions](https://github.com/manzolo/net-playground/discussions)
