#!/bin/bash
# Script de diagnóstico para servicios 8010 y 8020

echo "========================================="
echo "  Diagnóstico Servicios 8010 y 8020"
echo "========================================="
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}[1] Estado de los contenedores:${NC}"
docker compose ps
echo ""

echo -e "${GREEN}[2] Verificando si los contenedores están corriendo:${NC}"
if docker compose ps | grep -q "api-g2.*Up"; then
    echo -e "${GREEN}✅ api-g2 está corriendo${NC}"
else
    echo -e "${RED}❌ api-g2 NO está corriendo${NC}"
fi

if docker compose ps | grep -q "api-g3.*Up"; then
    echo -e "${GREEN}✅ api-g3 está corriendo${NC}"
else
    echo -e "${RED}❌ api-g3 NO está corriendo${NC}"
fi
echo ""

echo -e "${GREEN}[3] Logs últimos 30 líneas de api-g2:${NC}"
docker compose logs --tail=30 api-g2
echo ""

echo -e "${GREEN}[4] Logs últimos 30 líneas de api-g3:${NC}"
docker compose logs --tail=30 api-g3
echo ""

echo -e "${GREEN}[5] Verificando archivos CSV normalizados:${NC}"
if [ -f "datasets/g2/paises.csv" ]; then
    echo -e "${GREEN}✅ datasets/g2/paises.csv existe ($(wc -l < datasets/g2/paises.csv) líneas)${NC}"
else
    echo -e "${RED}❌ datasets/g2/paises.csv NO existe${NC}"
fi

if [ -f "datasets/g3/paises.csv" ]; then
    echo -e "${GREEN}✅ datasets/g3/paises.csv existe ($(wc -l < datasets/g3/paises.csv) líneas)${NC}"
else
    echo -e "${RED}❌ datasets/g3/paises.csv NO existe${NC}"
fi
echo ""

echo -e "${GREEN}[6] Probando endpoints localmente:${NC}"
if curl -s -f http://localhost:8010/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ http://localhost:8010/health responde${NC}"
    curl -s http://localhost:8010/health
else
    echo -e "${RED}❌ http://localhost:8010/health NO responde${NC}"
fi
echo ""

if curl -s -f http://localhost:8020/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ http://localhost:8020/health responde${NC}"
    curl -s http://localhost:8020/health
else
    echo -e "${RED}❌ http://localhost:8020/health NO responde${NC}"
fi
echo ""

echo -e "${GREEN}[7] Verificando montajes de volúmenes dentro de los contenedores:${NC}"
echo "Verificando api-g2:"
docker compose exec -T api-g2 ls -la /app/data/ 2>/dev/null || echo "No se puede acceder al contenedor api-g2"
echo ""
echo "Verificando api-g3:"
docker compose exec -T api-g3 ls -la /app/data/ 2>/dev/null || echo "No se puede acceder al contenedor api-g3"
echo ""

echo "========================================="
echo "  Fin del Diagnóstico"
echo "========================================="
