# images/ubuntu-network-playground-router/Dockerfile
FROM ubuntu:24.04

# Installa i pacchetti necessari
RUN apt-get update && \
    apt-get install -y iputils-ping iproute2 tcpdump iptables traceroute iputils-tracepath dnsutils curl wget nano iperf3 && \
    apt-get clean

# Copia lo script di configurazione
COPY ../scripts/router-setup.sh /scripts/router-setup.sh
RUN chmod +x /scripts/router-setup.sh

# Imposta il comando di default
CMD ["/scripts/router-setup.sh"]