# Docker Compose Network Simulation

This project simulates a network using Docker Compose.

![Example](doc/image.png)

## Services

* **dns (dnsmasq):** Provides DNS services.
* **router1, router2, router3:** Simulate routers.
* **pc1, pc2, pc3, pc4, pc5:** Simulate client PCs.
* **server_web:** Simulates a web server.

## Network Topology

* **LANs:**
    * lan\_20: 192.168.20.0/28
    * lan\_30: 192.168.30.0/28
    * lan\_40: 192.168.40.0/28
    * lan\_60: 192.168.60.0/28
* **Transit Networks:**
    * transit\_12: 192.168.100.0/29 (router1 <-> router2)
    * transit\_23: 192.168.200.0/29 (router2 <-> router3)
* **Router Connections:**
    * router1: lan\_20, lan\_30, transit\_12
    * router2: lan\_40, transit\_12, transit\_23
    * router3: lan\_60, transit\_23
* **PC Connections:**
    * pc1, pc2: lan\_20
    * pc3: lan\_30
    * pc4, pc5: lan\_40
    * server\_web: lan\_60

## Usage

1.  Ensure Docker and Docker Compose are installed.
2.  Clone this repository.
3.  Run `docker-compose up --build`.
4.  Access containers: `docker exec -it <container_name> bash`.

## Notes

* For educational purposes.
* Configuration scripts in `scripts/`.
* dns host file in `dnsmasq.hosts`.
* webserver port 80 is exposed.