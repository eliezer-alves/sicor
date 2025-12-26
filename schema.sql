-- Habilitar extensões (normalmente o container postgis já tem, mas mantenha)
CREATE EXTENSION IF NOT EXISTS postgis;

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
