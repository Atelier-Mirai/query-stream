# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


### Planned
- パフォーマンス最適化
- 追加のテンプレートスタイル

## [Unreleased]

## [1.2.1] - 2026-04-20

### Security
- **`DataResolver.load_records` を `YAML.safe_load_file` に移行** (`lib/query_stream/data_resolver.rb`):
  従来は `YAML.load_file(file_path, symbolize_names: true)` を使用しており、Psych のバージョンや将来のアップデートで `!ruby/object` などの Ruby オブジェクトタグが受理されてしまう可能性があった。
  `permitted_classes: [Symbol, Time, Date, DateTime]` と `aliases: true` を明示的に指定する `YAML.safe_load_file` に置き換え、安全性を Psych バージョン非依存にした。
  これにより悪意のあるデータファイル（`!ruby/object:Kernel {}` 等）を読み込ませて任意コード実行を試みる攻撃ベクトルを明示的に塞いだ。
  なお Symbol が許可されているため `symbolize_names: true` の挙動は従来どおり維持される。

### Added
- **`QueryStream::DataLoadError` 新規例外クラス** (`lib/query_stream/errors.rb`):
  `Psych::DisallowedClass` / `Psych::SyntaxError` / `JSON::ParserError` を呼び出し元に優しいメッセージ付きの `DataLoadError` に変換する。
  `file_path` と `cause_error` 属性を持ち、呼び出し元で詳細なログ出力や i18n が可能。

### Tests
- **セキュリティテスト 7 件を追加** (`test/query_stream_test.rb`):
  - `!ruby/object:Object {}` を含む YAML は `DataLoadError` で拒否
  - `!ruby/struct:Point` / `!ruby/hash:MyCustomHash` も同様に拒否
  - Symbol / Time / Date / DateTime は正常に読み込める
  - YAML / JSON 構文エラーは `DataLoadError` に変換される
  - 通常の YAML anchor / alias は正常に展開される（DoS 耐性の副次確認）

## [1.2.0] - 2026-04-19

### Fixed
- **`NoResultWarning` / `AmbiguousQueryWarning` を構造化例外に変更し、gem 内の `logger.warn` 呼び出しを全廃** (`lib/query_stream.rb`, `lib/query_stream/errors.rb`): 1.1.0 で `logger.error` は廃止されていたが、`render_query` の一件検索分岐に `logger.warn("一件検索で該当なし(…): …")` / `logger.warn("一件検索で複数件ヒット(…): …")` が残存しており、呼び出し元（vivlio-starter 等）が `⚠️` プレフィックスや i18n を付与できない問題があった。`NoResultWarning` / `AmbiguousQueryWarning` に `query` / `location` （ambiguous は `count` も）属性を追加し、`logger.warn` 呼び出しを削除。新たに `QueryStream.render` / `render_query` に `on_warning:` コールバックを追加し、警告情報を構造化例外として呼び出し元へ委譲する。これにより gem 内のログ出力が完全になくなり、メッセージ構成・ログ出力・i18n はすべて呼び出し元の責務となった。

## [1.1.0] - 2026-04-13

### Fixed

- **`TemplateNotFoundError` / `DataNotFoundError` を構造化例外に変更** (`lib/query_stream.rb`, `lib/query_stream/errors.rb`):
  従来は `render_query` 内で `logger.error` によるログ出力を行ってから例外を raise していた。
  これでは呼び出し元がメッセージフォーマットや言語（i18n）を制御できないため、
  gem 内のログ出力を廃止し、例外クラスに `template_path`, `query`, `location`, `hint`
  （`DataNotFoundError` は `expected_path`, `query`, `location`）の属性を追加。
  メッセージ構成・ログ出力・i18n はすべて呼び出し元の責務とした。

- **`render` 内で展開エラーをキャッチして後続の記法を継続展開するよう変更** (`lib/query_stream.rb`):
  従来は1行の展開失敗で `render` 全体が中断されていた。
  `render_query` の呼び出しを `rescue Error` で囲み、失敗した行は元の記法のまま残して
  後続の QueryStream 記法の展開を継続するよう修正。
  `on_error` コールバックを追加し、エラー情報を呼び出し元に通知できるようにした。

- **`Singularize` で `People`（大文字）が `person` に変換されない問題を修正** (`lib/query_stream/singularize.rb`):
  `people` パターンの正規表現に `/i` フラグを追加し、大文字小文字を問わず変換できるようにした。

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
