#!/usr/bin/env bash
#
# lab.sh — Mando a distancia del laboratorio de la Práctica 2 de SAD · Bodegas Atlántico.
#
# No necesitas saber Docker: todo lo que hace falta está aquí.
#   ./lab.sh ayuda        -> lista de órdenes
#
set -uo pipefail
cd "$(dirname "$0")" || exit 1

MAQUINAS="fw tienda oficina erp cliente enologa comercial"
c() { echo "sad-p2-$1"; }

# ---------- colores ----------
if [ -t 1 ]; then
    R=$'\e[1;31m'; V=$'\e[1;32m'; A=$'\e[1;33m'; Z=$'\e[1;34m'; N=$'\e[1m'; X=$'\e[0m'
else
    R=""; V=""; A=""; Z=""; N=""; X=""
fi
info()  { echo "${Z}▶${X} $*"; }
bien()  { echo "${V}✔${X} $*"; }
aviso() { echo "${A}!${X} $*"; }
error() { echo "${R}✘ $*${X}" >&2; }

necesita_docker() {
    if ! command -v docker >/dev/null 2>&1; then error "Docker no está instalado en este equipo."; exit 1; fi
    if ! docker info >/dev/null 2>&1; then
        error "Docker está instalado pero no puedo usarlo."
        echo "  - ¿Está arrancado?           sudo systemctl start docker"
        echo "  - ¿Tu usuario está en el grupo docker?  sudo usermod -aG docker \$USER  (y cierra sesión)"
        exit 1
    fi
}
corriendo() { [ "$(docker inspect -f '{{.State.Running}}' "$(c "$1")" 2>/dev/null)" = "true" ]; }
necesita_lab() {
    necesita_docker
    for m in $MAQUINAS; do
        corriendo "$m" || { error "El laboratorio no está arrancado (falta «$m»)."; echo "  Arráncalo con:  ./lab.sh arrancar"; exit 1; }
    done
}
en() { local m=$1; shift; docker exec "$(c "$m")" "$@"; }
# Lo que se crea dentro de las máquinas (claves, wg0.conf) pasa a ser del dueño de la carpeta, para editarlo desde tu ordenador
# (el arranque de cada máquina ya lo hace cada 2 s; esto es por si acaso, y vale también con sudo ./lab.sh)
tuyo() { for m in fw enologa comercial; do corriendo "$m" && en "$m" sh -c 'chown -R "$(stat -c %u:%g /lab)" /lab' 2>/dev/null; done; }

ayuda() {
    cat <<EOF
${N}Bodegas Atlántico · Práctica 2 de SAD (cortafuegos + VPN)${X}

  la calle 198.51.100.0/24                    DMZ 172.16.20.0/24     LAN 172.16.10.0/24
  cliente .50 · enologa .61 · comercial .62   tienda .10             oficina .5 · erp .20
                \\__________ fw .254 (wan · dmz · lan) + VPN wg0 10.66.0.1 __________/

${N}Arrancar y parar${X}
  ./lab.sh arrancar        crea y arranca las 7 máquinas (la primera vez tarda un par de minutos)
  ./lab.sh parar           las apaga (tus ficheros se quedan en esta carpeta)
  ./lab.sh reiniciar       las apaga y las vuelve a arrancar desde cero (si algo se ha liado)
  ./lab.sh estado          qué máquinas están en marcha

${N}Entrar en una máquina${X} (sales con exit)
  ./lab.sh fw · tienda · oficina · erp · cliente · enologa · comercial

${N}Bloque A · el cortafuegos${X}
  Edita ${N}fw/nftables.conf${X} en tu ordenador
  ./lab.sh aplicar         comprueba la sintaxis y lo carga (si hay un error, no carga nada)
  ./lab.sh ver             las reglas cargadas, con sus contadores

${N}Bloque B · la VPN${X}
  Configuración en ${N}fw/wireguard/${X}, ${N}enologa/wireguard/${X} y ${N}comercial/wireguard/${X}
  ./lab.sh vpn             (re)levanta los túneles y enseña «wg show» del firewall

${N}Comprobar y entregar${X}
  ./lab.sh comprobar       corrige tu práctica (o solo un bloque: ./lab.sh comprobar a · b)
  ./lab.sh entregar        guarda el informe y te dice cómo subirlo a tu repositorio
EOF
    [ -d solucion ] && echo -e "\n${N}Profesor${X}\n  ./lab.sh solucion        carga la solución (guarda antes una copia en copias/)\n  ./lab.sh cargar DIR [AAAA-MM-DD]  carga la carpeta del kit de un alumno (su repo clonado) y la comprueba;\n                           con fecha, lo que tenía subido ese día a las 23:59 (el avance)"
}

arrancar() {
    necesita_docker
    info "Arrancando las 7 máquinas de la bodega…"
    docker compose up -d --build >/dev/null 2>&1 || { error "No he podido arrancar. Mira el error:"; docker compose up -d --build; exit 1; }
    sleep 2; tuyo
    bien "Laboratorio en marcha. Entra en una máquina con  ./lab.sh fw  (o tienda, oficina, erp, cliente, enologa, comercial)"
}

aplicar() {
    necesita_lab
    info "Comprobando la sintaxis de fw/nftables.conf…"
    if ! en fw nft -c -f /etc/nftables.conf; then
        error "Hay un error en nftables.conf (arriba te dice la línea). No he cargado nada: sigue el cortafuegos de antes."
        return 1
    fi
    en fw nft -f /etc/nftables.conf && bien "Cortafuegos cargado. Míralo con ./lab.sh ver"
}

vpn() {
    necesita_lab; tuyo
    for m in fw enologa comercial; do
        if ! en "$m" test -s /etc/wireguard/wg0.conf; then aviso "$m: todavía no hay wireguard/wg0.conf"; continue; fi
        en "$m" bash -c 'wg-quick down wg0 >/dev/null 2>&1; wg-quick up wg0' >/dev/null 2>&1 \
            && bien "túnel levantado en $m" || { error "wg-quick no pudo levantar wg0 en $m:"; en "$m" wg-quick up wg0; }
    done
    echo; info "wg show en el firewall:"; en fw wg show
}

# ---------- comprobar ----------
# Cada prueba tiene un identificador. Las 👀 son los ejemplos resueltos: se enseñan, pero no cuentan.
# Una prueba de «NO llega» solo vale si funciona la que la acompaña (si no, con todo cerrado saldría verde sin hacer nada).
declare -A RES
OK_A=0; TOT_A=0; OK_B=0; TOT_B=0
CURL="curl -s -o /dev/null --max-time 3"
prueba() {
    local id=$1 desc=$2 maq=$3 orden=$4 pista=${5:-} dep=${6:-}
    local bloque=${id:0:1} cuenta=1
    [[ $id == 👀* ]] && cuenta=0
    if [ "$cuenta" = 1 ]; then [ "$bloque" = A ] && TOT_A=$((TOT_A + 1)) || TOT_B=$((TOT_B + 1)); fi
    if [ -n "$dep" ] && [ "${RES[$dep]:-0}" != 1 ]; then
        RES[$id]=0; echo "${R}✘${X} $id · $desc"; echo "    ${A}primero tiene que funcionar $dep${X}"; return
    fi
    if en "$maq" bash -c "$orden" >/dev/null 2>&1; then
        RES[$id]=1; bien "$id · $desc"
        if [ "$cuenta" = 1 ]; then [ "$bloque" = A ] && OK_A=$((OK_A + 1)) || OK_B=$((OK_B + 1)); fi
    else
        RES[$id]=0; echo "${R}✘${X} $id · $desc"; [ -n "$pista" ] && echo "    ${A}💡${X} $pista"
    fi
}
# En el propio ordenador (para respuestas.md)
prueba_local() {
    local id=$1 desc=$2 orden=$3 pista=$4 bloque=${1:0:1}
    [ "$bloque" = A ] && TOT_A=$((TOT_A + 1)) || TOT_B=$((TOT_B + 1))
    if bash -c "$orden" >/dev/null 2>&1; then RES[$id]=1; bien "$id · $desc"; [ "$bloque" = A ] && OK_A=$((OK_A + 1)) || OK_B=$((OK_B + 1))
    else RES[$id]=0; echo "${R}✘${X} $id · $desc"; echo "    ${A}💡${X} $pista"; fi
}
NO="[ \$? -ne 0 ]"   # tras un curl: no ha llegado

comprobar_a() {
    echo "${N}Bloque A · el perímetro${X}"
    prueba "👀 A0" "El vigilante tiene política drop en input y en forward" fw \
        "nft list chain inet bodega input | grep -q 'policy drop' && nft list chain inet bodega forward | grep -q 'policy drop'" \
        "¿has borrado el «policy drop;» de alguna cadena?"
    prueba "👀 A0b" "Las oficinas entran al firewall por SSH" oficina "$CURL http://172.16.10.254:22" \
        "¿has tocado la cadena input?"
    prueba "👀 A0c" "La calle NO entra al firewall por SSH" cliente "$CURL http://198.51.100.254:22; $NO" "" "👀 A0b"
    prueba "A1" "La memoria del vigilante (established,related) está en forward" fw \
        "nft list chain inet bodega forward | grep -q 'ct state established,related accept'" \
        "sin esta línea no vuelve ninguna respuesta: ct state established,related accept"
    prueba "A2" "Las oficinas navegan por la calle" oficina "$CURL http://198.51.100.50" \
        "hacen falta A1, A2 (lan -> wan) y el masquerade de A7"
    prueba "A3" "Las oficinas ven la web de la tienda (80)" oficina "$CURL http://172.16.20.10:80" \
        "A3: oficinas -> tienda, puertos 22, 80 y 443"
    prueba "A3b" "Las oficinas administran la tienda por SSH (22)" oficina "$CURL http://172.16.20.10:22" \
        "A3: ¿has puesto el 22 en la lista de puertos?"
    prueba "A4" "Desde la calle se ve la tienda en la IP de la bodega, puerto 80 (DNAT)" cliente \
        "curl -s --max-time 3 http://198.51.100.254 | grep -q Tienda" \
        "hacen falta las dos cosas: el dnat de A7 (prerouting) y dejarle pasar en forward (A4)"
    prueba "A4b" "…y también por el 443" cliente "curl -s --max-time 3 http://198.51.100.254:443 | grep -q Tienda" \
        "el dnat y la regla de A4 tienen que llevar { 80, 443 }"
    prueba "A4c" "Desde la calle NO se llega al SSH de la tienda" cliente "$CURL http://172.16.20.10:22; $NO" \
        "en A4 solo 80 y 443: ¿has dejado pasar todo de wan a dmz?" A4
    prueba "A5" "La tienda consulta el stock en el ERP (5432)" tienda "$CURL http://172.16.10.20:5432" \
        "A5 tiene que ir ANTES que el drop de A6: la primera que encaja, manda"
    prueba "A5b" "La tienda NO llega a la intranet del ERP (8080)" tienda "$CURL http://172.16.10.20:8080; $NO" \
        "la excepción es SOLO el 5432 y SOLO hacia el ERP" A5
    prueba "A6" "La tienda NO entra en el PC de la oficina" tienda "$CURL http://172.16.10.5; $NO" \
        "dmz -> lan: drop" A5
    prueba "A6b" "El intento se cuenta (counter en la regla dmz -> lan)" fw \
        "nft list chain inet bodega forward | grep -E 'iifname \"dmz\" oifname \"lan\" counter packets [1-9]'" \
        "la regla de A6 necesita la palabra counter antes de drop:  … counter drop" A6
    prueba "A6c" "La tienda NO sale a la calle (si la asaltan, no descarga nada)" tienda "$CURL http://198.51.100.50; $NO" \
        "¿has puesto «oifname \$WAN accept» sin decir de dónde viene? A2 es SOLO para las oficinas (iifname \$LAN)" A4
    prueba "A7" "Fuera ven la IP de la bodega, no la del PC (masquerade)" oficina \
        "curl -s --max-time 3 http://198.51.100.50 | grep -q 'desde 198.51.100.254'" \
        "en la tabla nat, postrouting:  oifname \$WAN masquerade"
    prueba "A8" "Desde la calle NO se llega a las oficinas (SSH del PC)" cliente "$CURL http://172.16.10.5:22; $NO" \
        "de wan a lan no hay ninguna regla: ¿has puesto algún accept sin iifname?" A4
    prueba_local "A9" "respuestas.md tiene la salida de nmap pegada" \
        "grep -q '80/tcp' respuestas.md && grep -qE '(open|filtered)' respuestas.md" \
        "./lab.sh cliente  →  nmap -Pn -p 22,80,443,5432,8080 198.51.100.254  y pega la salida en respuestas.md"
}

comprobar_b() {
    echo "${N}Bloque B · el teletrabajo${X}"
    # Que haya tráfico por los túneles antes de mirar los saludos
    en enologa ping -c 1 -W 2 10.66.0.1 >/dev/null 2>&1; en comercial ping -c 1 -W 2 10.66.0.1 >/dev/null 2>&1
    hs="[ \$(wg show wg0 latest-handshakes | awk '{print \$2}' | sort -n | tail -1) -gt 0 ]"
    prueba "👀 B0" "La enóloga tiene túnel y se ha dado la mano con el firewall" enologa "$hs" \
        "sigue los pasos 👀 del enunciado: claves, los dos wg0.conf y ./lab.sh vpn"
    prueba "👀 B0b" "La enóloga llega a la intranet del ERP (8080)" enologa \
        "curl -s --max-time 3 http://172.16.10.20:8080 | grep -q 'desde 10.66.0.2'" \
        "¿tienes el AllowedIPs de su portátil con la LAN? ¿y la regla 👀 B en forward?"
    prueba "B1" "El comercial tiene túnel (10.66.0.3) y se ha dado la mano con el firewall" comercial \
        "ip -4 addr show wg0 | grep -q 10.66.0.3 && $hs" \
        "en TU fichero, TU llave y el CANDADO DEL OTRO; y en el fw, un [Peer] nuevo con el candado del comercial"
    prueba "B1b" "En el firewall, cada persona entra solo con su IP (/32)" fw \
        "wg show wg0 allowed-ips | grep -q '10.66.0.2/32' && wg show wg0 allowed-ips | grep -q '10.66.0.3/32' && ! wg show wg0 allowed-ips | grep -qE '/(0|8|16|24)\b'" \
        "AllowedIPs del [Peer] en el fw: 10.66.0.3/32 (una sola IP, no la red entera)" B1
    prueba "B2" "El comercial llega a la intranet del ERP (8080)" comercial \
        "curl -s --max-time 3 http://172.16.10.20:8080 | grep -q 'desde 10.66.0.3'" \
        "B2 en forward: iifname \$VPN … ip saddr \$COMERCIAL ip daddr \$ERP tcp dport 8080" B1
    prueba "B3" "El comercial administra la tienda por SSH (22)" comercial "$CURL http://172.16.20.10:22" \
        "B3: wg0 -> dmz, solo el comercial, solo el 22. ¿Su AllowedIPs incluye 172.16.20.0/24?" B1
    prueba "B4" "La enóloga NO llega al SSH de la tienda" enologa "$CURL http://172.16.20.10:22; $NO" \
        "B3 es SOLO para el comercial: ip saddr \$COMERCIAL" B3
    prueba "B5" "Por la VPN nadie llega al PC de la oficina" comercial "$CURL http://172.16.10.5; $NO" \
        "¿has puesto «iifname \$VPN oifname \$LAN accept»? Por la VPN solo lo justo" B2
    prueba "B6" "Por la VPN nadie llega a la base de datos (5432)" enologa "$CURL http://172.16.10.20:5432; $NO" \
        "la enóloga y el comercial, solo el 8080 del ERP" "👀 B0b"
    prueba "B7" "El portátil del comercial solo manda lo de la bodega por el túnel (split tunnel)" comercial \
        "! wg show wg0 allowed-ips | grep -q '0.0.0.0/0'" \
        "AllowedIPs del portátil: las redes de la bodega, no 0.0.0.0/0" B1
    prueba_local "B8" "respuestas.md tiene la captura de tcpdump pegada (UDP 51820)" \
        "grep -q '51820' respuestas.md && grep -qi 'udp' respuestas.md" \
        "./lab.sh fw  →  tcpdump -ni wan host 198.51.100.62 -c 6  (mientras el comercial hace un curl al ERP) y pega la salida"
}

calidad() {
    echo "${N}Calidad${X}"
    # Reglas de forward y de nat sin comment (las de ct state no hace falta comentarlas)
    local reglas; reglas=$(en fw bash -c "nft list chain inet bodega forward; nft list table ip nat" 2>/dev/null \
        | grep -E '(accept|drop|masquerade|dnat to)' | grep -v -e policy -e 'ct state')
    if [ "$OK_A" -gt 0 ] && en fw nft -c -f /etc/nftables.conf >/dev/null 2>&1; then bien "A · fw/nftables.conf es válido (nft -c)"; CAL_A1=1
    else echo "${R}✘${X} A · fw/nftables.conf tiene errores"; CAL_A1=0; fi
    if [ -n "$(echo "$reglas" | grep -v '"wg0"')" ] && ! echo "$reglas" | grep -v '"wg0"' | grep -qv comment; then
        bien "A · Todas tus reglas de forward y de nat dicen para qué son (comment)"; CAL_A2=1
    else echo "${R}✘${X} A · Hay reglas sin comment (o ninguna regla)"; echo "    ${A}💡${X} al final de cada regla:  comment \"A2 · oficinas -> calle\""; CAL_A2=0; fi
    # Cada wg0.conf lleva SU llave y solo la suya: tres llaves distintas, ninguna repetida en otro fichero
    local llaves=""
    for f in fw/wireguard/wg0.conf enologa/wireguard/wg0.conf comercial/wireguard/wg0.conf; do
        [ -f "$f" ] && llaves="$llaves$(sed -n "s/^PrivateKey *= *//p" "$f")"$'\n'
    done
    if [ "$(echo "$llaves" | grep -c .)" = 3 ] && [ "$(echo "$llaves" | grep . | sort -u | wc -l)" = 3 ]; then
        bien "B · Los tres wg0.conf existen y cada uno lleva su propia llave (ninguna repetida)"; CAL_B1=1
    else echo "${R}✘${X} B · Falta algún wg0.conf o hay llaves privadas repetidas o compartidas"; echo "    ${A}💡${X} cada máquina genera su llave; al otro solo se le da el candado (.pub)"; CAL_B1=0; fi
    if [ "$(echo "$reglas" | grep -c '"wg0"')" -ge 3 ] && ! echo "$reglas" | grep '"wg0"' | grep -qv comment; then
        bien "B · Las reglas de la VPN dicen para qué son (comment)"; CAL_B2=1
    else echo "${R}✘${X} B · Faltan reglas de la VPN o alguna no tiene comment"; CAL_B2=0; fi
}

comprobar() {
    necesita_lab; tuyo
    CAL_A1=0; CAL_A2=0; CAL_B1=0; CAL_B2=0
    case "${1:-todo}" in
        a|A) comprobar_a ;;
        b|B) comprobar_b ;;
        *) comprobar_a; echo; comprobar_b; echo; calidad ;;
    esac
    echo
    local fa fb
    [ "$TOT_A" -gt 0 ] && { fa=$(awk "BEGIN{printf \"%.1f\", 7*$OK_A/$TOT_A}"); echo "${N}Bloque A:${X} $OK_A de $TOT_A pruebas  →  funciona $fa de 7"; }
    [ "$TOT_B" -gt 0 ] && { fb=$(awk "BEGIN{printf \"%.1f\", 7*$OK_B/$TOT_B}"); echo "${N}Bloque B:${X} $OK_B de $TOT_B pruebas  →  funciona $fb de 7"; }
    if [ "${1:-todo}" = todo ]; then
        echo "${N}Calidad:${X} A $(awk "BEGIN{printf \"%.1f\", 0.5*$CAL_A1+0.5*$CAL_A2}") de 1 · B $(awk "BEGIN{printf \"%.1f\", 0.5*$CAL_B1+0.5*$CAL_B2}") de 1"
        echo "(el avance, 1,5, y la entrega con ./lab.sh entregar, 0,5, los pone el profesor al ver tu repositorio)"
    fi
    echo "(los 👀 no cuentan: son los ejemplos resueltos)"
}

entregar() {
    necesita_lab; tuyo
    mkdir -p entrega
    info "Comprobando tu práctica para guardar el informe en la entrega…"
    comprobar | sed 's/\x1b\[[0-9;]*m//g' > entrega/informe.txt
    tail -3 entrega/informe.txt
    bien "Informe guardado en ${N}entrega/informe.txt${X}. Ahora súbelo todo a tu repositorio:"
    echo "    git add -A ."
    echo "    git commit -m \"P2 · entrega\""
    echo "    git push"
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || aviso "Esta carpeta no está dentro de tu repositorio: muévela dentro (con fw/, enologa/… tal cual) y repite"
}

# ---------- profesor ----------
solucion() {
    [ -d solucion ] || { error "Esta orden es solo del profesor."; exit 1; }
    necesita_lab
    local f="copias/$(date +%H%M%S)"; mkdir -p "$f"; cp -r fw enologa comercial respuestas.md "$f"/ 2>/dev/null
    aviso "Copia de lo que había en $f/"
    cp solucion/nftables.conf fw/nftables.conf
    cp solucion/respuestas.md respuestas.md
    info "Generando las claves de WireGuard (fw, enóloga y comercial)…"
    declare -A PRIV PUB
    for m in fw enologa comercial; do
        PRIV[$m]=$(en "$m" wg genkey); PUB[$m]=$(echo "${PRIV[$m]}" | docker exec -i "$(c "$m")" wg pubkey)
    done
    sed -e "s|@FW_PRIV@|${PRIV[fw]}|" -e "s|@ENOLOGA_PUB@|${PUB[enologa]}|" -e "s|@COMERCIAL_PUB@|${PUB[comercial]}|" \
        solucion/wg0-fw.conf > fw/wireguard/wg0.conf
    for m in enologa comercial; do
        local M; M=$(echo "$m" | tr a-z A-Z)
        sed -e "s|@${M}_PRIV@|${PRIV[$m]}|" -e "s|@FW_PUB@|${PUB[fw]}|" solucion/wg0-$m.conf > $m/wireguard/wg0.conf
    done
    chmod 600 fw/wireguard/wg0.conf enologa/wireguard/wg0.conf comercial/wireguard/wg0.conf
    aplicar && vpn
}

cargar() {
    local d=${1:-} fecha=${2:-}
    [ -d "$d/fw" ] || { error "Uso: ./lab.sh cargar CARPETA [AAAA-MM-DD]  (la carpeta del kit en el repo del alumno, con fw/ dentro)"; exit 1; }
    if [ -n "$fecha" ]; then
        # El avance: lo último que tenía subido ese día a las 23:59
        local c rel t; c=$(git -C "$d" rev-list -1 --before="$fecha 23:59:59" HEAD) \
            || { error "No es un repositorio git"; exit 1; }
        [ -n "$c" ] || { error "No había nada subido el $fecha"; exit 1; }
        rel=$(git -C "$d" rev-parse --show-prefix); t=$(mktemp -d)
        git -C "$d" archive "$c" -- . | tar -x -C "$t"
        info "Cargando lo subido hasta el $fecha: $(git -C "$d" log -1 --format='%h · %ad · %s' --date=format:'%d/%m %H:%M' "$c")"
        d=$t
    fi
    necesita_lab
    local f="copias/$(date +%H%M%S)"; mkdir -p "$f"; cp -r fw enologa comercial respuestas.md "$f"/ 2>/dev/null
    aviso "Copia de lo que había en $f/"
    # Se vacía y se rellena cada carpeta, sin borrarla: las máquinas la tienen montada
    for x in fw enologa comercial; do
        mkdir -p "$x/wireguard"; find "$x" -mindepth 1 ! -name .gitkeep -delete 2>/dev/null
        [ -d "$d/$x" ] && cp -r "$d/$x/." "$x/"; mkdir -p "$x/wireguard"
    done
    cp "$d/respuestas.md" respuestas.md 2>/dev/null || aviso "La entrega no trae respuestas.md"
    info "Reiniciando con la entrega cargada…"
    docker compose down >/dev/null 2>&1; arrancar; sleep 3; vpn >/dev/null 2>&1
    comprobar
}

case "${1:-ayuda}" in
    arrancar) arrancar ;;
    parar) necesita_docker; tuyo; docker compose stop >/dev/null 2>&1 && bien "Laboratorio parado" ;;
    reiniciar) necesita_docker; docker compose down >/dev/null 2>&1; arrancar ;;
    estado) necesita_docker; for m in $MAQUINAS; do corriendo "$m" && bien "$m" || aviso "$m parada"; done ;;
    fw|tienda|oficina|erp|cliente|enologa|comercial) necesita_lab; docker exec -it "$(c "$1")" bash; tuyo ;;
    aplicar) aplicar ;;
    ver) necesita_lab; en fw nft -a list ruleset ;;
    vpn) vpn ;;
    comprobar) comprobar "${2:-todo}" ;;
    entregar) entregar ;;
    solucion) solucion ;;
    cargar) cargar "${2:-}" "${3:-}" ;;
    ayuda|-h|--help) ayuda ;;
    *) error "No conozco la orden «$1»."; ayuda; exit 1 ;;
esac
