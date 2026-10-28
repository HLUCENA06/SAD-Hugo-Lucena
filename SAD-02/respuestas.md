# Respuestas · Práctica 2 · Bodegas Atlántico

> Rellena este fichero en tu ordenador. Va en la entrega (`./lab.sh entregar`) y en la defensa te pueden preguntar por él.

## Bloque A · Piensa como un atacante (nmap)

**Antes** de lanzar nada, predice qué verá alguien de la calle en la IP de la bodega (open / closed / filtered):

| Puerto | Mi predicción | Por qué |
|---|---|---|
| 22 |  |  |
| 80 |  |  |
| 443 |  |  |
| 5432 |  |  |
| 8080 |  |  |

**Ahora sí:** `./lab.sh cliente` y dentro `nmap -Pn -p 22,80,443,5432,8080 198.51.100.254`. Pega la salida:

```text
(pega aquí la salida de nmap)
```

¿Has acertado todos? Si no, ¿en cuál fallaste y por qué?

>

## Bloque A · El contador

Después de `./lab.sh comprobar`, mira `./lab.sh ver`. ¿Cuántos paquetes lleva el contador de A6? ¿Quién los ha mandado?

>

## Bloque B · La prueba del cifrado

En el firewall (`./lab.sh fw`): `tcpdump -ni wan host 198.51.100.62 -c 6`. Mientras, en otra terminal, el comercial
(`./lab.sh comercial`) hace `curl http://172.16.10.20:8080`. Pega lo que sale en el firewall:

```text
(pega aquí la salida de tcpdump)
```

En dos líneas: ¿qué se ve por la calle y qué NO se ve?

>

## Bloque B · Dos preguntas

1. En el `wg0.conf` del firewall, ¿por qué el `AllowedIPs` del comercial es `10.66.0.3/32` y no `10.66.0.0/24`?

>

2. La enóloga cambia en su `wg0.conf` su dirección a `10.66.0.3` (la del comercial). ¿Consigue entrar al SSH de la
   tienda? ¿Por qué?

>
