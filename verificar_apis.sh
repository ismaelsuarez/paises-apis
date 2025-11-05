#!/bin/bash
# Script de verificación de las 3 APIs

echo "=========================================="
echo "VERIFICACIÓN DE LAS 3 APIs"
echo "=========================================="
echo ""

# Colores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para verificar endpoint
verificar_endpoint() {
    local nombre=$1
    local url=$2
    local endpoint=$3
    
    echo -n "Verificando $nombre ($endpoint)... "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    
    if [ "$response" = "200" ]; then
        echo -e "${GREEN}✓ OK${NC} (HTTP $response)"
        return 0
    else
        echo -e "${RED}✗ ERROR${NC} (HTTP $response)"
        return 1
    fi
}

# Función para verificar datos
verificar_datos() {
    local nombre=$1
    local url=$2
    
    echo -n "Verificando datos de $nombre... "
    
    data=$(curl -s "$url")
    count=$(echo "$data" | grep -o '"id"' | wc -l)
    
    if [ "$count" -gt 0 ]; then
        echo -e "${GREEN}✓ OK${NC} ($count items)"
        return 0
    else
        echo -e "${YELLOW}⚠ Sin datos${NC}"
        return 1
    fi
}

# Verificar servicios Docker
echo "1. Verificando servicios Docker..."
docker compose ps | grep -E "paises_api|api-g2|api-g3" | while read line; do
    if echo "$line" | grep -q "Up"; then
        echo -e "  ${GREEN}✓${NC} $line"
    else
        echo -e "  ${RED}✗${NC} $line"
    fi
done
echo ""

# Verificar Puerto 8000 - Países
echo "2. Verificando API de Países (Puerto 8000)..."
verificar_endpoint "Health" "http://localhost:8000/health" "/health"
verificar_endpoint "Countries" "http://localhost:8000/countries" "/countries"
verificar_datos "Countries" "http://localhost:8000/countries"
echo ""

# Verificar Puerto 8010 - Autos
echo "3. Verificando API de Autos (Puerto 8010)..."
verificar_endpoint "Health" "http://localhost:8010/health" "/health"
verificar_endpoint "Autos" "http://localhost:8010/autos" "/autos"
verificar_datos "Autos" "http://localhost:8010/autos"
echo ""

# Verificar Puerto 8020 - Colegios
echo "4. Verificando API de Colegios (Puerto 8020)..."
verificar_endpoint "Health" "http://localhost:8020/health" "/health"
verificar_endpoint "Colegios" "http://localhost:8020/colegios" "/colegios"
verificar_datos "Colegios" "http://localhost:8020/colegios"
echo ""

# Resumen
echo "=========================================="
echo "RESUMEN"
echo "=========================================="
echo ""
echo "Documentación disponible en:"
echo "  - Países:  http://149.50.150.15:8000/docs"
echo "  - Autos:   http://149.50.150.15:8010/docs"
echo "  - Colegios: http://149.50.150.15:8020/docs"
echo ""
