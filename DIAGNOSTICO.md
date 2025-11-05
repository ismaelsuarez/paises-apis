# Diagnóstico del Problema 404 en /autos

## 🔍 Comandos de Diagnóstico en el Servidor Linux

Ejecuta estos comandos en el servidor para identificar el problema:

### 1. Verificar que el servicio api-g2 está corriendo

```bash
ssh usuario@149.50.150.15
cd ~/paises-apis
docker compose ps
```

Deberías ver `api-g2` con estado `Up`.

### 2. Verificar qué código tiene el contenedor

```bash
# Ver el contenido de main.py dentro del contenedor
docker exec paises-api-g2 cat /app/main.py | grep -A 5 "@app.get.*autos"

# O verificar si existe el endpoint
docker exec paises-api-g2 cat /app/main.py | grep "/autos"
```

Si no aparece nada, el código no está actualizado.

### 3. Verificar qué CSV está montado

```bash
# Ver qué archivos hay en /app/data dentro del contenedor
docker exec paises-api-g2 ls -la /app/data/

# Verificar si autos.csv existe
docker exec paises-api-g2 test -f /app/data/autos.csv && echo "✅ autos.csv existe" || echo "❌ autos.csv NO existe"
```

### 4. Ver los logs del servicio

```bash
# Ver logs completos
docker compose logs api-g2

# Ver las últimas 100 líneas
docker compose logs api-g2 --tail=100

# Ver logs en tiempo real
docker compose logs -f api-g2
```

### 5. Verificar el código actual en el servidor

```bash
# Verificar que el código local está actualizado
cd ~/paises-apis
grep -n "@app.get.*autos" app/main.py
grep -n "CSV_TYPE" app/main.py | head -5
```

### 6. Probar el endpoint directamente desde el servidor

```bash
# Desde dentro del servidor, probar localhost
curl http://localhost:8010/health
curl http://localhost:8010/autos
curl http://localhost:8010/docs
```

### 7. Verificar la imagen Docker que está usando

```bash
# Ver qué imagen está usando el contenedor
docker inspect paises-api-g2 | grep -i image

# Ver cuándo se construyó la imagen
docker images paises-apis:local
```

## 🔧 Soluciones Posibles

### Solución 1: Forzar reconstrucción completa

```bash
cd ~/paises-apis

# Detener y eliminar el contenedor
docker compose stop api-g2
docker compose rm -f api-g2

# Reconstruir SIN caché
docker compose build --no-cache api-g2

# Levantar de nuevo
docker compose up -d api-g2

# Ver logs
docker compose logs -f api-g2
```

### Solución 2: Verificar que el código está correcto

```bash
cd ~/paises-apis/app

# Verificar que el código tiene el endpoint /autos
grep -n "def list_autos" main.py
grep -n "@app.get(\"/autos\"" main.py

# Si no aparece, el código no está actualizado
# Hacer git pull de nuevo
git pull origin main
```

### Solución 3: Verificar el montaje del volumen

```bash
# Ver la configuración del docker-compose
cat docker-compose.yml | grep -A 10 "api-g2"

# Verificar que el CSV existe en el host
ls -lh datasets/g2/raw.csv

# Verificar que se montó correctamente
docker exec paises-api-g2 cat /app/data/autos.csv | head -3
```

### Solución 4: Reiniciar todo desde cero

```bash
cd ~/paises-apis

# Detener todo
docker compose down api-g2 api-g3

# Eliminar la imagen local (opcional, para forzar rebuild)
# docker rmi paises-apis:local

# Reconstruir TODO
docker compose build --no-cache api-g2 api-g3

# Levantar
docker compose up -d api-g2 api-g3

# Verificar
docker compose ps
docker compose logs api-g2 --tail=50
```

## ✅ Verificación Final

Después de aplicar las soluciones:

```bash
# 1. Verificar que el servicio está corriendo
docker compose ps | grep api-g2

# 2. Verificar que el endpoint responde
curl http://localhost:8010/health
curl http://localhost:8010/autos

# 3. Verificar desde fuera del servidor (desde tu PC)
# Desde Windows PowerShell:
curl http://149.50.150.15:8010/health
curl http://149.50.150.15:8010/autos
```

## 📝 Checklist de Problemas Comunes

- [ ] El código `main.py` está actualizado en el servidor
- [ ] El contenedor se reconstruyó después de actualizar el código
- [ ] El CSV `datasets/g2/raw.csv` existe en el servidor
- [ ] El CSV se monta correctamente en `/app/data/autos.csv`
- [ ] El servicio api-g2 está corriendo (estado `Up`)
- [ ] Los puertos 8010 están abiertos en el firewall
- [ ] El endpoint `/autos` existe en el código dentro del contenedor
