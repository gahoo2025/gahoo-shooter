import express from "express";
import "dotenv/config";
import { pool } from "./db.js";

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;

// 死活監視用エンドポイント
app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

// DB接続確認用エンドポイント（初期スキャフォールドの動作確認用）
app.get("/health/db", async (_req, res) => {
  try {
    const result = await pool.query("SELECT NOW()");
    res.json({ status: "ok", now: result.rows[0].now });
  } catch (err) {
    res.status(500).json({ status: "error", message: err.message });
  }
});

// TODO: ゲーム機能のAPI（スコア保存等）は詳細仕様策定後に追加する

app.listen(PORT, () => {
  console.log(`gahoo-shooter server listening on port ${PORT}`);
});
