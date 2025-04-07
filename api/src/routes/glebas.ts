import { FastifyInstance } from "fastify";
import { listGlebasWithinRadius } from "../usecases/listGlebasWithinRadius";

export default async function routes(app: FastifyInstance) {
  app.get(
    "/",
    {
      schema: {
        querystring: {
          type: "object",
          required: ["lat", "lon", "raio", "ano"],
          properties: {
            lat: { type: "number" },
            lon: { type: "number" },
            raio: { type: "number" },
            ano: { type: "number" },
          },
        },
        // response: {
        //   200: {
        //     type: "object",
        //     properties: {
        //       type: { type: "string" },
        //       features: { type: "array", items: { type: "object" } },
        //     },
        //   },
        // },
      },
    },
    async (request, reply) => {
      const { lat, lon, raio, ano } = request.query as any;
      const glebas = await listGlebasWithinRadius({ lat, lon, raio, ano });

      reply.send({
        type: "FeatureCollection",
        features: glebas.map((g) => g.geojson),
      });
    }
  );
}
