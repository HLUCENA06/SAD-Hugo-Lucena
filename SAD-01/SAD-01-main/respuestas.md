# Práctica 1 de SAD · SecureCorp — Respuestas

**Nombre y apellidos:**
Hugo Lucena Mariscal

**Usuario: hlucena**

Responde con tus palabras, en 1-3 líneas. En la defensa te preguntaré lo mismo en voz alta.

**Contraseñas que has usado** (solo porque es un laboratorio; en una empresa, jamás en un fichero):

- Tu usuario: 
- hlucena: Hugo2026
- mtorres: Marta2026
---

**1. (A1)** ¿Quién es el `issuer` de tu `ca.crt`? ¿Hasta qué fecha es válido? ¿Por qué el `subject`
y el `issuer` de la CA son iguales y los de `ldap.crt` no?
* El issuer es "ES", y es valido hasta dentro de 3650 dias
* Porque la CA es la autoridad maxima y firma su propio certificado mientras que ldap.crt esta autorizado por la CA


**2. (A3)** Pega el comando y el resultado de tus dos búsquedas:

```
a) miembros de rrhh:
# extended LDIF
#
# LDAPv3
# base <ou=groups,dc=securecorp,dc=local> with scope subtree
# filter: (cn=rrhh)
# requesting: member 
#

# rrhh, groups, securecorp.local
dn: cn=rrhh,ou=groups,dc=securecorp,dc=local
member: uid=lromero,ou=people,dc=securecorp,dc=local
member: uid=mtorres,ou=people,dc=securecorp,dc=local

# search result
search: 2
result: 0 Success

# numResponses: 2
# numEntries: 1


b) cn y mail de todas las personas:
# extended LDIF
#
# LDAPv3
# base <ou=people,dc=securecorp,dc=local> with scope subtree
# filter: (objectClass=inetOrgPerson)
# requesting: cn mail 
#

# lromero, people, securecorp.local
dn: uid=lromero,ou=people,dc=securecorp,dc=local
cn: Lucia Romero
mail: lromero@securecorp.local

# hlucena, people, securecorp.local
dn: uid=hlucena,ou=people,dc=securecorp,dc=local
cn: Hugo
mail: hlucena@securecorp.local

# mtorres, people, securecorp.local
dn: uid=mtorres,ou=people,dc=securecorp,dc=local
cn: Marta
mail: mtorres@securecorp.local

# search result
search: 2
result: 0 Success

# numResponses: 4
# numEntries: 3


```

**3. (A4)** ¿Por qué la clave `ldap.key` tiene que ser de `openldap` y tener permisos 600?


**4. (A4)** ¿Qué valor has puesto en `SLAPD_SERVICES` y por qué?


**5. (A4)** Antes de añadir `TLS_CACERT` en el cliente, `ldaps://` no funcionaba. ¿Por qué?


**6. (B3)** Pega la salida de `klist` con tus dos tickets. ¿Para qué sirve cada uno? ¿Ha viajado tu
contraseña por la red?

```

```

**7. (C)** En el `docker-compose.yml`, ¿qué diferencia hay entre `build:` e `image:`? ¿Qué
significa la línea `- "8081:80"` del servicio `phpldapadmin`?


**8. (C)** ¿Por qué en la máquina `web` no has tenido que escribir a mano `TLS_CACERT`, y en el
cliente sí? ¿Qué pasaría con esa línea del cliente si hicieras `./lab.sh reset`?

