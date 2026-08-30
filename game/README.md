# game/（Godotプロジェクト）

gahoo-shooterのゲーム本体。[Godot](https://godotengine.org/) 4系を想定。

## 開き方

1. [Godot](https://godotengine.org/download) をインストール（4.3以降推奨）
2. Godotエディタの「Import」からこのフォルダ内の `project.godot` を選択して開く

## 現在の状況

初期スキャフォールドのみ（空のメインシーン `scenes/main.tscn` と `scripts/main.gd` のみ）。詳細仕様策定後、以下を実装していく想定。

- 自機（プレイヤー機）の移動・弾発射
- 敵機の出現パターン・弾幕
- スクロール背景（縦スクロール）
- スコア計算・表示
- ステージ構成・ボス

## 構成

```
game/
├── project.godot
├── scenes/     # シーンファイル（.tscn）
├── scripts/    # GDScript（.gd）
└── assets/     # 画像・音声等（今後追加）
```
