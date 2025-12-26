-- Habilitar extensões (normalmente o container postgis já tem, mas mantenha)
CREATE EXTENSION IF NOT EXISTS postgis;

-- =========================================
-- GLEBAS
-- =========================================

-- STAGING: texto cru. UNLOGGED melhora performance (aceita perder staging em crash).
DROP TABLE IF EXISTS glebas_staging;
CREATE UNLOGGED TABLE glebas_staging (
  ref_bacen     text,
  order_number  text,
  index_number  text,
  wkt           text,
  year          int
);

-- FINAL
CREATE TABLE IF NOT EXISTS glebas (
  id            bigserial PRIMARY KEY,
  ref_bacen     text NOT NULL,
  order_number  text NOT NULL,
  index_number  text NOT NULL,
  year          int  NOT NULL,
  wkt           text,
  geom          geometry(Geometry, 4326) NOT NULL,

  -- geography gerada (metros). Ideal para ST_DWithin com raio em metros.
  geog          geography(Geometry, 4326) GENERATED ALWAYS AS (geom::geography) STORED,

  created_at    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT glebas_uk UNIQUE (ref_bacen, order_number, index_number, year)
);

-- Índices
CREATE INDEX IF NOT EXISTS glebas_geom_gix ON glebas USING GIST (geom);
CREATE INDEX IF NOT EXISTS glebas_geog_gix ON glebas USING GIST (geog);
CREATE INDEX IF NOT EXISTS glebas_year_idx ON glebas (year);

-- Rejeitados: auditoria e reprocessamento
CREATE TABLE IF NOT EXISTS glebas_rejected (
  id            bigserial PRIMARY KEY,
  ref_bacen     text,
  order_number  text,
  index_number  text,
  year          int,
  wkt           text,
  reason        text,
  rejected_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS glebas_rejected_year_idx ON glebas_rejected (year);
CREATE INDEX IF NOT EXISTS glebas_rejected_ref_idx ON glebas_rejected (ref_bacen);

-- View para consulta “formatada” (KML/GeoJSON gerados sob demanda)
CREATE OR REPLACE VIEW v_glebas_formats AS
SELECT
  g.id,
  g.ref_bacen,
  g.order_number,
  g.index_number,
  g.year,
  g.geom,
  ST_AsKML(g.geom) AS kml,
  ST_AsGeoJSON(g.geom)::json AS geojson
FROM glebas g;

-- =========================================
-- SICOR - OPERACAO BASICA ESTADO (novo)
-- =========================================

-- STAGING (tudo TEXT): garante COPY sem falha por tipo/data/numeric
CREATE TABLE IF NOT EXISTS sicor_operacao_basica_estado_staging (
  ref_bacen                  text,
  nu_ordem                   text,
  cnpj_if                    text,
  dt_emissao                 text,
  dt_vencimento              text,
  cd_inst_credito            text,
  cd_categ_emitente          text,
  cd_fonte_recurso           text,
  cnpj_agente_invest         text,
  cd_estado                  text,
  cd_ref_bacen_investimento  text,
  cd_tipo_seguro             text,
  cd_empreendimento          text,
  cd_programa                text,
  cd_tipo_encarg_financ      text,
  cd_tipo_irrigacao          text,
  cd_tipo_agricultura        text,
  cd_fase_ciclo_producao     text,
  cd_tipo_cultivo            text,
  cd_tipo_intgr_consor       text,
  cd_tipo_grao_semente       text,
  vl_aliq_proagro            text,
  vl_juros                   text,
  vl_prestacao_investimento  text,
  vl_prev_prod               text,
  vl_quantidade              text,
  vl_receita_bruta_esperada  text,
  vl_parc_credito            text,
  vl_rec_proprio             text,
  vl_perc_risco_stn          text,
  vl_perc_risco_fundo_const  text,
  vl_rec_proprio_srv         text,
  vl_area_financ             text,
  cd_subprograma             text,
  vl_produtiv_obtida         text,
  dt_fim_colheita            text,
  dt_fim_plantio             text,
  dt_inic_colheita           text,
  dt_inic_plantio            text,
  vl_juros_enc_finan_posfix  text,
  vl_perc_custo_efet_total   text,
  cd_contrato_stn            text,
  cd_cnpj_cadastrante        text,
  vl_area_informada          text,
  cd_ciclo_cultivar          text,
  cd_tipo_solo               text,
  pc_bonus_car               text,
  _imported_at               timestamptz NOT NULL DEFAULT now()
);

-- TABELA OFICIAL (tipada) + year
CREATE TABLE IF NOT EXISTS sicor_operacao_basica_estado (
  id                         bigserial PRIMARY KEY,
  year                       int NOT NULL,

  ref_bacen                  text NOT NULL,
  nu_ordem                   int  NOT NULL,

  cnpj_if                    text,
  dt_emissao                 date,
  dt_vencimento              date,

  cd_inst_credito            text,
  cd_categ_emitente          text,
  cd_fonte_recurso           text,
  cnpj_agente_invest         text,
  cd_estado                  text,

  cd_ref_bacen_investimento  text,
  cd_tipo_seguro             text,
  cd_empreendimento          text,
  cd_programa                text,
  cd_tipo_encarg_financ      text,
  cd_tipo_irrigacao          text,
  cd_tipo_agricultura        text,
  cd_fase_ciclo_producao     text,
  cd_tipo_cultivo            text,
  cd_tipo_intgr_consor       text,
  cd_tipo_grao_semente       text,

  vl_aliq_proagro            numeric,
  vl_juros                   numeric,
  vl_prestacao_investimento  numeric,
  vl_prev_prod               numeric,
  vl_quantidade              numeric,
  vl_receita_bruta_esperada  numeric,
  vl_parc_credito            numeric,
  vl_rec_proprio             numeric,
  vl_perc_risco_stn          numeric,
  vl_perc_risco_fundo_const  numeric,
  vl_rec_proprio_srv         numeric,
  vl_area_financ             numeric,

  cd_subprograma             text,
  vl_produtiv_obtida         numeric,

  dt_fim_colheita            date,
  dt_fim_plantio             date,
  dt_inic_colheita           date,
  dt_inic_plantio            date,

  vl_juros_enc_finan_posfix  numeric,
  vl_perc_custo_efet_total   numeric,

  cd_contrato_stn            text,
  cd_cnpj_cadastrante        text,

  vl_area_informada          numeric,
  cd_ciclo_cultivar          text,
  cd_tipo_solo               text,
  pc_bonus_car               numeric,

  created_at                 timestamptz NOT NULL DEFAULT now()
);

-- Índices para consultas e reimport seguro
CREATE INDEX IF NOT EXISTS sicor_ob_estado_year_idx ON sicor_operacao_basica_estado (year);
CREATE INDEX IF NOT EXISTS sicor_ob_estado_ref_bacen_idx ON sicor_operacao_basica_estado (ref_bacen);
CREATE INDEX IF NOT EXISTS sicor_ob_estado_uf_idx ON sicor_operacao_basica_estado (cd_estado);

-- Chave natural (permite ON CONFLICT DO NOTHING no reimport)
CREATE UNIQUE INDEX IF NOT EXISTS sicor_ob_estado_uniq
ON sicor_operacao_basica_estado (year, ref_bacen, nu_ordem);

-- =========================================
-- DIMENSOES AUXILIARES (novo)
-- =========================================

CREATE TABLE IF NOT EXISTS fonte_recursos (
  codigo   text PRIMARY KEY,
  descricao text NOT NULL
);
