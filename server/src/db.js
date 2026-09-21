import pg from "pg";
import "dotenv/config";

const { Pool } = pg;

// DATABASE_URL 形式（例: postgres://user:password@localhost:5432/gahoo_shooter）
// を優先し、無ければ個別の環境変数から組み立てる。
export const pool = new Pool(
  process.env.DATABASE_URL
    ? { connectionString: process.env.DATABASE_URL }
    : {
        host: process.env.PGHOST || "localhost",
        port: Number(process.env.PGPORT) || 5432,
        user: process.env.PGUSER || "postgres",
        password: process.env.PGPASSWORD || "postgres",
        database: process.env.PGDATABASE || "gahoo_shooter",
      }
);
