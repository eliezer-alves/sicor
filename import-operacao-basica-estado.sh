#!/usr/bin/env bash
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-postgis-db}"
DB_NAME="${DB_NAME:-geoapi}"
DB_USER="${DB_USER:-postgres}"

# intervalo padrão
FROM_YEAR="${1:-2014}"
TO_YEAR="${2:-2025}"

psql_in_container() {
  docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 "$@"
}

echo "Import SICOR_OPERACAO_BASICA_ESTADO: ${FROM_YEAR}..${TO_YEAR}"
echo "Container: ${DB_CONTAINER} | DB: ${DB_NAME} | User: ${DB_USER}"
echo

# Sessão: ajustes leves de performance (não persistem)
psql_in_container <<'SQL'
SET statement_timeout = 0;
SET synchronous_commit = off;
SQL

for y in $(seq "$FROM_YEAR" "$TO_YEAR"); do
  csv="/data/SICOR_OPERACAO_BASICA_ESTADO_${y}.csv"

  echo "============================"
  echo "Ano: $y"
  echo "CSV: $csv"

  # Verifica se o arquivo existe dentro do container
  if ! docker exec "$DB_CONTAINER" bash -lc "[ -f '$csv' ]"; then
    echo "[skip] CSV não encontrado no container: $csv"
    continue
  fi

  t0=$(date +%s)

  # 1) staging
  psql_in_container <<SQL
TRUNCATE sicor_operacao_basica_estado_staging;

COPY sicor_operacao_basica_estado_staging (
  ref_bacen, nu_ordem, cnpj_if, dt_emissao, dt_vencimento, cd_inst_credito, cd_categ_emitente,
  cd_fonte_recurso, cnpj_agente_invest, cd_estado, cd_ref_bacen_investimento, cd_tipo_seguro,
  cd_empreendimento, cd_programa, cd_tipo_encarg_financ, cd_tipo_irrigacao, cd_tipo_agricultura,
  cd_fase_ciclo_producao, cd_tipo_cultivo, cd_tipo_intgr_consor, cd_tipo_grao_semente,
  vl_aliq_proagro, vl_juros, vl_prestacao_investimento, vl_prev_prod, vl_quantidade,
  vl_receita_bruta_esperada, vl_parc_credito, vl_rec_proprio, vl_perc_risco_stn,
  vl_perc_risco_fundo_const, vl_rec_proprio_srv, vl_area_financ, cd_subprograma,
  vl_produtiv_obtida, dt_fim_colheita, dt_fim_plantio, dt_inic_colheita, dt_inic_plantio,
  vl_juros_enc_finan_posfix, vl_perc_custo_efet_total, cd_contrato_stn, cd_cnpj_cadastrante,
  vl_area_informada, cd_ciclo_cultivar, cd_tipo_solo, pc_bonus_car
)
FROM '$csv'
WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL '', ENCODING 'UTF8');

SELECT 'staging_rows' AS k, count(*)::bigint AS v
FROM sicor_operacao_basica_estado_staging;
SQL

  t1=$(date +%s)

  # 2) insert tipado (tabela oficial)
  psql_in_container <<SQL
INSERT INTO sicor_operacao_basica_estado (
  year,
  ref_bacen, nu_ordem,
  cnpj_if, dt_emissao, dt_vencimento,
  cd_inst_credito, cd_categ_emitente, cd_fonte_recurso, cnpj_agente_invest, cd_estado,
  cd_ref_bacen_investimento, cd_tipo_seguro, cd_empreendimento, cd_programa, cd_tipo_encarg_financ,
  cd_tipo_irrigacao, cd_tipo_agricultura, cd_fase_ciclo_producao, cd_tipo_cultivo,
  cd_tipo_intgr_consor, cd_tipo_grao_semente,
  vl_aliq_proagro, vl_juros, vl_prestacao_investimento, vl_prev_prod, vl_quantidade,
  vl_receita_bruta_esperada, vl_parc_credito, vl_rec_proprio, vl_perc_risco_stn,
  vl_perc_risco_fundo_const, vl_rec_proprio_srv, vl_area_financ,
  cd_subprograma, vl_produtiv_obtida,
  dt_fim_colheita, dt_fim_plantio, dt_inic_colheita, dt_inic_plantio,
  vl_juros_enc_finan_posfix, vl_perc_custo_efet_total,
  cd_contrato_stn, cd_cnpj_cadastrante,
  vl_area_informada, cd_ciclo_cultivar, cd_tipo_solo, pc_bonus_car
)
SELECT
  ${y} AS year,

  NULLIF(trim(ref_bacen), '') AS ref_bacen,
  CASE WHEN NULLIF(trim(nu_ordem), '') ~ '^\d+$' THEN trim(nu_ordem)::int ELSE NULL END AS nu_ordem,

  NULLIF(trim(cnpj_if), '') AS cnpj_if,
  CASE WHEN NULLIF(trim(dt_emissao), '') ~ '^\d{2}/\d{2}/\d{4}$' THEN to_date(trim(dt_emissao), 'DD/MM/YYYY') ELSE NULL END AS dt_emissao,
  CASE WHEN NULLIF(trim(dt_vencimento), '') ~ '^\d{2}/\d{2}/\d{4}$' THEN to_date(trim(dt_vencimento), 'DD/MM/YYYY') ELSE NULL END AS dt_vencimento,

  NULLIF(trim(cd_inst_credito), '') AS cd_inst_credito,
  NULLIF(trim(cd_categ_emitente), '') AS cd_categ_emitente,
  NULLIF(trim(cd_fonte_recurso), '') AS cd_fonte_recurso,
  NULLIF(trim(cnpj_agente_invest), '') AS cnpj_agente_invest,
  NULLIF(trim(cd_estado), '') AS cd_estado,

  NULLIF(trim(cd_ref_bacen_investimento), '') AS cd_ref_bacen_investimento,
  NULLIF(trim(cd_tipo_seguro), '') AS cd_tipo_seguro,
  NULLIF(trim(cd_empreendimento), '') AS cd_empreendimento,
  NULLIF(trim(cd_programa), '') AS cd_programa,
  NULLIF(trim(cd_tipo_encarg_financ), '') AS cd_tipo_encarg_financ,
  NULLIF(trim(cd_tipo_irrigacao), '') AS cd_tipo_irrigacao,
  NULLIF(trim(cd_tipo_agricultura), '') AS cd_tipo_agricultura,
  NULLIF(trim(cd_fase_ciclo_producao), '') AS cd_fase_ciclo_producao,
  NULLIF(trim(cd_tipo_cultivo), '') AS cd_tipo_cultivo,
  NULLIF(trim(cd_tipo_intgr_consor), '') AS cd_tipo_intgr_consor,
  NULLIF(trim(cd_tipo_grao_semente), '') AS cd_tipo_grao_semente,

  CASE WHEN NULLIF(trim(vl_aliq_proagro), '') IS NULL THEN NULL
       WHEN replace(trim(vl_aliq_proagro), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_aliq_proagro), ',', '.')::numeric
       ELSE NULL END AS vl_aliq_proagro,
  CASE WHEN NULLIF(trim(vl_juros), '') IS NULL THEN NULL
       WHEN replace(trim(vl_juros), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_juros), ',', '.')::numeric
       ELSE NULL END AS vl_juros,
  CASE WHEN NULLIF(trim(vl_prestacao_investimento), '') IS NULL THEN NULL
       WHEN replace(trim(vl_prestacao_investimento), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_prestacao_investimento), ',', '.')::numeric
       ELSE NULL END AS vl_prestacao_investimento,
  CASE WHEN NULLIF(trim(vl_prev_prod), '') IS NULL THEN NULL
       WHEN replace(trim(vl_prev_prod), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_prev_prod), ',', '.')::numeric
       ELSE NULL END AS vl_prev_prod,
  CASE WHEN NULLIF(trim(vl_quantidade), '') IS NULL THEN NULL
       WHEN replace(trim(vl_quantidade), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_quantidade), ',', '.')::numeric
       ELSE NULL END AS vl_quantidade,
  CASE WHEN NULLIF(trim(vl_receita_bruta_esperada), '') IS NULL THEN NULL
       WHEN replace(trim(vl_receita_bruta_esperada), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_receita_bruta_esperada), ',', '.')::numeric
       ELSE NULL END AS vl_receita_bruta_esperada,
  CASE WHEN NULLIF(trim(vl_parc_credito), '') IS NULL THEN NULL
       WHEN replace(trim(vl_parc_credito), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_parc_credito), ',', '.')::numeric
       ELSE NULL END AS vl_parc_credito,
  CASE WHEN NULLIF(trim(vl_rec_proprio), '') IS NULL THEN NULL
       WHEN replace(trim(vl_rec_proprio), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_rec_proprio), ',', '.')::numeric
       ELSE NULL END AS vl_rec_proprio,
  CASE WHEN NULLIF(trim(vl_perc_risco_stn), '') IS NULL THEN NULL
       WHEN replace(trim(vl_perc_risco_stn), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_perc_risco_stn), ',', '.')::numeric
       ELSE NULL END AS vl_perc_risco_stn,
  CASE WHEN NULLIF(trim(vl_perc_risco_fundo_const), '') IS NULL THEN NULL
       WHEN replace(trim(vl_perc_risco_fundo_const), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_perc_risco_fundo_const), ',', '.')::numeric
       ELSE NULL END AS vl_perc_risco_fundo_const,
  CASE WHEN NULLIF(trim(vl_rec_proprio_srv), '') IS NULL THEN NULL
       WHEN replace(trim(vl_rec_proprio_srv), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_rec_proprio_srv), ',', '.')::numeric
       ELSE NULL END AS vl_rec_proprio_srv,
  CASE WHEN NULLIF(trim(vl_area_financ), '') IS NULL THEN NULL
       WHEN replace(trim(vl_area_financ), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_area_financ), ',', '.')::numeric
       ELSE NULL END AS vl_area_financ,

  NULLIF(trim(cd_subprograma), '') AS cd_subprograma,
  CASE WHEN NULLIF(trim(vl_produtiv_obtida), '') IS NULL THEN NULL
       WHEN replace(trim(vl_produtiv_obtida), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_produtiv_obtida), ',', '.')::numeric
       ELSE NULL END AS vl_produtiv_obtida,

  CASE WHEN NULLIF(trim(dt_fim_colheita), '') ~ '^\d{2}/\d{2}/\d{4}$' THEN to_date(trim(dt_fim_colheita), 'DD/MM/YYYY') ELSE NULL END AS dt_fim_colheita,
  CASE WHEN NULLIF(trim(dt_fim_plantio), '') ~ '^\d{2}/\d{2}/\d{4}$' THEN to_date(trim(dt_fim_plantio), 'DD/MM/YYYY') ELSE NULL END AS dt_fim_plantio,
  CASE WHEN NULLIF(trim(dt_inic_colheita), '') ~ '^\d{2}/\d{2}/\d{4}$' THEN to_date(trim(dt_inic_colheita), 'DD/MM/YYYY') ELSE NULL END AS dt_inic_colheita,
  CASE WHEN NULLIF(trim(dt_inic_plantio), '') ~ '^\d{2}/\d{2}/\d{4}$' THEN to_date(trim(dt_inic_plantio), 'DD/MM/YYYY') ELSE NULL END AS dt_inic_plantio,

  CASE WHEN NULLIF(trim(vl_juros_enc_finan_posfix), '') IS NULL THEN NULL
       WHEN replace(trim(vl_juros_enc_finan_posfix), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_juros_enc_finan_posfix), ',', '.')::numeric
       ELSE NULL END AS vl_juros_enc_finan_posfix,
  CASE WHEN NULLIF(trim(vl_perc_custo_efet_total), '') IS NULL THEN NULL
       WHEN replace(trim(vl_perc_custo_efet_total), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_perc_custo_efet_total), ',', '.')::numeric
       ELSE NULL END AS vl_perc_custo_efet_total,

  NULLIF(trim(cd_contrato_stn), '') AS cd_contrato_stn,
  NULLIF(trim(cd_cnpj_cadastrante), '') AS cd_cnpj_cadastrante,

  CASE WHEN NULLIF(trim(vl_area_informada), '') IS NULL THEN NULL
       WHEN replace(trim(vl_area_informada), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(vl_area_informada), ',', '.')::numeric
       ELSE NULL END AS vl_area_informada,

  NULLIF(trim(cd_ciclo_cultivar), '') AS cd_ciclo_cultivar,
  NULLIF(trim(cd_tipo_solo), '') AS cd_tipo_solo,

  CASE WHEN NULLIF(trim(pc_bonus_car), '') IS NULL THEN NULL
       WHEN replace(trim(pc_bonus_car), ',', '.') ~ '^-?\d+(\.\d+)?$' THEN replace(trim(pc_bonus_car), ',', '.')::numeric
       ELSE NULL END AS pc_bonus_car
FROM sicor_operacao_basica_estado_staging
WHERE NULLIF(trim(ref_bacen), '') IS NOT NULL
  AND NULLIF(trim(nu_ordem), '') ~ '^\d+$'
ON CONFLICT (year, ref_bacen, nu_ordem) DO NOTHING;

SELECT 'inserted_total_year' AS k, count(*)::bigint AS v
FROM sicor_operacao_basica_estado
WHERE year = ${y};
SQL

  t2=$(date +%s)

  # métricas
  stage_s=$((t1 - t0))
  ins_s=$((t2 - t1))
  total_s=$((t2 - t0))

  echo "Tempo COPY staging: ${stage_s}s | Tempo INSERT oficial: ${ins_s}s | Total: ${total_s}s"

  # limpeza (opcional)
  psql_in_container -c "TRUNCATE sicor_operacao_basica_estado_staging;" >/dev/null
done

echo
echo "Concluído."
echo "Resumo por ano:"
psql_in_container <<'SQL'
SELECT year, count(*) AS rows
FROM sicor_operacao_basica_estado
GROUP BY year
ORDER BY year;

