# Solución Error 404 en /colegios (Puerto 8020)

## 🔍 Problema Identificado

El cliente se conecta correctamente al servidor (health check OK), pero el endpoint `/colegios` devuelve **404 Not Found**.

Esto indica que:
1. ✅ El servidor está corriendo en el puerto 8020
2. ✅ El health check funciona
3. ❌ El endpoint `/colegios` no existe o el servicio no detecta `colegios.csv` correctamente

## 🎯 Causa Raíz

El servicio `api-g3` no está detectando correctamente que debe usar `colegios.csv` porque:
- Busca archivos en orden: `autos.csv` → `colegios.csv` → `paises.csv`
- Si encuentra `autos.csv` primero (por ejemplo, de una prueba anterior), lo usa en lugar de `colegios.csv`
- El código del servidor en Linux puede estar desactualizado

## ✅ Solución Completa (Pasos a Ejecutar en el Servidor Linux)

### Paso 1: Actualizar el código del servidor

```bash
# En el servidor Linux
cd ~/paises-apis

# Si usas git, hacer pull
git pull origin main

# O subir manualmente el archivo app/main.py actualizado
```

### Paso 2: Agregar CSV_TYPE=colegios al .env.g3

```bash
# Editar .env.g3
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

Guardar y salir (Ctrl+X, Y, Enter)

### Paso 3: Verificar que el CSV existe

```bash
# Verificar que el archivo CSV existe
ls -la datasets/g3/raw.csv

# Si no existe, copiarlo desde donde esté
# cp /ruta/al/archivo/Colegios.csv datasets/g3/raw.csv
```

### Paso 4: Reconstruir el servicio api-g3

```bash
cd ~/paises-apis

# Detener el servicio actual
docker compose stop api-g3

# Reconstruir completamente (importante para que tome el código actualizado)
docker compose build api-g3

# Levantar el servicio
docker compose up -d api-g3

# Ver los logs para verificar que detecte colegios.csv correctamente
docker compose logs -f api-g3
```

**En los logs debes ver algo como:**
```
✅ CSV_TYPE=colegios detectado
✅ Cargando colegios.csv desde /app/data/colegios.csv
```

### Paso 5: Verificar que funcione

```bash
# Verificar health check
curl http://localhost:8020/health

# Verificar que detecte colegios correctamente (NO debe dar 404)
curl http://localhost:8020/colegios

# Debe devolver una lista (puede estar vacía [] si no hay datos, pero NO debe dar 404)
```

## 🔍 Diagnóstico Si Sigue Fallando

### 1. Verificar que el CSV está montado correctamente

```bash
# Entrar al contenedor
docker exec -it paises-api-g3 bash

# Ver qué archivos hay en /app/data
ls -la /app/data/

# Debe existir colegios.csv
cat /app/data/colegios.csv | head -5

# Salir del contenedor
exit
```

### 2. Verificar la variable de entorno CSV_TYPE

```bash
# Verificar que la variable de entorno esté en el contenedor
docker exec paises-api-g3 env | grep CSV_TYPE

# Debe mostrar: CSV_TYPE=colegios
```

### 3. Ver los logs del servicio

```bash
# Ver los últimos 50 logs
docker compose logs --tail=50 api-g3

# Buscar mensajes sobre qué CSV detectó
docker compose logs api-g3 | grep -i "csv\|colegios\|autos"
```

### 4. Verificar que el código del servidor esté actualizado

```bash
# Verificar que el código tiene la nueva lógica
docker exec paises-api-g3 cat /app/main.py | grep -A 5 "CSV_TYPE"

# Debe mostrar código que verifica os.getenv("CSV_TYPE")
```

## 🚨 Si el Problema Persiste

### Forzar rebuild completo

```bash
cd ~/paises-apis

# Eliminar el contenedor y volúmenes
docker compose down api-g3

# Reconstruir desde cero
docker compose build --no-cache api-g3

# Levantar
docker compose up -d api-g3
```

## ✅ Checklist Final

Antes de considerar que está resuelto, verifica:

- [ ] El archivo `.env.g3` tiene `CSV_TYPE=colegios`
- [ ] El archivo `app/main.py` está actualizado con la nueva lógica
- [ ] El archivo `datasets/g3/raw.csv` existe
- [ ] El servicio `api-g3` está corriendo: `docker compose ps`
- [ ] El health check funciona: `curl http://localhost:8020/health`
- [ ] El endpoint `/colegios` responde: `curl http://localhost:8020/colegios` (no debe dar 404)
- [ ] Los logs muestran que detectó `colegios.csv` correctamente

## 📝 Notas Importantes

- **NO toques** los servicios `paises_api` (8000) ni `api-g2` (8010), están funcionando correctamente.
- El fix solo afecta al servicio `api-g3` (8020) de colegios.
- Si después del fix el endpoint `/colegios` devuelve una lista vacía `[]`, es normal si no hay datos. El problema estaba en el 404, no en la ausencia de datos.

