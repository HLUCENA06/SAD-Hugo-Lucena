# Laboratorio de la Práctica 2 de SAD · Bodegas Atlántico (cortafuegos nftables + VPN WireGuard)
# Una sola imagen para las siete máquinas: cada una hace su papel según ROL (ver arranque.sh).
FROM debian:trixie-slim
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      nftables iproute2 iputils-ping wireguard-tools tcpdump curl nmap netcat-openbsd nginx-light procps less nano vim-tiny zip \
    && rm -rf /var/lib/apt/lists/* && rm -f /etc/nginx/sites-enabled/default
COPY arranque.sh /usr/local/bin/arranque.sh
RUN chmod +x /usr/local/bin/arranque.sh
CMD ["/usr/local/bin/arranque.sh"]
