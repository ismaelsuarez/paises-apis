#!/bin/bash
# Script de despliegue - Ejecutar en el servidor Linux después de git pull

echo "=========================================="
echo "DESPLIEGUE DE LAS 3 APIs"
echo "=========================================="
echo ""

# Paso 1: Verificar archivos
echo "PASO 1: Verificando archivos..."
cd ~/paises-apis

echo "Verificando CSVs..."
ls -lh datasets/g2/raw.csv || echo "⚠️  FALTA: datasets/g2/raw.csv"
ls -lh datasets/g3/raw.csv || echo "⚠️  FALTA: datasets/g3/raw.csv"
ls -lh data/paises.csv || echo "⚠️  FALTA: data/paises.csv"

echo ""
echo "Verificando archivos de configuración..."
ls -lh .env.g2 || echo "⚠️  FALTA: .env.g2"
ls -lh .env.g3 || echo "⚠️  FALTA: .env.g3"
ls -lh app/main.py || echo "⚠️  FALTA: app/main.py"
ls -lh docker-compose.yml || echo "⚠️  FALTA: docker-compose.yml"

echo ""
read -p "¿Todos los archivos están presentes? (s/n): " confirmar
if [ "$confirmar" != "s" ]; then
    echo "Por favor, verifica los archivos faltantes y vuelve a intentar."
    exit 1
fi

# Paso 2: Etiquetar imagen Docker
echo ""
echo "PASO 2: Etiquetando imagen Docker..."
echo "Buscando imagen del servicio 8000..."
IMAGE_ID=$(docker ps --filter "publish=8000" --format '{{.Image}}' | head -1)

if [ -z "$IMAGE_ID" ]; then
    echo "⚠️  No se encontró el servicio 8000. Intentando buscar imagen paises-apis..."
    IMAGE_ID=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "paises-apis" | head -1)
fi

if [ -z "$IMAGE_ID" ]; then
    echo "❌ No se encontró ninguna imagen. Necesitas construir primero el servicio 8000."
    exit 1
fi

echo "Imagen encontrada: $IMAGE_ID"
echo "Etiquetando como paises-apis:local..."

# Extraer el ID de la imagen si es necesario
if [[ "$IMAGE_ID" == *":"* ]]; then
    # Ya tiene tag
    docker tag "$IMAGE_ID" paises-apis:local 2>/dev/null || echo "La imagen ya está etiquetada o no existe."
else
    # Es solo un ID
    docker tag "$IMAGE_ID" paises-apis:local 2>/dev/null || echo "La imagen ya está etiquetada o no existe."
fi

# Verificar que la imagen existe
docker images | grep "paises-apis:local" && echo "✅ Imagen etiquetada correctamente" || echo "⚠️  Verifica que la imagen existe"

# Paso 3: Detener servicios existentes
echo ""
echo "PASO 3: Deteniendo servicios existentes (si están corriendo)..."
docker compose stop api-g2 api-g3 2>/dev/null || echo "Los servicios no estaban corriendo."

# Paso 4: Reconstruir servicios
echo ""
echo "PASO 4: Reconstruyendo servicios..."
echo "Esto puede tardar unos minutos..."
docker compose build api-g2 api-g3

if [ $? -ne 0 ]; then
    echo "❌ Error al reconstruir. Revisa los logs."
    exit 1
fi

echo "✅ Servicios reconstruidos"

# Paso 5: Levantar servicios
echo ""
echo "PASO 5: Levantando servicios..."
docker compose up -d api-g2 api-g3

if [ $? -ne 0 ]; then
    echo "❌ Error al levantar servicios. Revisa los logs."
    exit 1
fi

echo "✅ Servicios levantados"

# Paso 6: Ver logs
echo ""
echo "PASO 6: Verificando logs (últimas 30 líneas)..."
echo "--- Logs de api-g2 ---"
docker compose logs api-g2 --tail=30

echo ""
echo "--- Logs de api-g3 ---"
docker compose logs api-g3 --tail=30

# Paso 7: Verificar salud
echo ""
echo "PASO 7: Verificando salud de las APIs..."
sleep 3  # Esperar a que los servicios arranquen

echo -n "Puerto 8000 (Países): "
curl -s http://localhost:8000/health && echo " ✅" || echo " ❌"

echo -n "Puerto 8010 (Autos): "
curl -s http://localhost:8010/health && echo " ✅" || echo " ❌"

echo -n "Puerto 8020 (Colegios): "
curl -s http://localhost:8020/health && echo " ✅" || echo " ❌"

echo ""
echo "=========================================="
echo "DESPLIEGUE COMPLETADO"
echo "=========================================="
echo ""
echo "URLs de documentación:"
echo "  - Países:  http://149.50.150.15:8000/docs"
echo "  - Autos:   http://149.50.150.15:8010/docs"
echo "  - Colegios: http://149.50.150.15:8020/docs"
echo ""
echo "Para verificar en detalle, ejecuta:"
echo "  bash verificar_apis.sh"
echo ""
