#!/bin/bash

# === CONFIGS =====================
DB_USER="postgres"
DB_PASS="postgres"
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="geoapi"
EXPORT_DIR="./kml"

# Ponto central e raio (fácil de alterar)
LAT="-21.3700"
LON="-46.5300"
RAIO=20000  # 20km
# =================================

if [ $# -eq 0 ]; then
  echo "❌ Uso: ./export-glebas.sh ANO"
  echo "Exemplo: ./export-glebas.sh 2024"
  exit 1
fi

ANO=$1
FILE="$EXPORT_DIR/glebas_${ANO}_muzambinho.kml"

mkdir -p "$EXPORT_DIR"

echo "📍 Exportando glebas do ano $ANO dentro de $RAIO metros de Muzambinho..."

PGPASSWORD=$DB_PASS psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -c "\
COPY (
  SELECT '<?xml version=\"1.0\" encoding=\"UTF-8\"?>' ||
         '<kml xmlns=\"http://www.opengis.net/kml/2.2\"><Document>' ||
         string_agg(kml, '') ||
         '</Document></kml>'
  FROM glebas
  WHERE year = $ANO
    AND ST_DWithin(
      geom::geography,
      ST_SetSRID(ST_MakePoint($LON, $LAT), 4326)::geography,
      $RAIO
    )
) TO STDOUT;" > "$FILE"

if [ $? -eq 0 ]; then
  echo "✅ KML exportado com sucesso para: $FILE"
else
  echo "❌ Erro ao exportar arquivo para o ano $ANO"
fi
