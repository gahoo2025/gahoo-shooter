# gahoo-shooter

1942風の縦スクロールシューティングゲーム（個人開発）。

このリポジトリは [gahoo-company](https://github.com/gahoo2025/gahoo-company) の秘書室・`gamedev/`部署が担当するプロジェクトです。企画・仕様検討・作業ログは `gahoo-company/gamedev/` 側に記録されます。実際のコード変更はこちら（`gahoo-shooter`）で行います。

## 技術スタック

- **ゲーム本体**：[Godot](https://godotengine.org/)（Godot 4系を想定）
- **バックエンド**：Node.js + Express
- **データベース**：PostgreSQL

現時点ではシンプルな単人用ゲーム（マルチプレイ・ユーザー認証・ランキングは無し）を想定していますが、将来スコア保存・ランキング等をAPI経由で拡張できるよう、ゲーム本体（クライアント）とバックエンド（API/DB）を分離した構成にしています。

## ディレクトリ構成

```
gahoo-shooter/
├── game/     # Godotプロジェクト（ゲーム本体）
└── server/   # Node.js/Express + PostgreSQL バックエンド
```

## 現在の状況（2026-08-30時点）

初期スキャフォールドのみの状態です。詳細仕様（ステージ構成・敵パターン・自機性能・スコア計算方法等）はこれから策定します。進め方は `gahoo-company/CLAUDE.md`「アプリ開発の基本動作」（①仕様の策定 → ②改修計画の策定 → ③改修の実施）に従います。

## セットアップ（バックエンド）

```bash
cd server
cp .env.example .env   # DB接続情報を設定
npm install
npm run dev
```

`docker-compose up` でPostgreSQLごと起動することもできます（`server/docker-compose.yml`参照）。

## セットアップ（ゲーム本体）

1. [Godot](https://godotengine.org/download) をインストール
2. Godotエディタで `game/project.godot` を開く
3. 詳細は `game/README.md` 参照
