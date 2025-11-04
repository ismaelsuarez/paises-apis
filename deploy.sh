#!/bin/bash

# Script de despliegue para Paises APIs
# Uso: ./deploy.sh

set -e  # Salir si hay algún error

echo "========================================="
echo "  Despliegue de Paises APIs"
echo "========================================="
echo ""

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Paso 1: Verificar Docker
info "Verificando Docker..."
if ! command -v docker &> /dev/null; then
    error "Docker no está instalado. Instalando..."
    sudo apt-get update
    sudo apt-get install -y docker.io docker-compose-plugin
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    error "Docker Compose no está instalado."
    exit 1
fi

docker --version
docker compose version
echo ""

# Paso 2: Verificar estructura de archivos
info "Verificando estructura de archivos..."

REQUIRED_FILES=(
    "docker-compose.yml"
    "app/Dockerfile"
    "app/main.py"
    "scripts/normalize_csv.py"
    "datasets/g2/raw.csv"
    "datasets/g2/columns.map.json"
    "datasets/g3/raw.csv"
    "datasets/g3/columns.map.json"
    ".env.g2"
    ".env.g3"
)

MISSING_FILES=()
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    error "Faltan los siguientes archivos:"
    for file in "${MISSING_FILES[@]}"; do
        echo "  - $file"
    done
    exit 1
fi

info "Todos los archivos requeridos están presentes."
echo ""

# Paso 3: Verificar CSV de países (servicio original)
if [ ! -f "data/paises.csv" ]; then
    warn "data/paises.csv no existe. El servicio en puerto 8000 puede no funcionar correctamente."
else
    info "data/paises.csv encontrado."
fi
echo ""

# Paso 4: Preguntar si levantar todos los servicios o solo los nuevos
read -p "¿Levantar todos los servicios (8000, 8010, 8020) o solo los nuevos (8010, 8020)? [todos/nuevos] " choice

if [ "$choice" = "todos" ] || [ "$choice" = "T" ] || [ "$choice" = "" ]; then
    info "Levantando todos los servicios..."
    docker compose up -d --build
else
    info "Levantando solo los servicios nuevos (8010, 8020)..."
    docker compose up -d --build preprocess-g2 preprocess-g3
    docker compose up -d --build api-g2 api-g3
fi

echo ""

# Paso 5: Verificar logs de preprocesamiento
info "Verificando logs de preprocesamiento..."
echo ""
echo "--- Logs preprocess-g2 ---"
docker compose logs preprocess-g2 || true
echo ""
echo "--- Logs preprocess-g3 ---"
docker compose logs preprocess-g3 || true
echo ""

# Paso 6: Esperar unos segundos para que los servicios inicien
info "Esperando 5 segundos para que los servicios inicien..."
sleep 5

# Paso 7: Verificar estado de los servicios
info "Verificando estado de los servicios..."
docker compose ps
echo ""

# Paso 8: Probar los endpoints de salud
info "Probando endpoints de salud..."

SERVICES=(
    "8000:paises_api"
    "8010:api-g2"
    "8020:api-g3"
)

for service in "${SERVICES[@]}"; do
    PORT="${service%%:*}"
    NAME="${service##*:}"
    
    if docker compose ps | grep -q "$NAME.*Up"; then
        if curl -s -f "http://localhost:$PORT/health" > /dev/null 2>&1; then
            info "Puerto $PORT ($NAME): ✅ OK"
        else
            warn "Puerto $PORT ($NAME): ⚠️  Servicio corriendo pero no responde en /health"
        fi
    else
        warn "Puerto $PORT ($NAME): ⚠️  Servicio no está corriendo"
    fi
done

echo ""
info "========================================="
info "  Despliegue completado"
info "========================================="
echo ""
info "URLs disponibles:"
echo "  - Servicio 8000: http://localhost:8000/docs"
echo "  - Servicio 8010: http://localhost:8010/docs"
echo "  - Servicio 8020: http://localhost:8020/docs"
echo ""
info "Para ver logs: docker compose logs -f <nombre_servicio>"
info "Para detener: docker compose down"
