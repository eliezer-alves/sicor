import { FastifyInstance } from "fastify";
import swagger from "@fastify/swagger";
import swaggerUI from "@fastify/swagger-ui";

export default async function swaggerConfig(app: FastifyInstance) {
  await app.register(swagger, {
    openapi: {
      info: {
        title: "GeoAPI",
        description: "Documentação da API de Glebas do SICOR",
        version: "1.0.0",
      },
      servers: [
        {
          url: "http://localhost:3000",
          description: "Local dev",
        },
      ],
    },
  });

  await app.register(swaggerUI, {
    routePrefix: "/docs",
  });
}
