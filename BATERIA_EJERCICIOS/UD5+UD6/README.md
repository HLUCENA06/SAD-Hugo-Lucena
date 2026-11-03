# Batería UD5 + UD6 · IDS/IPS, WAF y bastionado (opcional)

Un laboratorio para **entrenar** lo de las unidades 5 y 6 antes de la Práctica 2. **No cuenta para la nota** y no se
entrega: es para que practiques con el comprobador delante.

## Antes de empezar

- Necesitas **Docker** (ya lo usaste en las prácticas anteriores). **No instalas nada más.**
- Descomprime este kit y entra en la carpeta: `cd docker-sad-ud56`
- Todo se maneja con **`./lab.sh`**. Empieza por:

```bash
./lab.sh arrancar     # la primera vez tarda unos minutos
./lab.sh ayuda        # todas las órdenes
```

## Qué vas a practicar

| Unidad | Lo que haces | Lo compruebas con |
|---|---|---|
| **UD5** | Reglas de Suricata, el WAF en la puerta y una excepción bien hecha | `./lab.sh comprobar ud5` |
| **UD6** | SSH, Nginx, Fail2ban, el núcleo y las cuentas del servidor | `./lab.sh comprobar ud6` |

Lo que editas vive en tu carpeta: `firewall/suricata/`, `waf/` y `servidor/`. Los ejercicios están marcados con **✍️**
dentro de los ficheros. Si te atascas, la explicación completa está en la web de la asignatura (UD5 y UD6).

> El comprobador te dice qué falta y te da una 💡 pista, **sin darte la solución**. Lánzalo todas las veces que quieras.
> Lo que sale con 👀 son ejemplos ya resueltos: no cuentan, están para que los copies de modelo.
