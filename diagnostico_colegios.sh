#!/bin/bash
# Script de diagnóstico completo para el servicio de colegios (api-g3)

set -e

echo "========================================="
echo "🔍 DIAGNÓSTICO COMPLETO - API COLEGIOS"
echo "========================================="
echo ""

# 1. Verificar estado del servicio
echo "1️⃣  Verificando estado del servicio api-g3..."
if docker compose ps api-g3 | grep -q "Up"; then
    echo "   ✅ Servicio api-g3 está corriendo"
else
    echo "   ❌ Servicio api-g3 NO está corriendo"
    echo "   Ejecuta: docker compose up -d api-g3"
    exit 1
fi
echo ""

# 2. Verificar health check
echo "2️⃣  Verificando health check..."
if curl -fsS http://localhost:8020/health > /dev/null 2>&1; then
    echo "   ✅ Health check OK"
    curl -s http://localhost:8020/health | head -3
else
    echo "   ❌ Health check FALLÓ"
fi
echo ""

# 3. Verificar variable de entorno CSV_TYPE
echo "3️⃣  Verificando variable CSV_TYPE en .env.g3..."
if grep -q "CSV_TYPE=colegios" .env.g3 2>/dev/null; then
    echo "   ✅ CSV_TYPE=colegios encontrado en .env.g3"
else
    echo "   ❌ CSV_TYPE=colegios NO encontrado en .env.g3"
    echo "   Agregar: echo 'CSV_TYPE=colegios' >> .env.g3"
fi
echo ""

# 4. Verificar variable de entorno en el contenedor
echo "4️⃣  Verificando variable CSV_TYPE en el contenedor..."
CSV_TYPE_ENV=$(docker exec paises-api-g3 env | grep CSV_TYPE || echo "")
if [ -n "$CSV_TYPE_ENV" ]; then
    echo "   ✅ Variable encontrada: $CSV_TYPE_ENV"
else
    echo "   ❌ Variable CSV_TYPE NO encontrada en el contenedor"
    echo "   El servicio necesita reiniciarse después de agregar CSV_TYPE al .env.g3"
fi
echo ""

# 5. Verificar archivo CSV en el host
echo "5️⃣  Verificando archivo CSV en el host..."
if [ -f "datasets/g3/raw.csv" ]; then
    echo "   ✅ Archivo encontrado: datasets/g3/raw.csv"
    echo "   Tamaño: $(ls -lh datasets/g3/raw.csv | awk '{print $5}')"
    echo "   Líneas: $(wc -l < datasets/g3/raw.csv)"
else
    echo "   ❌ Archivo NO encontrado: datasets/g3/raw.csv"
fi
echo ""

# 6. Verificar montaje del CSV en el contenedor
echo "6️⃣  Verificando archivo CSV en el contenedor..."
if docker exec paises-api-g3 test -f /app/data/colegios.csv 2>/dev/null; then
    echo "   ✅ Archivo montado correctamente: /app/data/colegios.csv"
    echo "   Primeras líneas:"
    docker exec paises-api-g3 head -3 /app/data/colegios.csv
else
    echo "   ❌ Archivo NO encontrado en el contenedor: /app/data/colegios.csv"
fi
echo ""

# 7. Verificar qué archivos hay en /app/data
echo "7️⃣  Listando archivos en /app/data del contenedor..."
docker exec paises-api-g3 ls -la /app/data/ | head -10
echo ""

# 8. Verificar código del servidor (si tiene la nueva lógica)
echo "8️⃣  Verificando código del servidor..."
if docker exec paises-api-g3 cat /app/main.py 2>/dev/null | grep -q "os.getenv.*CSV_TYPE"; then
    echo "   ✅ Código actualizado: verifica CSV_TYPE de variables de entorno"
else
    echo "   ⚠️  Código puede estar desactualizado"
    echo "   Verificar que app/main.py tenga la lógica de CSV_TYPE"
fi
echo ""

# 9. Probar endpoint /colegios
echo "9️⃣  Probando endpoint /colegios..."
RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:8020/colegios 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Endpoint /colegios responde OK (200)"
    echo "   Respuesta: $(echo "$BODY" | head -3)"
elif [ "$HTTP_CODE" = "404" ]; then
    echo "   ❌ Endpoint /colegios devuelve 404 (Not Found)"
    echo "   El servicio no detectó colegios.csv correctamente"
elif [ "$HTTP_CODE" = "000" ]; then
    echo "   ❌ No se pudo conectar al servidor"
else
    echo "   ⚠️  Endpoint /colegios devuelve código: $HTTP_CODE"
    echo "   Respuesta: $BODY"
fi
echo ""

# 10. Ver logs recientes del servicio
echo "🔟 Últimos logs del servicio api-g3..."
docker compose logs --tail=20 api-g3 | grep -i "csv\|colegios\|autos\|error\|warning" || echo "   (sin mensajes relevantes)"
echo ""

# Resumen y recomendaciones
echo "========================================="
echo "📋 RESUMEN Y RECOMENDACIONES"
echo "========================================="
echo ""

if [ "$HTTP_CODE" = "404" ]; then
    echo "❌ PROBLEMA DETECTADO: Endpoint /colegios devuelve 404"
    echo ""
    echo "🔧 SOLUCIÓN PASO A PASO:"
    echo ""
    echo "1. Agregar CSV_TYPE=colegios al .env.g3:"
    echo "   echo 'CSV_TYPE=colegios' >> .env.g3"
    echo ""
    echo "2. Reconstruir el servicio:"
    echo "   docker compose stop api-g3"
    echo "   docker compose build api-g3"
    echo "   docker compose up -d api-g3"
    echo ""
    echo "3. Verificar que funcione:"
    echo "   curl http://localhost:8020/colegios"
    echo ""
    echo "4. Si aún no funciona, verificar que el código esté actualizado:"
    echo "   git pull origin main  # o subir app/main.py manualmente"
    echo "   docker compose build --no-cache api-g3"
    echo "   docker compose up -d api-g3"
else
    echo "✅ El endpoint /colegios está respondiendo correctamente"
fi

echo ""
echo "========================================="

