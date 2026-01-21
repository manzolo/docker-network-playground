# Networking Basics

This guide explains fundamental networking concepts using examples from the Docker Network Playground.

## Table of Contents

- [IP Addressing and Subnetting](#ip-addressing-and-subnetting)
- [Routing](#routing)
- [DNS Resolution](#dns-resolution)
- [Firewalls and iptables](#firewalls-and-iptables)
- [NAT (Network Address Translation)](#nat-network-address-translation)
- [Common Network Tools](#common-network-tools)
- [Traffic Analysis](#traffic-analysis)
- [Docker Networking](#docker-networking)

---

## IP Addressing and Subnetting

### What is an IP Address?

An IP address is a unique identifier for a device on a network. In this playground, we use IPv4 addresses.

**Example from our topology**:
```
pc1: 192.168.20.3
```

This breaks down as:
- **192.168.20** - Network portion
- **3** - Host portion

### Subnet Masks

A subnet mask determines which part of an IP address is the network and which is the host.

**In this playground**:

```
LAN 20: 192.168.20.0/28
```

The `/28` means the first 28 bits are the network, leaving 4 bits for hosts.

**Calculating usable IPs**:
- /28 subnet = 2^(32-28) = 16 total IPs
- Usable IPs: 16 - 2 (network + broadcast) = 14 hosts

**IP range for 192.168.20.0/28**:
```
Network:    192.168.20.0    (not usable)
First host: 192.168.20.1
...
Last host:  192.168.20.14
Broadcast:  192.168.20.15   (not usable)
```

**In our LANs**:
- .1 reserved for Docker gateway
- .2 typically assigned to router
- .3+ assigned to PCs/services

### Checking Your IP Address

```bash
# Enter a container
./menu.sh enter pc1

# Inside container
ip addr show

# Output:
# eth0: ...
#     inet 192.168.20.3/28 ...
```

### Subnetting Exercise

**Question**: How many usable IPs in a /29 network?
<details>
<summary>Answer</summary>

- /29 = 2^(32-29) = 8 total IPs
- Usable: 8 - 2 = 6 hosts
- Used in our transit networks (transit_12, transit_23)
</details>

---

## Routing

### What is Routing?

Routing is the process of forwarding packets between networks. A router decides the best path for data to reach its destination.

### Default Gateway

The default gateway is the router that handles traffic destined for other networks.

**Example**:
```bash
# On pc1
ip route show

# Output:
default via 192.168.20.2 dev eth0
192.168.20.0/28 dev eth0 scope link
```

This means:
- Traffic to 192.168.20.0/28 stays local
- Everything else goes to 192.168.20.2 (router1)

### Routing Tables

**On router1**:
```bash
docker exec router1 ip route

# Output:
192.168.20.0/28 dev eth0 scope link
192.168.30.0/28 dev eth1 scope link
192.168.40.0/28 via 192.168.100.3 dev eth2
192.168.60.0/28 via 192.168.100.3 dev eth2
192.168.100.0/29 dev eth2 scope link
```

Breaking this down:
- **Directly connected**: 192.168.20.0/28, 192.168.30.0/28, 192.168.100.0/29
- **Via next-hop**: 192.168.40.0/28 and 192.168.60.0/28 through 192.168.100.3 (router2)

### How Routing Works in This Playground

Let's trace pc1 → server_web (192.168.60.5):

1. **pc1** (192.168.20.3):
   - Destination 192.168.60.5 not in local network
   - Send to default gateway: 192.168.20.2 (router1)

2. **router1** (192.168.20.2):
   - Check routing table: 192.168.60.0/28 via 192.168.100.3
   - Forward to 192.168.100.3 (router2) via transit_12

3. **router2** (192.168.100.3):
   - Check routing table: 192.168.60.0/28 via 192.168.200.3
   - Forward to 192.168.200.3 (router3) via transit_23

4. **router3** (192.168.200.3):
   - 192.168.60.0/28 directly connected on eth0
   - Deliver to 192.168.60.5 (server_web)

### Viewing the Path

Use `traceroute` to see the path:

```bash
docker exec pc1 traceroute 192.168.60.5

# Output:
traceroute to 192.168.60.5 (192.168.60.5), 30 hops max
 1  192.168.20.2 (router1)     0.123 ms
 2  192.168.100.3 (router2)    0.234 ms
 3  192.168.200.3 (router3)    0.345 ms
 4  192.168.60.5 (server_web)  0.456 ms
```

### Static vs Dynamic Routing

**Static Routing** (what we use):
- Routes manually configured
- Simple, predictable
- Configured via `ip route add` command
- Set in `docker-compose.yml` ROUTES environment variable

**Dynamic Routing** (not in this playground):
- Routes learned automatically via protocols (OSPF, BGP, etc.)
- More complex, scales better
- Adapts to network changes

---

## DNS Resolution

### What is DNS?

DNS (Domain Name System) translates human-readable names to IP addresses.

**Example**:
```bash
docker exec pc1 nslookup server_web

# Output:
Server:    192.168.20.10
Address:   192.168.20.10#53

Name:   server_web
Address: 192.168.60.5
```

### DNS Server Configuration

In this playground, dnsmasq provides DNS services:

**Configuration file**: `dnsmasq.hosts`
```
192.168.60.5 server_web server_web.lan_60
192.168.20.3 pc1 pc1.lan_20
...
```

### DNS Query Flow

When pc1 queries "server_web":

1. **pc1** looks at `/etc/resolv.conf`:
   ```
   nameserver 192.168.20.10
   ```

2. **Query sent** to 192.168.20.10 (dnsmasq)

3. **dnsmasq** checks:
   - Local hosts file (`/etc/dnsmasq.hosts`)
   - If not found, forwards to upstream DNS (8.8.8.8)

4. **Response** returns IP address to pc1

### DNS Troubleshooting

Check DNS configuration:
```bash
docker exec pc1 cat /etc/resolv.conf
```

Test DNS resolution:
```bash
# Test specific name
docker exec pc1 nslookup server_web

# Test DNS server directly
docker exec pc1 dig @192.168.20.10 server_web

# Test reverse DNS
docker exec pc1 nslookup 192.168.60.5
```

### Multi-homed DNS

Our dnsmasq is "multi-homed" - connected to all LANs:

```
dnsmasq interfaces:
  eth0: 192.168.20.10 (LAN 20)
  eth1: 192.168.30.10 (LAN 30)
  eth2: 192.168.40.10 (LAN 40)
  eth3: 192.168.60.10 (LAN 60)
```

This allows every PC to use its local IP (192.168.X.10) to reach DNS.

---

## Firewalls and iptables

### What is a Firewall?

A firewall controls network traffic based on rules. It can:
- Allow or block specific traffic
- Filter by IP, port, protocol
- Rate limit connections
- Log suspicious activity

### iptables Basics

**iptables** is the Linux firewall system. It uses chains and rules.

**Main chains**:
- **INPUT**: Traffic destined for this host
- **OUTPUT**: Traffic originating from this host
- **FORWARD**: Traffic passing through this host (routing)

### iptables Rules Anatomy

```bash
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
         |  |     |  |    |          |  |
         |  |     |  |    |          |  +-- Action (ACCEPT)
         |  |     |  |    |          +-- Jump to target
         |  |     |  |    +-- Destination port 80
         |  |     |  +-- TCP protocol
         |  |     +-- Protocol specification
         |  +-- Chain (INPUT)
         +-- Append rule
```

### Common iptables Operations

**View current rules**:
```bash
docker exec router1 iptables -L -v -n
```

**Block ICMP from a specific host**:
```bash
docker exec router1 iptables -A INPUT -p icmp -s 192.168.20.3 -j DROP
```

**Rate limit connections**:
```bash
docker exec router1 iptables -A INPUT -p icmp -m limit --limit 5/second -j ACCEPT
docker exec router1 iptables -A INPUT -p icmp -j DROP
```

**Block a specific port**:
```bash
docker exec router1 iptables -A INPUT -p tcp --dport 22 -j DROP
```

**Allow established connections**:
```bash
docker exec router1 iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
```

### Rule Ordering

iptables processes rules in order. First match wins.

**Example**:
```bash
# Rule 1: Accept from 192.168.20.3
iptables -A INPUT -s 192.168.20.3 -j ACCEPT

# Rule 2: Drop from 192.168.20.0/28
iptables -A INPUT -s 192.168.20.0/28 -j DROP
```

Result: 192.168.20.3 is accepted (Rule 1 matches first), others in 192.168.20.0/28 are dropped.

### Policy

Default policy applies when no rules match:

```bash
# Set default policy to DROP (more secure)
iptables -P INPUT DROP

# Now you must explicitly ACCEPT traffic you want
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
```

### Firewall Safety in This Playground

All firewall examples include **auto-rollback**:

```bash
./scripts/container/firewall-examples.sh block-icmp 192.168.20.3
# Rule applied, 60 second timer starts
# If you don't confirm, rule automatically reverts
```

This prevents you from locking yourself out.

---

## NAT (Network Address Translation)

### What is NAT?

NAT modifies IP addresses in packet headers. Common uses:
- Sharing one public IP among many private IPs
- Port forwarding to internal servers
- Hiding internal network structure

### Types of NAT

**1. SNAT (Source NAT / Masquerading)**

Changes source IP of outgoing packets.

**Use case**: Multiple internal hosts sharing one external IP.

```bash
# Enable masquerading on router1
docker exec router1 iptables -t nat -A POSTROUTING -o eth2 -j MASQUERADE
```

**Example flow**:
```
Before NAT:  pc1 (192.168.20.3) → Internet
After NAT:   router1 (public IP) → Internet
             (pc1's IP hidden)
```

**2. DNAT (Destination NAT / Port Forwarding)**

Changes destination IP of incoming packets.

**Use case**: External port 8080 forwards to internal server port 80.

```bash
# Forward port 8080 to server_web:80
docker exec router2 iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 192.168.60.5:80
```

**Example flow**:
```
External request to router2:8080
  → NAT translation
  → server_web:80 (192.168.60.5:80)
```

**3. Full NAT**

Combination of SNAT and DNAT for complete gateway functionality.

### NAT in This Playground

Use the NAT setup script:

```bash
# Enter router
./menu.sh enter router1

# Inside container
/scripts/container/nat-setup.sh help
/scripts/container/nat-setup.sh snat eth2
/scripts/container/nat-setup.sh dnat 8080 192.168.60.5 80
```

### Viewing NAT Rules

```bash
docker exec router1 iptables -t nat -L -v -n
```

---

## Common Network Tools

### ping

Tests connectivity by sending ICMP echo requests.

```bash
docker exec pc1 ping -c 4 192.168.60.5

# Options:
# -c 4      Send 4 packets
# -W 2      Timeout after 2 seconds
# -i 0.2    0.2 second interval between packets
```

### traceroute

Shows the path packets take to reach a destination.

```bash
docker exec pc1 traceroute 192.168.60.5
```

### tcpdump

Captures and analyzes network packets.

```bash
# Capture all traffic on eth0
docker exec router1 tcpdump -i eth0

# Capture only ICMP
docker exec router1 tcpdump -i eth0 icmp

# Capture HTTP traffic
docker exec router1 tcpdump -i eth0 port 80

# Save to file
docker exec router1 tcpdump -i eth0 -w /tmp/capture.pcap

# Read from file
docker exec router1 tcpdump -r /tmp/capture.pcap
```

### nslookup / dig

DNS query tools.

```bash
# Simple lookup
docker exec pc1 nslookup server_web

# Detailed query with dig
docker exec pc1 dig server_web

# Query specific DNS server
docker exec pc1 dig @192.168.20.10 server_web

# Reverse DNS lookup
docker exec pc1 dig -x 192.168.60.5
```

### curl

HTTP client for testing web servers.

```bash
# Simple GET request
docker exec pc1 curl http://server_web

# Show response headers
docker exec pc1 curl -I http://server_web

# Measure response time
docker exec pc1 curl -w "Time: %{time_total}s\n" -o /dev/null -s http://server_web

# Follow redirects
docker exec pc1 curl -L http://server_web
```

### iperf3

Network bandwidth testing.

```bash
# Start server on web server
docker exec server_web iperf3 -s -D

# Run client test from pc1 (10 second test)
docker exec pc1 iperf3 -c 192.168.60.5 -t 10

# UDP test
docker exec pc1 iperf3 -c 192.168.60.5 -u -b 100M

# Reverse direction test
docker exec pc1 iperf3 -c 192.168.60.5 -R
```

### netstat / ss

Display network connections and statistics.

```bash
# Show all listening ports
docker exec server_web netstat -tuln

# Show established connections
docker exec server_web netstat -tun

# Modern alternative: ss
docker exec server_web ss -tuln
```

---

## Traffic Analysis

### Understanding Network Traffic

**Protocol layers**:
1. **Physical**: Cables, signals (not relevant in Docker)
2. **Data Link**: MAC addresses, switching
3. **Network**: IP addresses, routing
4. **Transport**: TCP/UDP, ports
5. **Application**: HTTP, DNS, etc.

### Analyzing Traffic with tcpdump

**Capture HTTP traffic**:
```bash
docker exec router1 tcpdump -i eth0 'tcp port 80' -A
```

**Capture DNS queries**:
```bash
docker exec dnsmasq tcpdump -i eth0 'udp port 53'
```

**Capture traffic between specific hosts**:
```bash
docker exec router1 tcpdump -i eth0 'host 192.168.20.3 and host 192.168.60.5'
```

### Reading tcpdump Output

```
12:34:56.789012 IP 192.168.20.3.54321 > 192.168.60.5.80: Flags [S], seq 123456, length 0
                |  |                 |  |               |      |       |          |
                |  |                 |  |               |      |       |          +-- Payload length
                |  |                 |  |               |      |       +-- TCP sequence number
                |  |                 |  |               |      +-- TCP flags ([S]=SYN, [.]=ACK, [F]=FIN)
                |  |                 |  |               +-- Destination port
                |  |                 |  +-- Destination IP
                |  |                 +-- Source port
                |  +-- Source IP
                +-- Timestamp
```

### Common TCP Flags

- **[S]**: SYN - Connection initiation
- **[.]**: ACK - Acknowledgment
- **[P]**: PSH - Push data
- **[F]**: FIN - Connection termination
- **[R]**: RST - Connection reset

### Three-Way Handshake

Establishing a TCP connection:

```
1. Client → Server: [S] (SYN)
2. Server → Client: [S.] (SYN-ACK)
3. Client → Server: [.] (ACK)
```

**View it in action**:
```bash
# In one terminal, capture traffic
docker exec router1 tcpdump -i eth0 'host 192.168.20.3 and host 192.168.60.5 and tcp'

# In another, make HTTP request
docker exec pc1 curl http://192.168.60.5
```

---

## Docker Networking

### Bridge Networks

Docker uses bridge networks to isolate containers.

**In this playground**:
```bash
docker network ls | grep net-playgound

# Output:
net-playgound_lan_20
net-playgound_lan_30
net-playgound_lan_40
net-playgound_lan_60
net-playgound_transit_12
net-playgound_transit_23
```

### Network Isolation

**Important limitation**: Docker bridge networks are isolated by design.

This means:
- Containers on lan_20 can communicate with each other directly
- Containers on lan_20 and lan_30 (different bridges) cannot communicate directly
- Communication requires routing through connected containers (routers)

### Inspecting Docker Networks

```bash
# View network details
docker network inspect net-playgound_lan_20

# See connected containers
docker network inspect net-playgound_lan_20 --format='{{range $k,$v := .Containers}}{{$v.Name}} {{end}}'
```

### Container Networking

Each container gets:
- Network namespace (isolated network stack)
- Virtual ethernet interface (veth pair)
- IP address from network's subnet
- Default gateway (Docker bridge)

**View from inside container**:
```bash
docker exec pc1 ip addr
docker exec pc1 ip route
docker exec pc1 cat /etc/resolv.conf
```

---

## Practice Exercises

Ready to test your knowledge? See [EXERCISES.md](EXERCISES.md) for hands-on challenges.

**Beginner exercises**:
1. Find the IP address of all containers
2. Trace the route from pc1 to server_web
3. Test DNS resolution for all hostnames

**Intermediate exercises**:
1. Configure a firewall rule to block HTTP traffic
2. Set up port forwarding with DNAT
3. Simulate network latency between routers

**Advanced exercises**:
1. Create a NAT gateway for an entire LAN
2. Implement rate limiting for multiple services
3. Analyze tcpdump output to identify connection issues

---

## Additional Resources

**Books**:
- "TCP/IP Illustrated" by W. Richard Stevens
- "Computer Networks" by Andrew Tanenbaum

**Online**:
- [Cisco Networking Basics](https://www.cisco.com/c/en/us/solutions/small-business/resource-center/networking/networking-basics.html)
- [Linux iptables Tutorial](https://www.netfilter.org/documentation/)
- [Docker Networking Documentation](https://docs.docker.com/network/)

**Practice**:
- Work through all [scenarios](SCENARIOS.md)
- Complete [exercises](EXERCISES.md)
- Create your own network configurations

---

**Next Steps**:
- Try [Scenarios](SCENARIOS.md) to practice these concepts
- Work through [Exercises](EXERCISES.md) for hands-on learning
- See [Troubleshooting](TROUBLESHOOTING.md) when you encounter issues

---

For questions or contributions, visit: [GitHub Repository](https://github.com/manzolo/net-playground)
