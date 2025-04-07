import { pool } from "../infra/db";
import { Gleba } from "../types/Gleba";

export async function findGlebasWithinRadius(
  lat: number,
  lon: number,
  raio: number,
  ano: number
): Promise<Gleba[]> {
  const result = await pool.query(
    `SELECT ref_bacen, order_number, index_number, year, geojson
     FROM glebas
     WHERE year = $1
       AND ST_DWithin(
         geom::geography,
         ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography,
         $4
       )`,
    [ano, lon, lat, raio]
  );

  return result.rows.map((row) => ({
    ...row,
    geojson:
      typeof row.geojson === "string" ? JSON.parse(row.geojson) : row.geojson,
  }));
}
