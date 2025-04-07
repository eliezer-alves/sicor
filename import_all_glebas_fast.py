import os
import re
import pandas as pd
import psycopg2
from psycopg2 import sql
from shapely import wkt as shapely_wkt
from shapely.errors import ShapelyError

# Configurações do banco
DB_USER = "postgres"
DB_PASS = "postgres"
DB_HOST = "db"
DB_PORT = "5432"
DB_NAME = "geoapi"

INPUT_DIR = "input"

def extract_year_from_filename(filename):
    match = re.search(r"(\d{4})", filename)
    return int(match.group(1)) if match else None

def copy_to_staging(csv_path, year, conn):
    # 🔄 Limpa staging antes de cada importação
    clear_staging(conn)
    print(f"\n📂 Processando: {csv_path}")
    print(f"📅 Ano extraído: {year}")
    
    df = pd.read_csv(csv_path, sep=';', dtype=str)
    print(f"🧾 Linhas no CSV: {len(df)}")
    print(f"🧠 Colunas antes do rename: {df.columns.tolist()}")

    try:
        df.rename(columns={
            "REF_BACEN": "ref_bacen",
            "NU_ORDEM": "order_number",
            "NU_INDICE": "index_number",
            "GT_GEOMETRIA": "wkt"
        }, inplace=True)

        df["year"] = year

        # 🔍 Validação dos WKTs com Shapely
        valid_rows = []
        invalid_count = 0
        for _, row in df.iterrows():
            try:
                _ = shapely_wkt.loads(row["wkt"])
                valid_rows.append(row)
            except ShapelyError:
                invalid_count += 1

        df = pd.DataFrame(valid_rows)
        print(f"🧪 Geometrias válidas: {len(df)}")
        print(f"⚠️ Geometrias descartadas por WKT inválido: {invalid_count}")

        temp_csv = "/tmp/temp_glebas.csv"
        df[["ref_bacen", "order_number", "index_number", "wkt", "year"]].to_csv(temp_csv, index=False, header=False)

        print("📤 Exportando para CSV temporário... OK")

        with conn.cursor() as cur, open(temp_csv, 'r') as f:
            cur.copy_expert(
                sql.SQL("COPY glebas_staging (ref_bacen, order_number, index_number, wkt, year) FROM STDIN WITH (FORMAT CSV)"),
                f
            )
        conn.commit()
        print(f"✅ Dados copiados para staging ({len(df)} linhas).")
    
    except Exception as e:
        print(f"❌ Erro durante importação: {e}")

def process_staging(conn):
    print("⚙️ Processando dados da staging para a tabela final...")
    print("🔍 Aplicando filtro ST_IsValid() nas geometrias...")

    with conn.cursor() as cur:
        # Mostra quantas inválidas o PostGIS rejeitaria
        cur.execute("""
            SELECT COUNT(*) 
            FROM glebas_staging 
            WHERE NOT ST_IsValid(ST_GeomFromText(wkt, 4326));
        """)
        invalid_count = cur.fetchone()[0]
        print(f"⚠️ Geometrias inválidas no PostGIS: {invalid_count}")

        # Usando CTE para evitar que ST_GeomFromText quebre
        cur.execute("""
            WITH valid_geoms AS (
                SELECT
                    ref_bacen,
                    order_number,
                    index_number,
                    year,
                    wkt,
                    ST_GeomFromText(wkt, 4326) AS geom
                FROM glebas_staging
                WHERE ST_IsValid(ST_GeomFromText(wkt, 4326))
            )
            INSERT INTO glebas (
                ref_bacen,
                order_number,
                index_number,
                year,
                wkt,
                geom,
                kml,
                geojson
            )
            SELECT
                ref_bacen,
                order_number,
                index_number,
                year,
                wkt,
                geom,
                ST_AsKML(geom),
                json_build_object(
                    'type', 'Feature',
                    'geometry', ST_AsGeoJSON(geom)::json,
                    'properties', json_build_object(
                        'ref_bacen', ref_bacen,
                        'order_number', order_number,
                        'index_number', index_number,
                        'year', year
                    )
                )
            FROM valid_geoms;
        """)
        conn.commit()

    print("🏁 Dados processados e inseridos na tabela final.")

def clear_staging(conn):
    with conn.cursor() as cur:
        cur.execute("TRUNCATE glebas_staging;")
        conn.commit()

def main():
    print("🧠 Iniciando importação de arquivos...")
    conn = psycopg2.connect(
        dbname=DB_NAME, user=DB_USER, password=DB_PASS, host=DB_HOST, port=DB_PORT
    )

    for filename in os.listdir(INPUT_DIR):
        if filename.endswith(".csv"):
            year = extract_year_from_filename(filename)
            if year:
                file_path = os.path.join(INPUT_DIR, filename)
                copy_to_staging(file_path, year, conn)
                process_staging(conn)
            else:
                print(f"⚠️ Ignorando arquivo sem ano no nome: {filename}")
    
    conn.close()
    print("🎉 Importação completa!")

if __name__ == "__main__":
    main()
