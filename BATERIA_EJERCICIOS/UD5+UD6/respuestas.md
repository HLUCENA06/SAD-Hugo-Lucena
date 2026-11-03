# Respuestas · Batería UD5 + UD6

> Esto es para ti: no se entrega ni cuenta. Pero si sabes contestar aquí, en la defensa de la Práctica 2 vas sobrado.

## UD5 · IDS/IPS y WAF

1. Un IDS detecta un ataque. ¿Lo para? ¿Por qué? ¿Qué tendrías que cambiar para que lo cortara?

>

2. En tu regla de la inyección SQL pusiste el destino `any` y no `$HOME_NET`. ¿Por qué? (pista: el DNAT del firewall).

>

3. El WAF está en `DetectionOnly` y llega `?id=1' OR '1'='1`. ¿Qué código recibe el atacante? ¿Dónde queda apuntado?

>

4. El WAF bloquea el comentario de una clienta. ¿Qué nombre tiene ese problema? ¿Cómo lo arreglaste **sin** abrir la
   puerta a toda la web?

>

## UD6 · Bastionado

5. ¿Por qué `PermitRootLogin no`, si root es el administrador? ¿Cómo entra entonces el administrador?

>

6. Explica, con tus palabras y paso a paso, cómo Fail2ban deja fuera a una IP que prueba contraseñas.

>

7. Lynis te daba 58 y ahora da 63. ¿Por qué no llega a 100? ¿Significa que el servidor sigue inseguro?

>
