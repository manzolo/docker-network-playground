# images/ubuntu-network-playground-webserver/Dockerfile
FROM nginx:1.27

# Installa i pacchetti necessari
RUN apt-get update && \
    apt-get install -y iproute2 iputils-ping net-tools && \
    apt-get clean

# Copia lo script di configurazione
COPY ../scripts/web-setup.sh /scripts/web-setup.sh
RUN chmod +x /scripts/web-setup.sh

# Copia i file HTML personalizzati
#COPY ../html /usr/share/nginx/html

# Imposta il comando di default
CMD ["/scripts/web-setup.sh"]