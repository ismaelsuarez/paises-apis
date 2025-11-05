#!/bin/bash
# Solución Rápida para el Error 404 en /autos
# Ejecutar en el servidor Linux

echo "=========================================="
echo "SOLUCIÓN RÁPIDA - Error 404 en /autos"
echo "=========================================="
echo ""

cd ~/paises-apis

# Paso 1: Verificar el problema
echo "PASO 1: Verificando el problema..."
echo ""

# Verificar si el endpoint existe en el código del servidor
echo "Verificando código en el servidor..."
if grep -q "@app.get.*autos" app/main.py; then
    echo "✅ El código tiene el endpoint /autos"
else
    echo "❌ PROBLEMA: El código NO tiene el endpoint /autos"
    echo "   Ejecuta: git pull origin main"
    exit 1
fi

# Verificar código dentro del contenedor
echo ""
echo "Verificando código dentro del contenedor..."
if docker exec paises-api-g2 cat /app/main.py 2>/dev/null | grep -q "@app.get.*autos"; then
    echo "✅ El contenedor tiene el endpoint /autos"
    echo "   El problema podría ser otro (CSV, configuración, etc.)"
else
    echo "❌ PROBLEMA ENCONTRADO: El contenedor NO tiene el código actualizado"
    echo "   Necesita reconstrucción"
fi

echo ""
read -p "¿Continuar con la reconstrucción? (s/n): " continuar
if [ "$continuar" != "s" ]; then
    exit 0
fi

# Paso 2: Detener servicios
echo ""
echo "PASO 2: Deteniendo servicios..."
docker compose stop api-g2 api-g3
docker compose rm -f api-g2 api-g3

# Paso 3: Verificar imagen base
echo ""
echo "PASO 3: Verificando imagen base..."
if docker images | grep -q "paises-apis:local"; then
    echo "✅ Imagen paises-apis:local existe"
    echo "   NOTA: Reconstruiremos usando esta imagen pero con código nuevo"
else
    echo "⚠️  Imagen paises-apis:local no existe"
    echo "   Creando desde el servicio 8000..."
    
    # Buscar imagen del servicio 8000
    IMAGE_ID=$(docker ps --filter "publish=8000" --format '{{.Image}}' | head -1)
    if [ -n "$IMAGE_ID" ]; then
        echo "   Etiquetando imagen: $IMAGE_ID"
        docker tag "$IMAGE_ID" paises-apis:local
    else
        echo "   ❌ No se encontró imagen del servicio 8000"
        echo "   Construyendo desde Dockerfile..."
        docker compose build paises_api
        docker tag $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "paises-apis" | head -1) paises-apis:local
    fi
fi

# Paso 4: IMPORTANTE - Verificar que docker-compose usa build en lugar de image
echo ""
echo "PASO 4: Verificando docker-compose.yml..."
if grep -A 5 "api-g2:" docker-compose.yml | grep -q "build:"; then
    echo "✅ docker-compose.yml usa 'build:' - Correcto"
    USE_BUILD=true
elif grep -A 5 "api-g2:" docker-compose.yml | grep -q "image:.*local"; then
    echo "⚠️  docker-compose.yml usa 'image: paises-apis:local'"
    echo "   Necesitamos cambiar a 'build:' para usar código nuevo"
    USE_BUILD=false
    
    # Crear backup
    cp docker-compose.yml docker-compose.yml.backup
    echo "   Backup creado: docker-compose.yml.backup"
    
    # Modificar temporalmente para usar build
    echo ""
    echo "   Modificando docker-compose.yml temporalmente..."
    # Esto requiere edición manual o sed
    echo "   NOTA: Necesitas editar docker-compose.yml manualmente"
    echo "   Cambiar 'image: paises-apis:local' por 'build: ./app' en api-g2 y api-g3"
else
    echo "⚠️  No se encontró configuración clara"
    USE_BUILD=false
fi

# Paso 5: Reconstruir
echo ""
echo "PASO 5: Reconstruyendo servicios..."
echo "Esto puede tardar unos minutos..."

if [ "$USE_BUILD" = true ]; then
    # Reconstruir desde Dockerfile (usa código nuevo)
    docker compose build --no-cache api-g2 api-g3
else
    # Como usa imagen, necesitamos copiar el código manualmente
    echo "   Copiando código actualizado a la imagen..."
    echo ""
    echo "   OPCIÓN A: Reconstruir desde Dockerfile (RECOMENDADO)"
    echo "   1. Edita docker-compose.yml y cambia:"
    echo "      De: image: paises-apis:local"
    echo "      A:   build: ./app"
    echo ""
    echo "   2. Luego ejecuta: docker compose build --no-cache api-g2 api-g3"
    echo ""
    echo "   OPCIÓN B: Copiar código manualmente al contenedor (temporal)"
    echo "   Esto NO es recomendado pero funciona rápido"
    
    read -p "   ¿Usar opción B (copiar manualmente)? (s/n): " opcion_b
    if [ "$opcion_b" = "s" ]; then
        # Levantar con imagen vieja primero
        docker compose up -d api-g2
        
        # Esperar a que arranque
        sleep 3
        
        # Copiar código nuevo
        echo "   Copiando app/main.py al contenedor..."
        docker cp app/main.py paises-api-g2:/app/main.py
        
        # Reiniciar para que tome el código nuevo
        echo "   Reiniciando contenedor..."
        docker compose restart api-g2
        
        echo "   ✅ Código copiado manualmente"
    else
        echo "   Por favor, edita docker-compose.yml y vuelve a ejecutar este script"
        exit 1
    fi
fi

# Paso 6: Levantar servicios
if [ "$USE_BUILD" = true ] || [ "$opcion_b" != "s" ]; then
    echo ""
    echo "PASO 6: Levantando servicios..."
    docker compose up -d api-g2 api-g3
fi

# Paso 7: Esperar y verificar
echo ""
echo "PASO 7: Esperando a que los servicios arranquen..."
sleep 5

echo ""
echo "Verificando servicios..."
docker compose ps | grep -E "api-g2|api-g3"

echo ""
echo "Verificando endpoints..."
echo -n "  Health: "
curl -s http://localhost:8010/health > /dev/null && echo "✅" || echo "❌"

echo -n "  /autos: "
AUTOS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8010/autos)
if [ "$AUTOS_RESPONSE" = "200" ]; then
    echo "✅ OK"
    echo ""
    echo "=========================================="
    echo "✅ PROBLEMA RESUELTO"
    echo "=========================================="
    echo ""
    echo "El endpoint /autos ahora funciona!"
    echo ""
    echo "Probando desde el servidor:"
    curl -s http://localhost:8010/autos | head -20
else
    echo "❌ Error HTTP $AUTOS_RESPONSE"
    echo ""
    echo "Ver logs para más detalles:"
    echo "  docker compose logs api-g2 --tail=50"
fi

echo ""
echo "Ver logs completos:"
echo "  docker compose logs api-g2 --tail=100"
