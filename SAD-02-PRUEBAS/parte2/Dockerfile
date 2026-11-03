# Laboratorio de clase SAD · UD5 (IDS/IPS y WAF) y UD6 (bastionado)
# Una sola imagen para el firewall, internet, la tienda y el servidor: cada una hace su papel según ROL (ver arranque.sh).
# El WAF es la imagen oficial de OWASP (ModSecurity + Core Rule Set), ver docker-compose.yml.
FROM debian:trixie-slim
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      nftables iproute2 iputils-ping tcpdump curl nmap netcat-openbsd nginx-light procps less nano vim-tiny jq \
      suricata openssh-server openssh-client sshpass fail2ban lynis rsyslog \
    && rm -rf /var/lib/apt/lists/* && rm -f /etc/nginx/sites-enabled/default /etc/fail2ban/jail.d/defaults-debian.conf
# La llave de «admin» (el administrador que trabaja desde fuera): la privada para internet, la pública para el servidor
RUN mkdir -p /etc/lab && ssh-keygen -q -t ed25519 -N "" -C admin@lab -f /etc/lab/admin
COPY arranque.sh /usr/local/bin/arranque.sh
RUN chmod +x /usr/local/bin/arranque.sh
CMD ["/usr/local/bin/arranque.sh"]
