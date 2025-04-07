import { Pool } from "pg";
import dotenv from "dotenv";

dotenv.config();

const isProd = process.env.NODE_ENV === "production";

export const pool = new Pool({
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  host: isProd ? "db" : "localhost", // <== essa é a mágica!
  port: Number(process.env.DB_PORT),
  database: process.env.DB_NAME,
});
