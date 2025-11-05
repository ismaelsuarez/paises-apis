# Solución Completa para los 3 Servicios API

## 🚨 Problema Identificado

Los 3 servicios API están fallando porque:
1. **Puerto 8000 (paises)**: Debe usar siempre `paises.csv` desde `/data`
2. **Puerto 8010 (autos)**: Debe usar `autos.csv` desde `/app/data`
3. **Puerto 8020 (colegios)**: Debe usar `colegios.csv` desde `/app/data`

El problema es que los servicios 8010 y 8020 comparten `/app/data` y si no tienen `CSV_TYPE` en sus `.env`, pueden detectar el CSV incorrecto.

## ✅ Solución Completa

### Paso 1: Verificar y actualizar .env.g2 (para autos - puerto 8010)

```bash
cd ~/paises-apis
nano .env.g2
```

**Agregar esta línea al final:**
```
CSV_TYPE=autos
```

**El archivo completo debe verse así:**
```
TZ=America/Argentina/Mendoza
APP_NAME=Autos API (UTN - Grupo 2)
APP_DESCRIPTION=Dataset normalizado de autos
CSV_TYPE=autos
```

### Paso 2: Verificar y actualizar .env.g3 (para colegios - puerto 8020)

```bash
nano .env.g3
```

**Agregar esta línea al final:**
```
CSV_TYPE=colegios
```

**El archivo completo debe verse así:**
```
TZ=America/Argentina/Mendoza
APP_NAME=Colegios API (UTN - Grupo 3)
APP_DESCRIPTION=Dataset normalizado de colegios
CSV_TYPE=colegios
```

### Paso 3: Verificar que el código del servidor esté actualizado

```bash
# Si usas git
git pull origin main

# O subir manualmente el archivo app/main.py actualizado
```

### Paso 4: Reconstruir TODOS los servicios

```bash
cd ~/paises-apis

# Detener todos los servicios
docker compose stop

# Reconstruir todos los servicios
docker compose build

# Levantar todos los servicios
docker compose up -d

# Verificar que todos estén corriendo
docker compose ps
```

### Paso 5: Verificar que TODOS funcionen correctamente

```bash
# Servicio 8000 (paises)
curl http://localhost:8000/health
curl http://localhost:8000/countries

# Servicio 8010 (autos)
curl http://localhost:8010/health
curl http://localhost:8010/autos

# Servicio 8020 (colegios)
curl http://localhost:8020/health
curl http://localhost:8020/colegios
```

**Ninguno debe dar 404.**

## 🔍 Verificación Detallada

### Verificar variables de entorno en cada contenedor

```bash
# Servicio 8000 (paises)
docker exec paises-apis-1 env | grep CSV_TYPE || echo "No necesita CSV_TYPE (usa /data)"

# Servicio 8010 (autos)
docker exec paises-api-g2 env | grep CSV_TYPE
# Debe mostrar: CSV_TYPE=autos

# Servicio 8020 (colegios)
docker exec paises-api-g3 env | grep CSV_TYPE
# Debe mostrar: CSV_TYPE=colegios
```

### Verificar qué CSV está montado en cada contenedor

```bash
# Servicio 8000 (paises)
docker exec paises-apis-1 ls -la /data/ | grep paises.csv

# Servicio 8010 (autos)
docker exec paises-api-g2 ls -la /app/data/ | grep autos.csv

# Servicio 8020 (colegios)
docker exec paises-api-g3 ls -la /app/data/ | grep colegios.csv
```

### Ver logs de cada servicio

```bash
# Logs del servicio 8000
docker compose logs --tail=20 paises_api

# Logs del servicio 8010
docker compose logs --tail=20 api-g2

# Logs del servicio 8020
docker compose logs --tail=20 api-g3
```

## 🚨 Si Alguno Sigue Fallando

### Forzar rebuild completo de un servicio específico

```bash
# Para autos (8010)
docker compose stop api-g2
docker compose build --no-cache api-g2
docker compose up -d api-g2

# Para colegios (8020)
docker compose stop api-g3
docker compose build --no-cache api-g3
docker compose up -d api-g3

# Para paises (8000) - NO tocar si funciona
# Solo si es necesario:
docker compose stop paises_api
docker compose build --no-cache paises_api
docker compose up -d paises_api
```

## ✅ Checklist Final

Antes de considerar que está todo resuelto:

- [ ] `.env.g2` tiene `CSV_TYPE=autos`
- [ ] `.env.g3` tiene `CSV_TYPE=colegios`
- [ ] El archivo `app/main.py` está actualizado con la nueva lógica
- [ ] Todos los servicios están corriendo: `docker compose ps`
- [ ] Puerto 8000 responde: `curl http://localhost:8000/health`
- [ ] Puerto 8010 responde: `curl http://localhost:8010/health`
- [ ] Puerto 8020 responde: `curl http://localhost:8020/health`
- [ ] Puerto 8000 tiene endpoint `/countries`: `curl http://localhost:8000/countries` (no debe dar 404)
- [ ] Puerto 8010 tiene endpoint `/autos`: `curl http://localhost:8010/autos` (no debe dar 404)
- [ ] Puerto 8020 tiene endpoint `/colegios`: `curl http://localhost:8020/colegios` (no debe dar 404)

## 📝 Notas Importantes

1. **Servicio 8000 (paises)**: No necesita `CSV_TYPE` porque siempre usa `/data` y detecta `paises.csv` automáticamente. NO tocar si funciona.

2. **Servicio 8010 (autos)**: DEBE tener `CSV_TYPE=autos` en `.env.g2` para garantizar que use `autos.csv`.

3. **Servicio 8020 (colegios)**: DEBE tener `CSV_TYPE=colegios` en `.env.g3` para garantizar que use `colegios.csv`.

4. **Orden de reinicio**: Si solo uno falla, puedes reconstruir solo ese servicio. Si varios fallan, reconstruir todos.

5. **Si después del fix un endpoint devuelve `[]`**: Es normal si no hay datos. El problema era el 404, no la ausencia de datos.

