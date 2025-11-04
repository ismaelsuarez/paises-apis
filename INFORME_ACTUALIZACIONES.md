# Informe de Actualizaciones - Paises APIs

**Fecha:** Enero 2025  
**Repositorio:** https://github.com/ismaelsuarez/paises-apis  
**Objetivo:** Agregar dos nuevas APIs (puertos 8010 y 8020) sin modificar el servicio existente en puerto 8000

---

## 📋 Resumen Ejecutivo

Se ha implementado una solución que permite ejecutar tres instancias independientes de la API FastAPI:
- **Puerto 8000**: Servicio original (países) - **SIN CAMBIOS FUNCIONALES**
- **Puerto 8010**: Nueva API para dataset de Autos (Grupo 2)
- **Puerto 8020**: Nueva API para dataset de Colegios (Grupo 3)

Cada servicio mantiene su propia persistencia y puede tener un título personalizado mediante variables de entorno.

---

## 🏗️ Estructura del Proyecto

```
paises-apis/
├── app/
│   ├── Dockerfile              # Imagen base de la API
│   ├── main.py                 # Código FastAPI (actualizado con APP_NAME)
│   ├── requirements.txt        # Dependencias Python
│   └── docker-compose.yml      # (opcional, existe también en raíz)
│
├── scripts/
│   └── normalize_csv.py        # Script de normalización de CSV
│
├── datasets/
│   ├── g2/                     # Dataset Grupo 2 (AUTOS)
│   │   ├── raw.csv             # CSV original (autos.csv)
│   │   ├── columns.map.json    # Mapeo de columnas → esquema canónico
│   │   └── paises.csv          # CSV normalizado (generado automáticamente)
│   │
│   └── g3/                     # Dataset Grupo 3 (COLEGIOS)
│       ├── raw.csv             # CSV original (Colegios.csv)
│       ├── columns.map.json    # Mapeo de columnas → esquema canónico
│       └── paises.csv          # CSV normalizado (generado automáticamente)
│
├── data/                       # Persistencia servicio 8000 (original)
│   └── paises.csv              # CSV original de países
│
├── data/                       # Persistencia en runtime
│   ├── g2/                     # Persistencia JSON para API 8010
│   └── g3/                     # Persistencia JSON para API 8020
│
├── docker-compose.yml          # Configuración de todos los servicios
├── .env.g2                     # Variables de entorno API 8010
├── .env.g3                     # Variables de entorno API 8020
└── README.md
```

---

## 🔧 Cambios Implementados

### 1. Script de Normalización (`scripts/normalize_csv.py`)

**Propósito:** Convertir CSVs con diferentes estructuras al esquema canónico esperado por la API.

**Características:**
- Idempotente y robusto
- Maneja tildes, espacios y columnas faltantes
- Autodetecta el dialecto del CSV
- Normaliza encabezados automáticamente
- Convierte valores numéricos correctamente

**Esquema Canónico:**
```python
["nombre", "continente", "capital", "poblacion", "superficie", "codigo"]
```

**Uso:**
```bash
python normalize_csv.py <input.csv> <columns.map.json> <output.csv>
```

### 2. Archivos de Mapeo de Columnas

#### `datasets/g2/columns.map.json` (AUTOS)
```json
{
  "nombre":     ["Modelo"],
  "continente": ["TipoCombustible"],
  "capital":    ["Transmisión"],
  "poblacion":  ["Año"],
  "superficie": [],
  "codigo":     ["Marca"]
}
```

#### `datasets/g3/columns.map.json` (COLEGIOS)
```json
{
  "nombre":     ["Colegio"],
  "continente": ["Provincia"],
  "capital":    [],
  "poblacion":  ["Cantidad de Estudiantes"],
  "superficie": [],
  "codigo":     ["Provincia"]
}
```

### 3. Actualización de `app/main.py`

**Cambios realizados:**
- ✅ Agregado soporte para `APP_NAME` y `APP_DESCRIPTION` desde variables de entorno
- ✅ Mantiene valores por defecto originales (`"Paises API"`) para compatibilidad
- ✅ Mejorado `_load()` con manejo tolerante de columnas opcionales
- ✅ Compatible con esquema canónico y formato original

**Código agregado:**
```python
import os

APP_NAME = os.getenv("APP_NAME", "Paises API")
APP_DESCRIPTION = os.getenv("APP_DESCRIPTION", "API de países (UTN).")

app = FastAPI(title=APP_NAME, description=APP_DESCRIPTION, version="1.0.0")
```

### 4. Docker Compose (`docker-compose.yml`)

**Servicios configurados:**

#### Servicio Original (puerto 8000) - **SIN CAMBIOS**
```yaml
paises_api:
  build: ./app
  ports:
    - "8000:8000"
  volumes:
    - ./data:/data:rw
  restart: unless-stopped
```

#### Nuevos Servicios:

**Preprocesamiento G2:**
```yaml
preprocess-g2:
  image: python:3.12-slim
  volumes:
    - ./scripts:/scripts:ro
    - ./datasets/g2:/work
  command: ["python","/scripts/normalize_csv.py","/work/raw.csv","/work/columns.map.json","/work/paises.csv"]
  restart: "no"
```

**API G2 (puerto 8010):**
```yaml
api-g2:
  build: ./app
  container_name: paises-api-g2
  env_file: .env.g2
  ports:
    - "8010:8000"
  volumes:
    - ./data/g2:/data:rw
    - ./datasets/g2/paises.csv:/data/paises.csv:ro
  depends_on:
    preprocess-g2:
      condition: service_completed_successfully
  restart: unless-stopped
```

**Preprocesamiento G3:**
```yaml
preprocess-g3:
  image: python:3.12-slim
  volumes:
    - ./scripts:/scripts:ro
    - ./datasets/g3:/work
  command: ["python","/scripts/normalize_csv.py","/work/raw.csv","/work/columns.map.json","/work/paises.csv"]
  restart: "no"
```

**API G3 (puerto 8020):**
```yaml
api-g3:
  build: ./app
  container_name: paises-api-g3
  env_file: .env.g3
  ports:
    - "8020:8000"
  volumes:
    - ./data/g3:/data:rw
    - ./datasets/g3/paises.csv:/data/paises.csv:ro
  depends_on:
    preprocess-g3:
      condition: service_completed_successfully
  restart: unless-stopped
```

### 5. Variables de Entorno

#### `.env.g2`
```env
TZ=America/Argentina/Mendoza
APP_NAME=Autos API (UTN - Grupo 2)
```

#### `.env.g3`
```env
TZ=America/Argentina/Mendoza
APP_NAME=Colegios API (UTN - Grupo 3)
```

---

## 🚀 Instrucciones de Despliegue en Servidor Linux

### Paso 1: Preparar el Servidor

```bash
# Actualizar sistema
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-plugin git

# Verificar instalación
docker --version
docker compose version
```

### Paso 2: Clonar/Actualizar el Repositorio

```bash
# Si es primera vez, clonar:
git clone https://github.com/ismaelsuarez/paises-apis.git
cd paises-apis

# Si ya existe, actualizar:
cd paises-apis
git pull origin main
```

### Paso 3: Verificar Estructura de Archivos

```bash
# Verificar que todos los archivos estén presentes
ls -la
ls -la app/
ls -la scripts/
ls -la datasets/g2/
ls -la datasets/g3/
ls -la data/

# Verificar CSVs
test -f data/paises.csv && echo "✅ data/paises.csv existe" || echo "❌ FALTA"
test -f datasets/g2/raw.csv && echo "✅ datasets/g2/raw.csv existe" || echo "❌ FALTA"
test -f datasets/g3/raw.csv && echo "✅ datasets/g3/raw.csv existe" || echo "❌ FALTA"
```

### Paso 4: Construir y Etiquetar la Imagen Local (IMPORTANTE)

**⚠️ CRÍTICO:** Los servicios nuevos (`api-g2`, `api-g3`, `preprocess-g2`, `preprocess-g3`) usan la imagen `paises-apis:local`. Esta imagen NO existe en Docker Hub, por lo que debes construirla localmente primero.

```bash
# Opción A: Si el servicio 8000 ya está corriendo, etiquetar su imagen existente
docker tag $(docker ps --filter "publish=8000" --format '{{.Image}}') paises-apis:local

# Opción B: Construir la imagen desde cero (si no existe el servicio 8000)
docker build -t paises-apis:local ./app

# Verificar que la imagen existe
docker images | grep paises-apis

# Deberías ver algo como:
# paises-apis  local  <image-id>  <time>  <size>
```

**Nota:** Si usas `docker compose up -d --build` para el servicio `paises_api` primero, también puedes etiquetar esa imagen después:
```bash
# Construir y levantar el servicio 8000
docker compose up -d --build paises_api

# Etiquetar la imagen recién construida
docker tag $(docker compose images paises_api -q) paises-apis:local
```

### Paso 5: Levantar los Servicios

```bash
# Opción 1: Levantar todos los servicios (requiere que paises-apis:local exista)
docker compose up -d paises_api  # Primero el servicio original
docker tag $(docker compose images paises_api -q) paises-apis:local  # Etiquetar
docker compose up -d preprocess-g2 preprocess-g3  # Luego preprocesamiento
docker compose up -d api-g2 api-g3  # Finalmente las APIs nuevas

# Opción 2: Levantar solo los servicios nuevos (si el 8000 ya está corriendo)
# Asegúrate de que paises-apis:local existe (ver Paso 4)
docker compose up -d preprocess-g2 preprocess-g3
docker compose up -d api-g2 api-g3

# Ver logs de preprocesamiento
docker compose logs preprocess-g2
docker compose logs preprocess-g3
```

### Paso 6: Verificar Estado de los Servicios

```bash
# Ver estado de todos los contenedores
docker compose ps

# Verificar que estén corriendo
docker compose ps | grep -E "(paises_api|api-g2|api-g3)" | grep "Up"
```

### Paso 7: Probar las APIs

```bash
# Salud servicio original (8000)
curl -s http://localhost:8000/health && echo " ✅ Puerto 8000 OK"

# Salud servicio Autos (8010)
curl -s http://localhost:8010/health && echo " ✅ Puerto 8010 OK"

# Salud servicio Colegios (8020)
curl -s http://localhost:8020/health && echo " ✅ Puerto 8020 OK"

# Probar endpoints de datos
curl -s "http://localhost:8010/countries?limit=3" | head -20
curl -s "http://localhost:8020/countries?limit=3" | head -20
```

### Paso 8: Acceder a Documentación Swagger

```bash
# URLs de documentación interactiva:
# http://<IP_SERVIDOR>:8000/docs  - Paises API (original)
# http://<IP_SERVIDOR>:8010/docs  - Autos API (Grupo 2)
# http://<IP_SERVIDOR>:8020/docs  - Colegios API (Grupo 3)
```

---

## 📊 Endpoints Disponibles

Todos los servicios comparten los mismos endpoints (comportamiento idéntico):

### Endpoints GET
- `GET /health` - Estado del servicio
- `GET /countries` - Listar países/registros
  - Query params: `q` (búsqueda), `continente`, `sort_by`, `desc`
- `GET /countries/{id}` - Obtener un registro por ID
- `GET /docs` - Documentación Swagger UI

### Endpoints POST
- `POST /countries` - Crear nuevo registro
- `POST /admin/reload-from-csv` - Recargar datos desde CSV

### Endpoints PUT/PATCH
- `PUT /countries/{id}` - Reemplazar registro completo
- `PATCH /countries/{id}` - Actualizar campos específicos

### Endpoints DELETE
- `DELETE /countries/{id}` - Eliminar registro

---

## 🔄 Flujo de Trabajo

1. **Preprocesamiento:** Los servicios `preprocess-g2` y `preprocess-g3` normalizan los CSV antes de que las APIs inicien
2. **Carga Inicial:** Cada API carga su CSV normalizado desde `/data/paises.csv`
3. **Persistencia:** Los cambios se guardan en JSON separado por servicio:
   - Servicio 8000: `data/paises.json`
   - Servicio 8010: `data/g2/paises.json`
   - Servicio 8020: `data/g3/paises.json`

---

## 🔧 Comandos Útiles de Mantenimiento

### Ver logs en tiempo real
```bash
docker compose logs -f api-g2
docker compose logs -f api-g3
docker compose logs -f paises_api
```

### Reiniciar un servicio específico
```bash
docker compose restart api-g2
docker compose restart api-g3
```

### Re-normalizar un CSV (si cambia el raw.csv)
```bash
# Para G2
docker compose run --rm preprocess-g2

# Para G3
docker compose run --rm preprocess-g3

# Luego recargar la API
curl -X POST http://localhost:8010/admin/reload-from-csv
curl -X POST http://localhost:8020/admin/reload-from-csv
```

### Detener todos los servicios
```bash
docker compose down
```

### Detener solo servicios nuevos (mantener 8000)
```bash
docker compose stop api-g2 api-g3
docker compose rm -f api-g2 api-g3
```

---

## ✅ Criterios de Aceptación

### Servicio Original (8000)
- ✅ Responde igual que antes
- ✅ Mismo comportamiento funcional
- ✅ Sin cambios en endpoints o lógica de negocio
- ✅ Mismo título por defecto ("Paises API")

### Nuevos Servicios
- ✅ Puerto 8010 sirve datos de Autos normalizados
- ✅ Puerto 8020 sirve datos de Colegios normalizados
- ✅ Cada servicio tiene persistencia independiente
- ✅ Títulos personalizados en OpenAPI docs
- ✅ Normalización automática al iniciar

---

## 📝 Notas Importantes

1. **Compatibilidad:** El servicio en puerto 8000 mantiene 100% de compatibilidad con versiones anteriores
2. **Volúmenes:** Cada servicio tiene su propio volumen de persistencia (`data/`, `data/g2/`, `data/g3/`)
3. **Normalización:** Si cambias `raw.csv` o `columns.map.json`, ejecuta el preprocesamiento nuevamente
4. **Puertos:** Asegúrate de que los puertos 8000, 8010 y 8020 estén abiertos en el firewall del servidor
5. **Recursos:** Cada servicio consume recursos independientes; ajusta según la capacidad del servidor

---

## 🐛 Solución de Problemas

### El servicio no inicia
```bash
# Ver logs detallados
docker compose logs <nombre_servicio>

# Verificar que los CSV estén normalizados
ls -la datasets/g2/paises.csv
ls -la datasets/g3/paises.csv
```

### Error de normalización (preprocess falla con exit 1)
**Problema:** Los servicios `preprocess-g2` y `preprocess-g3` fallan al ejecutarse.

**Diagnóstico:**
```bash
# Ver los logs detallados del error
docker compose logs preprocess-g2
docker compose logs preprocess-g3

# Verificar que los archivos necesarios existan
ls -la datasets/g2/
ls -la datasets/g3/

# Deben existir:
# - datasets/g2/raw.csv
# - datasets/g2/columns.map.json
# - datasets/g3/raw.csv
# - datasets/g3/columns.map.json
```

**Soluciones comunes:**

1. **Si faltan los archivos raw.csv:**
```bash
# Copiar los CSV originales a las carpetas correspondientes
cp /ruta/a/autos.csv datasets/g2/raw.csv
cp /ruta/a/Colegios.csv datasets/g3/raw.csv
```

2. **Si falta el script normalize_csv.py:**
```bash
# Verificar que existe
ls -la scripts/normalize_csv.py

# Si no existe, crearlo o copiarlo desde el repo
```

3. **Probar el script manualmente:**
```bash
# Ejecutar el contenedor de preprocesamiento manualmente para ver el error exacto
docker compose run --rm preprocess-g2

# O ejecutar directamente en el contenedor
docker run --rm -v $(pwd)/scripts:/scripts:ro -v $(pwd)/datasets/g2:/work paises-apis:local python /scripts/normalize_csv.py /work/raw.csv /work/columns.map.json /work/paises.csv
```

### Puerto ya en uso
```bash
# Ver qué está usando el puerto
sudo netstat -tulpn | grep :8010
sudo netstat -tulpn | grep :8020

# Detener servicio conflictivo o cambiar puerto en docker-compose.yml
```

### Error: "pull access denied for paises-apis"
**Problema:** Docker intenta descargar `paises-apis:local` desde Docker Hub, pero es una imagen local.

**Solución Rápida (si ya tienes el servicio 8000 corriendo):**
```bash
# 1. Etiquetar la imagen existente del servicio 8000
docker tag paises-apis-paises_api:latest paises-apis:local

# 2. Verificar que existe
docker images | grep paises-apis

# 3. Ahora levantar los servicios nuevos
docker compose up -d preprocess-g2 preprocess-g3
docker compose up -d api-g2 api-g3
```

**Solución Alternativa (si no existe el servicio 8000):**
```bash
# 1. Primero corregir el nombre del archivo requirements.txt (si tiene typo)
# En el servidor: mv app/requeriments.txt app/requirements.txt (si existe el typo)

# 2. Construir la imagen localmente
docker build -t paises-apis:local ./app

# 3. Verificar que existe
docker images | grep paises-apis

# 4. Ahora intenta levantar los servicios nuevamente
docker compose up -d preprocess-g2 preprocess-g3
docker compose up -d api-g2 api-g3
```

### Error: "requirements.txt not found" al construir
**Problema:** El Dockerfile busca `requirements.txt` pero el archivo puede tener un typo (`requeriments.txt`).

**Solución:**
```bash
# Verificar qué archivo existe
ls -la app/ | grep -i requirement

# Si existe "requeriments.txt" (con typo), renombrarlo:
mv app/requeriments.txt app/requirements.txt

# O crear requirements.txt copiando el contenido:
cp app/requeriments.txt app/requirements.txt
```

### Datos no se actualizan
```bash
# Forzar recarga desde CSV
curl -X POST http://localhost:8010/admin/reload-from-csv
curl -X POST http://localhost:8020/admin/reload-from-csv
```

---

## 📚 Referencias

- Repositorio: https://github.com/ismaelsuarez/paises-apis
- FastAPI Docs: https://fastapi.tiangolo.com/
- Docker Compose: https://docs.docker.com/compose/

---

**Documento generado:** $(date)  
**Versión:** 1.0  
**Autor:** Actualización Automatizada
