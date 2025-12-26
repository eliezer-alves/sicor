import os
import re
import sys
import time
from pathlib import Path
from typing import Optional, Tuple

import psycopg2


# ---------------------------
# Config
# ---------------------------
INPUT_DIR = Path(os.getenv("INPUT_DIR", "input"))
SCHEMA_SQL_PATH = Path(os.getenv("SCHEMA_SQL_PATH", "schema.sql"))

DB_USER = os.getenv("DB_USER", "postgres")
DB_PASS = os.getenv("DB_PASS", "postgres")
DB_HOST = os.getenv("DB_HOST", "db")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "geoapi")

# Performance flags
ANALYZE_AFTER_EACH_FILE = os.getenv("ANALYZE_AFTER_EACH_FILE", "true").lower() == "true"
TRUNCATE_STAGING_EACH_FILE = os.getenv("TRUNCATE_STAGING_EACH_FILE", "true").lower() == "true"


def log(msg: str) -> None:
    print(msg, flush=True)


def extract_year_from_filename(filename: str) -> Optional[int]:
    """
    Extrai um ano (YYYY) do nome do arquivo.
    Ex.: glebas_2022.csv -> 2022
    """
    m = re.search(r"(19\d{2}|20\d{2})", filename)
    return int(m.group(1)) if m else None


def connect():
    return psycopg2.connect(
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS,
        host=DB_HOST,
        port=DB_PORT,
    )


def ensure_schema(conn) -> None:
    if not SCHEMA_SQL_PATH.exists():
        raise FileNotFoundError(f"schema.sql não encontrado em: {SCHEMA_SQL_PATH.resolve()}")

    sql_text = SCHEMA_SQL_PATH.read_text(encoding="utf-8")
    with conn.cursor() as cur:
        cur.execute(sql_text)
    conn.commit()
    log(f"Schema aplicado a partir de {SCHEMA_SQL_PATH}")


def copy_csv_to_staging(conn, csv_path: Path, year: int) -> int:
    """
    Faz COPY do CSV original direto para staging.
    Retorna quantidade estimada de linhas carregadas (nem sempre disponível com precisão no COPY).
    """
    with conn.cursor() as cur:
        if TRUNCATE_STAGING_EACH_FILE:
            cur.execute("TRUNCATE glebas_staging;")

        # COPY: arquivo tem HEADER e delimiter ';'
        copy_cmd = """
            COPY glebas_staging (ref_bacen, order_number, index_number, wkt)
            FROM STDIN
            WITH (FORMAT CSV, HEADER TRUE, DELIMITER ';')
        """

        # Arquivos podem ter sujeira de encoding; errors=replace evita crash
        with csv_path.open("r", encoding="utf-8", errors="replace") as f:
            cur.copy_expert(copy_cmd, f)

        # set year para o lote atual
        cur.execute("UPDATE glebas_staging SET year = %s WHERE year IS NULL;", (year,))

        # Contagem do lote (custo baixo, mas existe; pode desligar se quiser)
        cur.execute("SELECT COUNT(*) FROM glebas_staging;")
        (count_rows,) = cur.fetchone()
        return int(count_rows)


def process_staging_set_based(conn) -> Tuple[int, int]:
    """
    Processa staging -> final em SQL set-based:
      - Converte WKT -> geom
      - Separa inválidos e registra em glebas_rejected
      - Insere válidos em glebas (ON CONFLICT DO NOTHING)
    Retorna (inserted_valid, inserted_rejected) da execução.
    """
    sql_process = """
    WITH parsed AS (
      SELECT
        ref_bacen,
        order_number,
        index_number,
        year,
        wkt,
        ST_Force2D(ST_GeomFromText(wkt, 4326)) AS geom
      FROM glebas_staging
    ),
    invalid AS (
      SELECT
        ref_bacen,
        order_number,
        index_number,
        year,
        wkt,
        CASE
          WHEN geom IS NULL THEN 'geom is NULL (parse failed)'
          ELSE ST_IsValidReason(geom)
        END AS reason
      FROM parsed
      WHERE geom IS NULL OR NOT ST_IsValid(geom)
    ),
    valid AS (
      SELECT
        ref_bacen,
        order_number,
        index_number,
        year,
        wkt,
        geom
      FROM parsed
      WHERE geom IS NOT NULL AND ST_IsValid(geom)
    ),
    ins_valid AS (
      INSERT INTO glebas (ref_bacen, order_number, index_number, year, wkt, geom)
      SELECT ref_bacen, order_number, index_number, year, wkt, geom
      FROM valid
      ON CONFLICT (ref_bacen, order_number, index_number, year) DO NOTHING
      RETURNING 1
    ),
    ins_rej AS (
      INSERT INTO glebas_rejected (ref_bacen, order_number, index_number, year, wkt, reason)
      SELECT ref_bacen, order_number, index_number, year, wkt, reason
      FROM invalid
      RETURNING 1
    )
    SELECT
      (SELECT COUNT(*) FROM ins_valid)   AS inserted_valid,
      (SELECT COUNT(*) FROM ins_rej)     AS inserted_rejected;
    """

    with conn.cursor() as cur:
        cur.execute(sql_process)
        inserted_valid, inserted_rejected = cur.fetchone()
        return int(inserted_valid), int(inserted_rejected)


def analyze_tables(conn) -> None:
    with conn.cursor() as cur:
        cur.execute("ANALYZE glebas;")
        cur.execute("ANALYZE glebas_rejected;")
    conn.commit()


def main() -> int:
    if not INPUT_DIR.exists():
        log(f"Diretório de input não existe: {INPUT_DIR.resolve()}")
        return 1

    csv_files = sorted([p for p in INPUT_DIR.iterdir() if p.is_file() and p.suffix.lower() == ".csv"])
    if not csv_files:
        log(f"Nenhum .csv encontrado em: {INPUT_DIR.resolve()}")
        return 0

    log(f"Conectando no Postgres: host={DB_HOST} db={DB_NAME} user={DB_USER}")
    conn = connect()
    conn.autocommit = False

    try:
        ensure_schema(conn)

        for csv_path in csv_files:
            year = extract_year_from_filename(csv_path.name)
            if not year:
                log(f"[SKIP] Arquivo sem ano no nome: {csv_path.name}")
                continue

            log(f"\n=== Importando: {csv_path.name} (year={year}) ===")
            t0 = time.time()

            try:
                # 1) COPY para staging
                staging_count = copy_csv_to_staging(conn, csv_path, year)

                # 2) Processamento set-based
                inserted_valid, inserted_rejected = process_staging_set_based(conn)

                conn.commit()

                t1 = time.time()
                log(
                    f"OK: staging={staging_count} | inserted_valid={inserted_valid} | "
                    f"rejected={inserted_rejected} | elapsed={t1 - t0:.2f}s"
                )

                if ANALYZE_AFTER_EACH_FILE:
                    analyze_tables(conn)
                    log("ANALYZE executado.")

            except Exception as e:
                conn.rollback()
                log(f"[ERRO] Falha importando {csv_path.name}: {e}")
                # Se quiser interromper ao primeiro erro:
                return 2

        log("\nImport finalizado com sucesso.")
        return 0

    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
