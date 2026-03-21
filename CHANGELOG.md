# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-21

### 🎉 最初のメジャーリリース

QueryStream 1.0.0 としてリリース！YAML/JSON データファイルとテンプレートファイルを組み合わせて、テキストコンテンツ内の QueryStream 記法を展開する汎用 Ruby ライブラリが完成しました。

### ✅ 実績と品質保証
- **vivlio-starter** プロジェクトで実稼働実績
- **109 テストケース**、**395 アサーション**で網羅的品質保証
- **VFM フェンス記法** 完全対応と実用性検証

### 🚀 主要機能
- QueryStream 記法の完全実装（源泉・抽出・ソート・件数・スタイル）
- VFM フェンス記法対応（`:::{.class-name}` 〜 `:::`）
- テンプレートコンパイラ（変数展開、画像記法、ネスト値アクセス）
- 高度なデータ処理（フィルタリング、ソート、単数形化）
- 柔軟な設定システム

### 📚 ドキュメント整備
- 詳細な README と具体例
- 完全な CHANGELOG
- vivlio-style での実装例

### 🔧 技術的特徴
- **Ruby 4.0+** モダン開発標準準拠
- **Semantic Versioning** 準拠
- 後方互換性保証

## [0.3.0] - 2026-03-21

### Added
- VFM フェンス記法対応 (`:::{.class-name}` 〜 `:::`)
- フェンス行が動的行を囲んでいる場合、フェンス行も repeating 範囲に含めて各レコードごとに反復出力
- `{.book-card}`, `{.person-card}` 等の任意 VFM クラス名に汎用的に対応
- フェンス記法関連のテストケースを追加 (12件)
- ファイルドキュメントに VFM フェンス記法対応の説明を追加

### Changed
- `TemplateCompiler` に `FENCE_OPEN_PATTERN` / `FENCE_CLOSE_PATTERN` 定数を追加
- `classify_lines` で `:fence_open` / `:fence_close` タイプを認識
- `expand_fence_range` メソッドを新設し、repeating 範囲の拡張ロジックを実装

### Fixed
- QueryStream と vivlio-starter の VFM フェンス記法の相性問題を解決
- フェンス行が一度しか出力されず、全レコードが1つのフェンスに押し込まれる問題を修正

## [0.2.0] - Previous Release

### Added
- 複数スタイル対応 (`:full`, `:table` 等)
- 高度なフィルタリング機能（範囲指定、不等値比較）
- パフォーマンス最適化
- エラーハンドリングの改善

## [0.1.0] - Initial Release

### Added
- 基本的な QueryStream 記法の実装
  - 源泉指定 (`= books`)
  - フィルタリング (`tags=ruby`, `condition=晴`)
  - ソート (`-title`, `+date`)
  - 件数制限 (`5`)
  - スタイル指定 (`:full`)
- テンプレートコンパイラ機能
  - 変数展開 (`= title`, `= author`)
  - 画像記法の展開 (`![](cover)`)
  - ネストされた値へのアクセス (`= author.name`)
  - テーブル記法対応
- データフィルタリングとソート機能
  - 等値フィルタ (`tags=ruby`)
  - AND/OR 条件 (`tags=ruby && beginner`, `tags=ruby, javascript`)
  - 比較演算子 (`>=`, `<=`, `>`, `<`, `!=`)
- データリゾルバー
  - YAML/JSON ファイルの自動探索
  - 複数形→単数形の自動テンプレート解決
- 単数形化ユーティリティ (Singularize)
  - 英語の複数形パターン対応
  - 不規則名詞 (people → person)
- 設定システム
  - データディレクトリ、テンプレートディレクトリの設定
  - ロガー設定
- エラー処理
  - データファイル不在エラー
  - テンプレートファイル不在エラー
  - 不明キーエラー

---

## [Unreleased]

### Planned
- パフォーマンス最適化
- 追加のテンプレートスタイル
