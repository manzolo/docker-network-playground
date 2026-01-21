# images/ubuntu-network-playground-pc/Dockerfile
FROM ubuntu:24.04

# Installa i pacchetti necessari
RUN apt-get update && \
    apt-get install -y iputils-ping iproute2 tcpdump wget curl traceroute iputils-tracepath dnsutils nano iperf3 && \
    apt-get clean

# Copia lo script di configurazione
COPY ../scripts/pc-setup.sh /scripts/pc-setup.sh
RUN chmod +x /scripts/pc-setup.sh

# Imposta il comando di default
CMD ["/scripts/pc-setup.sh"]