#!/bin/bash

echo "📦 Verificando pasta de entrada..."
if [ ! -d "input" ]; then
  echo "❌ Pasta 'input/' não encontrada."
  exit 1
fi

echo "🚀 Rodando importação..."
docker-compose run --rm importer python import_all_glebas_fast.py

echo "✅ Pronto! Todos os arquivos .csv em input/ foram processados."
