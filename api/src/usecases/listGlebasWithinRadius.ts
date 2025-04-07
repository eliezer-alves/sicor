import { findGlebasWithinRadius } from "../services/glebaService";

export async function listGlebasWithinRadius(params: {
  lat: number;
  lon: number;
  raio: number;
  ano: number;
}) {
  return await findGlebasWithinRadius(
    params.lat,
    params.lon,
    params.raio,
    params.ano
  );
}
