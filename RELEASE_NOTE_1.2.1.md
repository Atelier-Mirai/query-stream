# QueryStream 1.2.1 リリースノート

## リリース日
2026-04-21

## 概要
QueryStream 1.2.1 は、1.0.0 からのバグフィックスとセキュリティ強化を統合したリリースです。特に YAML データファイルの読み込みにおけるセキュリティ脆弱性を修正し、エラーハンドリングを構造化例外に移行することで、呼び出し元アプリケーション（vivlio-starter 等）での柔軟なエラー処理を可能にしました。

## 主な変更点

### セキュリティ強化
- **`DataResolver.load_records` を `YAML.safe_load_file` に移行** (`lib/query_stream/data_resolver.rb`)
  - 従来は `YAML.load_file(file_path, symbolize_names: true)` を使用しており、Psych のバージョンや将来のアップデートで `!ruby/object` などの Ruby オブジェクトタグが受理されてしまう可能性があった
  - `permitted_classes: [Symbol, Time, Date, DateTime]` と `aliases: true` を明示的に指定する `YAML.safe_load_file` に置き換え、安全性を Psych バージョン非依存にした
  - これにより悪意のあるデータファイル（`!ruby/object:Kernel {}` 等）を読み込ませて任意コード実行を試みる攻撃ベクトルを明示的に塞いだ
  - Symbol が許可されているため `symbolize_names: true` の挙動は従来どおり維持される

### 新規追加
- **`QueryStream::DataLoadError` 新規例外クラス** (`lib/query_stream/errors.rb`)
  - `Psych::DisallowedClass` / `Psych::SyntaxError` / `JSON::ParserError` を呼び出し元に優しいメッセージ付きの `DataLoadError` に変換する
  - `file_path` と `cause_error` 属性を持ち、呼び出し元で詳細なログ出力や i18n が可能

### バグフィックス

#### 1.2.0 からの変更
- **`NoResultWarning` / `AmbiguousQueryWarning` を構造化例外に変更し、gem 内の `logger.warn` 呼び出しを全廃** (`lib/query_stream.rb`, `lib/query_stream/errors.rb`)
  - 1.1.0 で `logger.error` は廃止されていたが、`render_query` の一件検索分岐に `logger.warn` 呼び出しが残存しており、呼び出し元（vivlio-starter 等）が `⚠️` プレフィックスや i18n を付与できない問題があった
  - `NoResultWarning` / `AmbiguousQueryWarning` に `query` / `location` （ambiguous は `count` も）属性を追加し、`logger.warn` 呼び出しを削除
  - 新たに `QueryStream.render` / `render_query` に `on_warning:` コールバックを追加し、警告情報を構造化例外として呼び出し元へ委譲する
  - これにより gem 内のログ出力が完全になくなり、メッセージ構成・ログ出力・i18n はすべて呼び出し元の責務となった

#### 1.1.0 からの変更
- **`TemplateNotFoundError` / `DataNotFoundError` を構造化例外に変更** (`lib/query_stream.rb`, `lib/query_stream/errors.rb`)
  - 従来は `render_query` 内で `logger.error` によるログ出力を行ってから例外を raise していた
  - 呼び出し元がメッセージフォーマットや言語（i18n）を制御できないため、gem 内のログ出力を廃止
  - 例外クラスに `template_path`, `query`, `location`, `hint` （`DataNotFoundError` は `expected_path`, `query`, `location`）の属性を追加
  - メッセージ構成・ログ出力・i18n はすべて呼び出し元の責務とした

- **`render` 内で展開エラーをキャッチして後続の記法を継続展開するよう変更** (`lib/query_stream.rb`)
  - 従来は1行の展開失敗で `render` 全体が中断されていた
  - `render_query` の呼び出しを `rescue Error` で囲み、失敗した行は元の記法のまま残して後続の QueryStream 記法の展開を継続するよう修正
  - `on_error` コールバックを追加し、エラー情報を呼び出し元に通知できるようにした

- **`Singularize` で `People`（大文字）が `person` に変換されない問題を修正** (`lib/query_stream/singularize.rb`)
  - `people` パターンの正規表現に `/i` フラグを追加し、大文字小文字を問わず変換できるようにした

### テスト
- **セキュリティテスト 7 件を追加** (`test/query_stream_test.rb`)
  - `!ruby/object:Object {}` を含む YAML は `DataLoadError` で拒否
  - `!ruby/struct:Point` / `!ruby/hash:MyCustomHash` も同様に拒否
  - Symbol / Time / Date / DateTime は正常に読み込める
  - YAML / JSON 構文エラーは `DataLoadError` に変換される
  - 通常の YAML anchor / alias は正常に展開される（DoS 耐性の副次確認）

## アップグレード方法

### Gemfile の更新
```ruby
gem 'query-stream', '~> 1.2.1'
```

### bundle update の実行
```bash
bundle update query-stream
```

## 互換性
- 後方互換性は維持されています
- 呼び出し元で `on_warning:` コールバックを使用する場合、コールバックのシグネチャに注意してください
- `YAML.safe_load_file` の導入により、従来許可されていた `!ruby/object` 等のタグは明示的に拒否されるようになりました

## 既知の問題
なし

## 次期リリース予定
- パフォーマンス最適化
- 追加のテンプレートスタイル

## 謝辞
このリリースには、vivlio-starter プロジェクトでの実稼働実績に基づくフィードバックが反映されています。
