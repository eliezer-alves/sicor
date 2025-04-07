import Fastify from "fastify";
import glebasRoutes from "./routes/glebas";
import swagger from "./swagger";

const app = Fastify();

swagger(app);

app.register(glebasRoutes, { prefix: "/glebas" });

app.listen({ port: 3000 }, (err, address) => {
  if (err) {
    console.error(err);
    process.exit(1);
  }
  console.log(`✨ API rodando em ${address}`);
});
