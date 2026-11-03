#!/usr/bin/env bash
#
# lab.sh — Mando a distancia del laboratorio de SAD · UD5 (IDS/IPS y WAF) y UD6 (bastionado).
#
# No necesitas saber Docker: todo lo que hace falta está aquí.
#   ./lab.sh ayuda        -> lista de órdenes
#
set -uo pipefail
cd "$(dirname "$0")"

MAQUINAS="firewall internet tienda waf servidor"
c() { echo "sad-ud56-$1"; }

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

# Una prueba: descripción, máquina y orden. Si la orden sale bien, ✔; si no, ✘ y la pista.
# Las 👀 son ejemplos resueltos: se enseñan, pero no cuentan.
OK=0; MAL=0
prueba() {
    local desc=$1 maq=$2 orden=$3 pista=${4:-}
    if en "$maq" bash -c "$orden" >/dev/null 2>&1; then bien "$desc"; [[ $desc == 👀* ]] || OK=$((OK + 1))
    else echo "${R}✘${X} $desc"; [ -n "$pista" ] && echo "    ${A}pista:${X} $pista"; [[ $desc == 👀* ]] || MAL=$((MAL + 1)); fi
}
# Código HTTP de una petición hecha desde internet
CODIGO="curl -s -o /dev/null -w '%{http_code}' --max-time 5"

ayuda() {
    cat <<EOF
${N}Laboratorio SAD · UD5 (IDS/IPS y WAF) y UD6 (bastionado)${X}

  «Internet» 203.0.113.0/24            DMZ 10.10.20.0/24
  internet .50 (el atacante)           tienda .10 · waf .20 (ModSecurity) · servidor .30
             \\______ firewall .254 (wan · dmz) con Suricata vigilando la wan ______/
  La web de la bodega es http://203.0.113.254 (el firewall la manda al WAF, y el WAF a la tienda)

${N}Arrancar y parar${X}
  ./lab.sh arrancar        crea y arranca las 5 máquinas (la primera vez tarda unos minutos)
  ./lab.sh parar           las apaga (tus ficheros se quedan en esta carpeta)
  ./lab.sh reiniciar       las apaga y las vuelve a crear desde cero (si algo se ha liado)
  ./lab.sh estado          qué máquinas están en marcha

${N}Entrar en una máquina${X} (sales con exit)
  ./lab.sh firewall · internet · tienda · servidor   (y el WAF: ./lab.sh waf entrar)

${N}UD5 · Suricata (IDS/IPS)${X}
  Edita ${N}firewall/suricata/local.rules${X}
  ./lab.sh reglas          comprueba las reglas y las carga (si hay un error, te dice cuál)
  ./lab.sh alertas         las alertas de Suricata (eve.json), una por línea
  ./lab.sh ips · ids       Suricata en medio del tráfico (puede tirarlo) · solo mirando (por defecto)

${N}UD5 · WAF (ModSecurity + OWASP CRS)${X}
  Edita ${N}waf/waf.env${X} (el modo) y ${N}waf/plugins/excepciones-before.conf${X} (las excepciones)
  ./lab.sh waf             aplica los cambios (vuelve a crear el WAF)
  ./lab.sh bloqueos        qué ha detectado o bloqueado el WAF y por qué regla

${N}UD6 · Bastionado del servidor${X}
  Edita ${N}servidor/ssh/${X}, ${N}servidor/nginx/${X}, ${N}servidor/fail2ban/jail.local${X} y ${N}servidor/sysctl.d/${X}
  ./lab.sh ssh · nginx · fail2ban   comprueba la configuración y la aplica
  ./lab.sh lynis           el inspector: auditoría del servidor y su nota (hardening index)
  ✍️ 5 (dentro del servidor): busca cuentas con UID 0 que no sean root y programas con SUID que sobren, y quítalos

${N}Comprobar${X}
  ./lab.sh comprobar ud5 · ud6
EOF
    [ -d solucion ] && echo -e "\n${N}Profesor${X}\n  ./lab.sh solucion ud5|ud6   carga la solución (guarda antes una copia de lo que hubiera en copias/)"
}

arrancar() {
    necesita_docker
    info "Arrancando el laboratorio…"
    docker compose up -d --build >/dev/null 2>&1 || { error "No se pudo arrancar. Prueba:  docker compose up --build  (y mira el error)"; exit 1; }
    sleep 4
    for m in $MAQUINAS; do corriendo "$m" && bien "$m en marcha" || error "$m no arrancó: docker logs $(c "$m")"; done
    echo; echo "Ahora: ${N}./lab.sh ayuda${X} para ver qué hacer."
}

# ---------- UD5 ----------
reglas() {
    necesita_lab
    info "Comprobando firewall/suricata/local.rules…"; local T; T=$(mktemp)
    if ! en firewall suricata -T -c /etc/suricata/suricata.yaml -S /lab/suricata/local.rules -l /tmp -k none >"$T" 2>&1; then
        error "Hay un error en las reglas. No he cargado nada: sigue Suricata con las de antes."
        grep -E "Error|error" "$T" | sed 's/^.*<Error> - //' | head -5; rm -f "$T"; exit 1
    fi
    rm -f "$T"
    local modo; modo=$(en firewall cat /run/suricata.modo 2>/dev/null || echo ids)
    en firewall arranque.sh suricata "$modo"; sleep 3
    en firewall test -s /run/suricata.pid && bien "Reglas cargadas ($(en firewall grep -cE '^(alert|drop|pass|reject)' /lab/suricata/local.rules) reglas, modo ${modo^^}). Míralas trabajar con ./lab.sh alertas"
}
modo_suricata() {
    necesita_lab
    en firewall arranque.sh suricata "$1"; en firewall sh -c "echo $1 > /run/suricata.modo"; sleep 3
    if [ "$1" = ips ]; then bien "Suricata en modo IPS: todo lo que cruza el firewall pasa por él. Las reglas «drop» tiran el paquete."
    else bien "Suricata en modo IDS: mira una copia del tráfico de la wan y solo avisa."; fi
}
alertas() {
    necesita_lab
    en firewall sh -c 'test -s /var/log/suricata/eve.json && jq -r "select(.event_type==\"alert\") | \"\(.timestamp[11:19])  \(.src_ip) → \(.dest_ip):\(.dest_port // \"-\")  \(if .alert.action==\"blocked\" then \"[BLOQUEADO] \" else \"\" end)\(.alert.signature)\"" /var/log/suricata/eve.json | tail -n "$1"' sh "${1:-20}" \
        || aviso "Todavía no hay alertas"
}
waf() {
    necesita_docker
    info "Volviendo a crear el WAF con waf/waf.env y waf/plugins/…"
    docker compose up -d --force-recreate waf >/dev/null 2>&1 || { error "No arranca el WAF:"; docker compose up -d --force-recreate waf; exit 1; }
    sleep 5
    if corriendo waf && en internet curl -s -o /dev/null --max-time 5 http://203.0.113.254/; then
        bien "WAF en marcha en modo $(grep -E '^MODSEC_RULE_ENGINE=' waf/waf.env | cut -d= -f2)"
    else error "El WAF no contesta. Mira el error:  docker logs $(c waf) | tail"; fi
}
bloqueos() {
    necesita_lab
    # El WAF apunta cada petición sospechosa en su registro de auditoría (JSON, por la salida del contenedor).
    # Por petición: hora, qué se pidió, qué contestó (403 = bloqueada) y qué reglas saltaron con la puntuación total.
    local T; T=$(docker logs "$(c waf)" 2>&1 | grep '^{"transaction"' | tail -n "${1:-8}")
    [ -n "$T" ] || { aviso "El WAF no ha detectado nada todavía"; return; }
    echo "$T" | docker exec -i "$(c firewall)" jq -r '.transaction |
        "\(.time_stamp[11:19])  \(.request.method) \(.request.uri)  → \(.response.http_code)\(if .response.http_code == 403 then "  BLOQUEADA" else "" end)",
        (.messages[]? | select(.details.ruleId != "980170") | "    [\(.details.ruleId)] \(.message)")'
}

# ---------- UD6 ----------
ssh_aplicar() {
    necesita_lab
    en servidor sshd -t || { error "Hay un error en servidor/ssh/ (arriba te dice cuál). No he aplicado nada."; exit 1; }
    en servidor sh -c 'kill -HUP $(cat /run/sshd.pid)' && bien "SSH recargado. Lo que vale de verdad:  ./lab.sh servidor  y  sshd -T | grep -i -e root -e password"
}
nginx_aplicar() {
    necesita_lab
    en servidor nginx -t 2>&1 | tail -1
    en servidor nginx -t >/dev/null 2>&1 || { error "No he aplicado nada."; exit 1; }
    en servidor nginx -s reload && bien "Nginx recargado. Míralo desde fuera:  ./lab.sh internet  y  curl -I http://10.10.20.30"
}
# Al activarse, la cárcel lee los fallos de los últimos 10 min (p. ej. los de un ./lab.sh comprobar anterior) y podría
# banear al atacante en el acto: se empieza sin castigos
fail2ban_aplicar() {
    necesita_lab
    en servidor sh -c 'fail2ban-client -t >/dev/null 2>&1' || { error "Hay un error en servidor/fail2ban/jail.local:"; en servidor fail2ban-client -t 2>&1 | tail -3; exit 1; }
    en servidor sh -c 'fail2ban-client ping >/dev/null 2>&1 && fail2ban-client reload >/dev/null || fail2ban-client -x start >/dev/null' \
        && { sleep 1; en servidor fail2ban-client unban --all >/dev/null 2>&1 || true; } \
        && bien "Fail2ban recargado. Cárceles: $(en servidor fail2ban-client status | sed -n 's/.*Jail list:\s*//p')"
}
lynis() {
    necesita_lab
    info "El inspector revisa el servidor (tarda un minuto)…"
    # Auditoría completa (--tests-from-group no admite varios grupos: Lynis lo para «por seguridad»)
    en servidor lynis audit system --quick --no-colors >/dev/null 2>&1 \
        || { error "Lynis no ha terminado. Míralo a mano:  ./lab.sh servidor  y  lynis audit system --quick"; exit 1; }
    en servidor sh -c 'grep -m1 "^hardening_index=" /var/log/lynis-report.dat | cut -d= -f2' | { read -r n; echo "${N}Nota del servidor (hardening index): ${n:-?} / 100${X}"; }
    echo "Avisos (warning): lo más grave"
    en servidor sh -c 'grep "^warning\[\]=" /var/log/lynis-report.dat | cut -d= -f2- | awk -F"|" "{print \"  \" \$1 \" · \" \$2}"' | grep . || echo "  ninguno"
    # De las sugerencias, solo las de lo que se toca en la UD6 (las de paquetes y particiones no vienen a cuento)
    echo "Sugerencias de lo que se toca en la UD6 (SSH, Nginx, núcleo, cuentas):"
    en servidor sh -c 'grep "^suggestion\[\]=" /var/log/lynis-report.dat | cut -d= -f2- | grep -E "^(SSH|HTTP|KRNL-6000|TOOL-5104)"' \
        | sed -E 's/\|-\|/|/g; s/(\|-)?\|?$//; s/\|/ · /; s/\|/ · /; s/ · \|/ · /; s/^/  /' | grep . || echo "  ninguna"
    en servidor sh -c 'echo "(en total: $(grep -c "^suggestion" /var/log/lynis-report.dat) sugerencias; todas en /var/log/lynis-report.dat)"'
}

# ---------- comprobar ----------
# Cuántas alertas con ese sid hay en eve.json
sid() { echo "jq -c 'select(.event_type==\"alert\" and .alert.signature_id==$1)' /var/log/suricata/eve.json 2>/dev/null | wc -l"; }
comprobar_ud5() {
    echo "${N}UD5 · Suricata${X}"
    local p1 p2 p3
    p1=$(en firewall bash -c "$(sid 1000001)"); p2=$(en firewall bash -c "$(sid 1000002)"); p3=$(en firewall bash -c "$(sid 1000003)")
    en internet ping -c 2 -W 1 10.10.20.10 >/dev/null 2>&1
    en internet nmap -sS -Pn -n -p 1-100 --max-retries 0 10.10.20.10 >/dev/null 2>&1
    en internet curl -s -o /dev/null --max-time 5 "http://203.0.113.254/?id=1%20UNION%20SELECT%20user,pass%20FROM%20clientes"
    sleep 3
    prueba "👀 El ping desde Internet salta como alerta (sid 1000001)" firewall "[ \$($(sid 1000001)) -gt $p1 ]" \
        "¿está Suricata en marcha? ./lab.sh reglas"
    prueba "1 · Un escaneo de puertos salta como alerta (sid 1000002)" firewall "[ \$($(sid 1000002)) -gt $p2 ]" \
        "alert tcp \$EXTERNAL_NET any -> \$HOME_NET any (… flags:S; threshold: type threshold, track by_src, count 20, seconds 10; sid:1000002; rev:1;)"
    prueba "2 · «union» en la URL salta como alerta (sid 1000003)" firewall "[ \$($(sid 1000003)) -gt $p3 ]" \
        "alert http … (msg:\"…\"; http.uri; content:\"union\"; nocase; sid:1000003; rev:1;)"
    echo; echo "${N}UD5 · WAF${X}"
    prueba "3 · Una inyección SQL a la tienda recibe un 403 (el WAF bloquea)" internet \
        "[ \$($CODIGO \"http://203.0.113.254/?id=1'%20OR%20'1'='1\") = 403 ]" \
        "en waf/waf.env: MODSEC_RULE_ENGINE=On  y luego ./lab.sh waf (con DetectionOnly solo lo apunta)"
    local bloquea="[ \$($CODIGO \"http://203.0.113.254/?id=1'%20OR%20'1'='1\") = 403 ]"
    prueba "3 · …y una visita normal sigue entrando (200)" internet "$bloquea && [ \$($CODIGO 'http://203.0.113.254/?id=7') = 200 ]" \
        "el WAF no puede bloquearlo todo: ./lab.sh bloqueos y mira qué regla salta"
    local fp="--data-urlencode 'comentario=Me gustó el vino; select from la carta de reservas'"
    prueba "4 · El comentario de un cliente en /contacto ya no se bloquea (falso positivo)" internet \
        "$bloquea && [ \$($CODIGO -X POST $fp http://203.0.113.254/contacto) = 200 ]" \
        "excepción en waf/plugins/excepciones-before.conf y ./lab.sh waf (y el WAF tiene que estar bloqueando: 3)"
    prueba "4 · …pero un ataque en OTRO campo de /contacto sigue bloqueado" internet \
        "[ \$($CODIGO -X POST --data-urlencode \"nombre=1' OR '1'='1\" --data-urlencode 'comentario=hola' http://203.0.113.254/contacto) = 403 ]" \
        "la excepción es SOLO para ARGS:comentario, no para todo el formulario"
    prueba "4 · …y el mismo comentario en otra página también (la excepción es solo para /contacto)" internet \
        "[ \$($CODIGO -X POST $fp http://203.0.113.254/otra) = 403 ]" \
        "SecRule REQUEST_URI \"@beginsWith /contacto\" …: no quites la regla para toda la web"
}
comprobar_ud6() {
    en servidor fail2ban-client unban --all >/dev/null 2>&1 || true   # que un castigo anterior no falsee las pruebas de SSH
    echo "${N}UD6 · SSH${X}"
    prueba "1 · root no entra por SSH" servidor "sshd -T | grep -qx 'permitrootlogin no'" "PermitRootLogin no  en servidor/ssh/bastionado.conf (y ./lab.sh ssh)"
    prueba "1 · Nadie entra con contraseña (solo con llave)" servidor "sshd -T | grep -qx 'passwordauthentication no'" "PasswordAuthentication no"
    prueba "1 · …y de verdad: la contraseña de root ya no sirve desde Internet" internet \
        "! sshpass -p bodega2026 ssh -o ConnectTimeout=5 -o PreferredAuthentications=password root@10.10.20.30 true" \
        "¿has hecho ./lab.sh ssh? ¿el fichero acaba en .conf?"
    prueba "1 · Como mucho 3 intentos por conexión y sin X11" servidor \
        "sshd -T | grep -qx 'maxauthtries 3' && sshd -T | grep -qx 'x11forwarding no'" "MaxAuthTries 3  ·  X11Forwarding no"
    prueba "1 · El administrador sigue entrando con su llave (no te has dejado fuera)" internet \
        "! sshpass -p bodega2026 ssh -o ConnectTimeout=5 -o PreferredAuthentications=password root@10.10.20.30 true && ssh -o ConnectTimeout=5 -o BatchMode=yes admin@10.10.20.30 true" \
        "si cortas también las llaves (PubkeyAuthentication no), nadie podrá administrar el servidor"
    echo; echo "${N}UD6 · Nginx${X}"
    prueba "2 · Nginx no dice su versión" internet "curl -sI --max-time 5 http://10.10.20.30 | grep -i '^server:' | grep -qv '[0-9]'" "server_tokens off;"
    prueba "2 · Manda X-Frame-Options y X-Content-Type-Options" internet \
        "h=\$(curl -sI --max-time 5 http://10.10.20.30); echo \"\$h\" | grep -qi '^x-frame-options' && echo \"\$h\" | grep -qi '^x-content-type-options: nosniff'" \
        "add_header X-Frame-Options \"DENY\" always;  ·  add_header X-Content-Type-Options \"nosniff\" always;"
    prueba "2 · Manda Content-Security-Policy" internet "curl -sI --max-time 5 http://10.10.20.30 | grep -qi '^content-security-policy'" \
        "add_header Content-Security-Policy \"default-src 'self'\" always;"
    echo; echo "${N}UD6 · Núcleo y cuentas${X}"
    prueba "4 · sysctl: ASLR completo, dmesg solo para root y sin redirecciones ICMP" servidor \
        "f=\$(cat /lab/sysctl.d/*.conf 2>/dev/null | tr -d ' '); echo \"\$f\" | grep -qx 'kernel.randomize_va_space=2' && echo \"\$f\" | grep -qx 'kernel.dmesg_restrict=1' && echo \"\$f\" | grep -qx 'net.ipv4.conf.all.accept_redirects=0'" \
        "en servidor/sysctl.d/99-bastionado.conf, una por línea:  clave = valor"
    prueba "5 · Solo root tiene UID 0" servidor "[ \$(awk -F: '\$3==0' /etc/passwd | wc -l) = 1 ]" \
        "awk -F: '\$3==0' /etc/passwd   (¿quién más es «root»?)"
    prueba "5 · No sobra ningún programa con SUID en /usr/local" servidor "[ -z \"\$(find /usr/local -perm -4000 -type f)\" ]" \
        "find / -xdev -perm -4000 -type f 2>/dev/null   (¿cuál no es del sistema?)"
    echo; echo "${N}UD6 · Fail2ban${X}"
    prueba "3 · La cárcel de SSH está activa (3 fallos)" servidor \
        "fail2ban-client status sshd >/dev/null && [ \$(fail2ban-client get sshd maxretry) = 3 ]" \
        "en servidor/fail2ban/jail.local, [sshd]: enabled = true, maxretry = 3 … y ./lab.sh fail2ban"
    # El ataque: 5 usuarios inventados desde Internet. Después se le quita el castigo para que el laboratorio siga funcionando
    en servidor fail2ban-client unban --all >/dev/null 2>&1
    for u in pepe maria test oracle guest; do en internet ssh -o ConnectTimeout=3 -o BatchMode=yes "$u@10.10.20.30" true >/dev/null 2>&1; done
    sleep 3
    prueba "3 · Tras 5 intentos fallidos, la IP del atacante queda baneada" servidor \
        "fail2ban-client status sshd | grep -q 203.0.113.50" "¿logpath = /var/log/auth.log? Mira  tail /var/log/auth.log  y  tail /var/log/fail2ban.log"
    prueba "3 · …y de verdad no puede ni conectar" internet "! nc -z -w 3 10.10.20.30 22" "banaction = nftables-multiport  (en [DEFAULT])"
    en servidor fail2ban-client unban --all >/dev/null 2>&1
}

comprobar() {
    necesita_lab
    OK=0; MAL=0
    case "${1:-todo}" in
        ud5) comprobar_ud5 ;;
        ud6) comprobar_ud6 ;;
        *) comprobar_ud5; echo; comprobar_ud6 ;;
    esac
    echo; [ "$MAL" -eq 0 ] && bien "${N}$OK de $OK. ¡Todo bien!${X}" || echo "${A}$OK de $((OK + MAL)) bien · $MAL por arreglar${X}  (los 👀 no cuentan)"
}

solucion() {
    local ud=${1:-}
    [ -d "solucion/$ud" ] || { error "Uso: ./lab.sh solucion ud5|ud6"; exit 1; }
    necesita_lab
    mkdir -p copias; local f="copias/$(date +%H%M%S)"
    mkdir -p "$f"; cp -r firewall waf servidor "$f"/ 2>/dev/null; aviso "Copia de lo que había en $f/"
    if [ "$ud" = ud5 ]; then
        cp solucion/ud5/local.rules firewall/suricata/local.rules
        cp solucion/ud5/waf.env waf/waf.env
        cp solucion/ud5/plugins/excepciones-before.conf waf/plugins/
        reglas; waf
    else
        cp solucion/ud6/ssh/bastionado.conf servidor/ssh/
        cp solucion/ud6/nginx/seguridad.conf servidor/nginx/
        cp solucion/ud6/fail2ban/jail.local servidor/fail2ban/
        cp solucion/ud6/sysctl.d/99-bastionado.conf servidor/sysctl.d/
        en servidor sh -c "sed -i '/^soporte:/d' /etc/passwd /etc/shadow; rm -f /usr/local/bin/copia-seguridad"
        ssh_aplicar; nginx_aplicar; fail2ban_aplicar
    fi
}

case "${1:-ayuda}" in
    arrancar) arrancar ;;
    parar) necesita_docker; docker compose stop >/dev/null 2>&1 && bien "Laboratorio parado" ;;
    reiniciar) necesita_docker; docker compose down >/dev/null 2>&1; arrancar ;;
    estado) necesita_docker; for m in $MAQUINAS; do corriendo "$m" && bien "$m" || aviso "$m parada"; done ;;
    firewall|internet|tienda|servidor) necesita_lab; docker exec -it "$(c "$1")" bash ;;
    waf) [ "${2:-}" = entrar ] && { necesita_lab; docker exec -it "$(c waf)" sh; } || waf ;;
    reglas) reglas ;;
    alertas) alertas "${2:-20}" ;;
    ips|ids) modo_suricata "$1" ;;
    bloqueos) bloqueos "${2:-15}" ;;
    ssh) ssh_aplicar ;;
    nginx) nginx_aplicar ;;
    fail2ban) fail2ban_aplicar ;;
    lynis) lynis ;;
    comprobar) comprobar "${2:-todo}" ;;
    solucion) solucion "${2:-}" ;;
    ayuda|-h|--help) ayuda ;;
    *) error "No conozco la orden «$1»."; ayuda; exit 1 ;;
esac
