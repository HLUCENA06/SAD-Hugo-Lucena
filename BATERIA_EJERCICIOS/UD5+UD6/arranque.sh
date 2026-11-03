#!/bin/bash
# Arranque de cada máquina del laboratorio según su ROL: firewall, internet, tienda o servidor (el WAF es la imagen de OWASP).
# En el firewall también: arranque.sh suricata ids|ips  (lo usa ./lab.sh para arrancar Suricata en un modo u otro)
set -u
ROL=${ROL:-?}

# Suricata: IDS = mira una copia del tráfico de la wan (af-packet) y avisa · IPS = el tráfico pasa POR él (NFQUEUE) y puede tirarlo
suricata_modo() {
  pkill -x Suricata-Main 2>/dev/null; pkill -x suricata 2>/dev/null
  # Esperar a que el anterior suelte la tarjeta: si no, el nuevo muere con «cluster-id 1 already in use»
  for _ in $(seq 20); do pgrep -f '^suricata ' >/dev/null || break; sleep 0.5; done
  pkill -9 -f '^suricata ' 2>/dev/null; sleep 0.5
  nft delete table inet ips 2>/dev/null
  rm -f /run/suricata.pid
  mkdir -p /var/log/suricata
  # -k none: no mirar las sumas de comprobación (en Docker las calcula la tarjeta «de mentira» y saldrían mal)
  local op=(-c /etc/suricata/suricata.yaml -S /lab/suricata/local.rules -l /var/log/suricata -k none -D --pidfile /run/suricata.pid)
  if [ "$1" = ips ]; then
    # Todo lo que cruza el firewall pasa por la cola 0, donde espera Suricata (bypass: si Suricata no está, pasa igual)
    nft -f - <<'EOF'
table inet ips {
  chain forward {
    type filter hook forward priority -10;
    queue num 0 bypass
  }
}
EOF
    suricata "${op[@]}" -q 0 >/dev/null 2>&1
  else
    suricata "${op[@]}" --af-packet=wan >/dev/null 2>&1
  fi
}
if [ "${1:-}" = suricata ]; then suricata_modo "${2:-ids}"; exit; fi

# Prompt de color con el nombre de la máquina, para no confundirse de terminal
case "$ROL" in
  firewall) C=31 ;; internet) C=35 ;; tienda) C=33 ;; servidor) C=36 ;; *) C=37 ;;
esac
grep -q "PS1=" /root/.bashrc || echo "PS1='\[\e[1;${C}m\]${ROL}\[\e[0m\]:\w# '" >> /root/.bashrc

# Lo que se crea aquí dentro (registros, copias…) es de root y desde tu ordenador no podrías editarlo:
# cada 2 s pasa a ser del dueño de la carpeta (tú)
[ -d /lab ] && ( while sleep 2; do find /lab ! -user "$(stat -c %u /lab)" -exec chown -h "$(stat -c %u:%g /lab)" {} + 2>/dev/null; done ) &

case "$ROL" in
  firewall)
    # Las interfaces se llaman por la red a la que van: wan y dmz (Docker las crea como eth0, eth1…)
    for i in $(ls /sys/class/net | grep -v '^lo$'); do
      ip=$(ip -4 -o addr show "$i" | awk '{print $4}')
      case "$ip" in 203.0.113.*) n=wan ;; 10.10.20.*) n=dmz ;; *) continue ;; esac
      ip link set "$i" down && ip link set "$i" name "$n" && ip link set "$n" up
    done
    ip route replace default via 203.0.113.1 dev wan 2>/dev/null
    # El cortafuegos ya está hecho (UD3): todo pasa, y la web de la bodega (la IP pública, puerto 80) es el WAF.
    # El WAF no sabe volver a Internet: le llega todo con la IP del firewall (masquerade solo hacia él).
    # (La tabla no se llama «nat»: esa ya la usa Docker para su DNS)
    nft -f - <<'EOF'
table ip bodega {
  chain prerouting {
    type nat hook prerouting priority dstnat;
    iifname "wan" ip daddr 203.0.113.254 tcp dport 80 dnat to 10.10.20.20:8080
  }
  chain postrouting {
    type nat hook postrouting priority srcnat;
    oifname "dmz" ip daddr 10.10.20.20 masquerade
  }
}
EOF
    suricata_modo ids
    ;;
  internet)
    # El atacante (y el administrador que trabaja desde fuera, con su llave de admin)
    ip route replace 10.10.20.0/24 via 203.0.113.254
    mkdir -p /root/.ssh && cp /etc/lab/admin /root/.ssh/id_ed25519 && chmod 600 /root/.ssh/id_ed25519
    printf 'Host *\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n' > /root/.ssh/config
    ;;
  tienda)
    ip route replace default via 10.10.20.254
    cat > /etc/nginx/sites-enabled/tienda <<'EOF'
server {
  listen 80 default_server;
  default_type text/plain;
  location /contacto { return 200 "Bodega Atlantico · gracias por tu comentario\n"; }
  location / { return 200 "Bodega Atlantico · tienda online · producto $arg_id\n"; }
}
EOF
    nginx
    ;;
  servidor)
    ip route replace default via 10.10.20.254
    # Un servidor «recién instalado y descuidado» (solo la primera vez: lo que arregles dentro no vuelve al reiniciar,
    # salvo con ./lab.sh reiniciar, que lo crea de nuevo)
    if [ ! -e /etc/lab/sembrado ]; then
      echo "root:bodega2026" | chpasswd
      useradd -m -s /bin/bash admin && echo "admin:Admin1234" | chpasswd
      mkdir -p /home/admin/.ssh && cp /etc/lab/admin.pub /home/admin/.ssh/authorized_keys
      chown -R admin:admin /home/admin/.ssh && chmod 700 /home/admin/.ssh && chmod 600 /home/admin/.ssh/authorized_keys
      useradd -o -u 0 -g 0 -M -d /root -s /bin/bash soporte && echo "soporte:soporte" | chpasswd   # una «puerta trasera»
      cp /bin/bash /usr/local/bin/copia-seguridad && chmod u+s /usr/local/bin/copia-seguridad       # un SUID de más
      printf '\n# Lo que dejó el instalador\nPermitRootLogin yes\nPasswordAuthentication yes\nX11Forwarding yes\nMaxAuthTries 6\n' >> /etc/ssh/sshd_config
      sed -i 's/^\s*server_tokens off;.*/\t# server_tokens off;/' /etc/nginx/nginx.conf                  # dice su versión
      echo '<h1>Servidor de la bodega</h1>' > /var/www/html/index.html
      touch /etc/lab/sembrado
    fi
    # Lo que se edita vive en /lab (tu carpeta servidor/): SSH, Nginx y Fail2ban leen de ahí
    mkdir -p /lab/ssh /lab/nginx /lab/fail2ban /lab/sysctl.d
    rm -rf /etc/ssh/sshd_config.d /etc/nginx/conf.d && ln -s /lab/ssh /etc/ssh/sshd_config.d && ln -s /lab/nginx /etc/nginx/conf.d
    ln -sf /lab/fail2ban/jail.local /etc/fail2ban/jail.local
    printf 'server { listen 80 default_server; root /var/www/html; }\n' > /etc/nginx/sites-enabled/servidor
    # El registro del sistema (rsyslog): los intentos de SSH quedan en /var/log/auth.log, que es lo que lee Fail2ban
    sed -i '/imklog/s/^/#/' /etc/rsyslog.conf; rm -f /run/rsyslogd.pid; rsyslogd
    mkdir -p /run/sshd && ssh-keygen -A >/dev/null 2>&1
    /usr/sbin/sshd || echo "La configuración de SSH tiene errores: sshd -t"
    nginx || echo "La configuración de Nginx tiene errores: nginx -t"
    fail2ban-client -x start >/dev/null 2>&1 || echo "Fail2ban no arranca: fail2ban-client -d"
    ;;
esac
echo "$ROL listo"
exec sleep infinity
