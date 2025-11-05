# Guía de Despliegue - 3 APIs en Servidor Linux

Esta guía explica cómo desplegar las 3 APIs en el servidor Linux:
- **Puerto 8000**: API de Países (`paises.csv`)
- **Puerto 8010**: API de Autos (`autos.csv`)
- **Puerto 8020**: API de Colegios (`colegios.csv`)

## 📋 Requisitos Previos

- Acceso SSH al servidor Linux
- Docker y Docker Compose instalados
- Los archivos actualizados localmente en `C:\Users\Ismael\Desktop\api\paises-apis`

## 📤 Paso 1: Subir Archivos al Servidor

### Opción A: Usando Git (Recomendado)
```bash
# En el servidor Linux
cd ~/paises-apis
git pull origin main
```

### Opción B: Usando SCP (Manual)
```bash
# Desde tu máquina Windows (PowerShell o CMD)
# Reemplazar 'usuario' y la IP con tus datos

# Subir el código del servidor
scp C:\Users\Ismael\Desktop\api\paises-apis\app\main.py usuario@149.50.150.15:~/paises-apis/app/main.py

# Subir docker-compose
scp C:\Users\Ismael\Desktop\api\paises-apis\docker-compose.yml usuario@149.50.150.15:~/paises-apis/docker-compose.yml

# Subir archivos .env
scp C:\Users\Ismael\Desktop\api\paises-apis\.env.g2 usuario@149.50.150.15:~/paises-apis/.env.g2
scp C:\Users\Ismael\Desktop\api\paises-apis\.env.g3 usuario@149.50.150.15:~/paises-apis/.env.g3

# Verificar que los CSVs estén en su lugar
# (Estos deberían estar ya en el servidor)
```

## 🔍 Paso 2: Verificar Archivos en el Servidor

Conectarse al servidor y verificar:

```bash
ssh usuario@149.50.150.15
cd ~/paises-apis

# Verificar estructura de carpetas
ls -la datasets/g2/raw.csv
ls -la datasets/g3/raw.csv
ls -la data/paises.csv

# Verificar que los archivos .env existen
cat .env.g2
cat .env.g3

# Verificar docker-compose
cat docker-compose.yml | grep -A 5 "api-g2"
cat docker-compose.yml | grep -A 5 "api-g3"
```

## 🏗️ Paso 3: Etiquetar Imagen Docker Local

Si no lo hiciste antes, etiquetar la imagen del servicio 8000:

```bash
# Etiquetar la imagen actual del servicio 8000
docker tag $(docker ps --filter "publish=8000" --format '{{.Image}}') paises-apis:local

# Verificar que la imagen existe
docker images | grep paises-apis
```

## 🔄 Paso 4: Reconstruir y Reiniciar Servicios

```bash
cd ~/paises-apis

# Detener los servicios existentes (si están corriendo)
docker compose down api-g2 api-g3

# Reconstruir los servicios (esto usa el código actualizado)
docker compose build api-g2 api-g3

# Levantar los servicios
docker compose up -d api-g2 api-g3

# Ver logs para verificar que arrancaron bien
docker compose logs api-g2 --tail=50
docker compose logs api-g3 --tail=50
```

## ✅ Paso 5: Verificar que Funcionan

```bash
# Verificar salud de cada API
curl http://localhost:8000/health
curl http://localhost:8010/health
curl http://localhost:8020/health

# Verificar endpoints de cada API
# Puerto 8000 - Países
curl "http://localhost:8000/countries?q=argentina" | head -20

# Puerto 8010 - Autos
curl "http://localhost:8010/autos?q=toyota" | head -20

# Puerto 8020 - Colegios
curl "http://localhost:8020/colegios?q=cordoba" | head -20

# Verificar documentación
echo "Puerto 8000: http://149.50.150.15:8000/docs"
echo "Puerto 8010: http://149.50.150.15:8010/docs"
echo "Puerto 8020: http://149.50.150.15:8020/docs"
```

## 📊 Resumen de Configuración

| Puerto | CSV | Endpoint Principal | Volumen Montado |
|--------|-----|-------------------|-----------------|
| 8000 | `paises.csv` | `/countries` | `./data:/data` |
| 8010 | `autos.csv` | `/autos` | `./datasets/g2/raw.csv:/app/data/autos.csv` |
| 8020 | `colegios.csv` | `/colegios` | `./datasets/g3/raw.csv:/app/data/colegios.csv` |

## 🔧 Solución de Problemas

### Error: "404 Not Found" en /autos
- Verificar que `main.py` esté actualizado
- Verificar que el contenedor se haya reconstruido: `docker compose build api-g2`
- Ver logs: `docker compose logs api-g2`

### Error: "No such file or directory" al montar CSV
- Verificar que los CSVs existan:
  ```bash
  ls -lh datasets/g2/raw.csv
  ls -lh datasets/g3/raw.csv
  ```

### Error: Contenedor no inicia
- Ver logs detallados: `docker compose logs api-g2`
- Verificar que la imagen existe: `docker images | grep paises-apis`
- Si falta, etiquetar: `docker tag <IMAGE_ID> paises-apis:local`

### Verificar qué CSV está usando cada servicio
```bash
# Dentro del contenedor
docker exec paises-api-g2 ls -la /app/data/
docker exec paises-api-g3 ls -la /app/data/
```

## 🚀 Comandos Útiles

```bash
# Ver estado de todos los servicios
docker compose ps

# Reiniciar un servicio específico
docker compose restart api-g2

# Ver logs en tiempo real
docker compose logs -f api-g2

# Detener todos los servicios
docker compose down

# Levantar todos los servicios
docker compose up -d
```

## 📝 Notas Importantes

1. **El servicio 8000 NO debe modificarse** - Debe seguir funcionando igual que antes
2. **Los CSVs se montan como solo lectura** (excepto `paises.csv` que es R/W)
3. **Cada servicio tiene su propia persistencia JSON** en `./data/g2/` y `./data/g3/`
4. **La detección del tipo de CSV es automática** según el nombre del archivo encontrado
