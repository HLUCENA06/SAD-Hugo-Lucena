#!/bin/bash
# Arranque de cada máquina de Bodegas Atlántico según su ROL: fw, tienda, oficina, erp, cliente, enologa o comercial.
set -u
ROL=${ROL:-?}

# Prompt de color con el nombre de la máquina, para no confundirse de terminal
case "$ROL" in
  fw) C=31 ;; tienda) C=33 ;; oficina) C=34 ;; erp) C=36 ;; cliente) C=35 ;; enologa) C=32 ;; comercial) C=32 ;; *) C=37 ;;
esac
grep -q "PS1=" /root/.bashrc || echo "PS1='\[\e[1;${C}m\]${ROL}\[\e[0m\]:\w# '" >> /root/.bashrc

# Servicios simulados: cada puerto contesta quién es y desde qué IP le llega la petición (curl http://IP:PUERTO)
pagina() {
  local nombre=$1; shift
  { echo "server {"; for p in "$@"; do echo "  listen $p;"; done
    printf '  location / { default_type text/plain; return 200 "%s (puerto $server_port) · te llega una peticion desde $remote_addr\\n"; }\n}\n' "$nombre"
  } > /etc/nginx/sites-enabled/lab
  nginx
}

# Lo que se edita vive en /lab (tu carpeta fw/, enologa/ o comercial/): /etc/nftables.conf y /etc/wireguard apuntan ahí
if [ -d /lab ]; then
  [ -f /lab/nftables.conf ] && ln -sf /lab/nftables.conf /etc/nftables.conf
  mkdir -p /lab/wireguard && rm -rf /etc/wireguard && ln -s /lab/wireguard /etc/wireguard
  # Lo que se crea aquí dentro (claves, wg0.conf…) es de root y desde tu ordenador no podrías editarlo:
  # cada 2 s pasa a ser del dueño de la carpeta (tú)
  ( while sleep 2; do find /lab ! -user "$(stat -c %u /lab)" -exec chown -h "$(stat -c %u:%g /lab)" {} + 2>/dev/null; done ) &
fi

case "$ROL" in
  fw)
    # Las interfaces se llaman por la red a la que van: wan, dmz y lan (Docker las crea como eth0, eth1…)
    for i in $(ls /sys/class/net | grep -v -e '^lo$' -e '^wg'); do
      ip=$(ip -4 -o addr show "$i" | awk '{print $4}')
      case "$ip" in 198.51.100.*) n=wan ;; 172.16.20.*) n=dmz ;; 172.16.10.*) n=lan ;; *) continue ;; esac
      ip link set "$i" down && ip link set "$i" name "$n" && ip link set "$n" up
    done
    ip route replace default via 198.51.100.1 dev wan 2>/dev/null
    pagina "SSH del firewall (simulado)" 22
    nft -f /etc/nftables.conf 2>/dev/null || echo "nftables.conf tiene errores: corrígelo y ./lab.sh aplicar"
    [ -s /etc/wireguard/wg0.conf ] && wg-quick up wg0 >/dev/null 2>&1
    ;;
  tienda)  ip route replace default via 172.16.20.254; pagina "Tienda online de la DMZ" 80 443 22 ;;
  oficina) ip route replace default via 172.16.10.254; pagina "PC de la oficina" 80 22 ;;
  erp)     ip route replace default via 172.16.10.254; pagina "ERP de la bodega" 8080 5432 ;;
  # El cliente de Internet sabe llegar a las redes internas a través del firewall: así se puede «intentar entrar»
  cliente) ip route replace 172.16.0.0/16 via 198.51.100.254; pagina "Servidor de Internet" 80 ;;
  enologa|comercial) [ -s /etc/wireguard/wg0.conf ] && wg-quick up wg0 >/dev/null 2>&1 ;;
esac
echo "$ROL listo"
exec sleep infinity
