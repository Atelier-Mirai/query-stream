# QueryStream 1.2.2 リリースノート

## リリース日
2026-04-26

## 概要
QueryStream 1.2.2 は、1.0.0 からのバグフィックス、セキュリティ強化、エラーハンドリングの構造化を統合したリリースです。YAML データファイルの読み込みにおけるセキュリティ脆弱性の修正、構造化例外への移行による呼び出し元での柔軟なエラー処理、そしてアンダースコア付き複合名の単数形変換の不具合修正を含みます。

## 主な変更点

### セキュリティ強化（1.2.1）
- **`DataResolver.load_records` を `YAML.safe_load_file` に移行**
  - `!ruby/object` 等の Ruby オブジェクトタグを明示的に拒否し、任意コード実行の攻撃ベクトルを塞いだ
  - `permitted_classes: [Symbol, Time, Date, DateTime]` と `aliases: true` を明示的に指定
  - `symbolize_names: true` の挙動は従来どおり維持

### バグフィックス

#### 1.2.2 での修正
- **アンダースコア付き複合名の単数形変換が誤る問題を修正** (`lib/query_stream/singularize.rb`)
  - `physics_books` が `physic_books` に変換されていた問題を修正
  - アンダースコアで分割し、末尾から複数形セグメントを探して単数化するよう変更
  - `people` は不規則変化として優先処理
  - `physics_books` → `physics_book`、`books_nested` → `book_nested` が正しく変換されるようになった

#### 1.2.0 での修正
- **`NoResultWarning` / `AmbiguousQueryWarning` を構造化例外に変更し、gem 内の `logger.warn` 呼び出しを全廃**
  - `on_warning:` コールバックを追加し、警告情報を構造化例外として呼び出し元へ委譲
  - gem 内のログ出力が完全になくなり、メッセージ構成・ログ出力・i18n はすべて呼び出し元の責務に

#### 1.1.0 での修正
- **`TemplateNotFoundError` / `DataNotFoundError` を構造化例外に変更**
  - 例外クラスに `template_path`, `query`, `location`, `hint` 等の属性を追加
  - `on_error` コールバックを追加し、展開エラー時も後続の記法を継続展開するよう変更
- **`Singularize` で `People`（大文字）が `person` に変換されない問題を修正**

### 新規追加（1.2.1）
- **`QueryStream::DataLoadError` 新規例外クラス**
  - `Psych::DisallowedClass` / `Psych::SyntaxError` / `JSON::ParserError` を呼び出し元に優しいメッセージ付きの `DataLoadError` に変換
  - `file_path` と `cause_error` 属性を持ち、詳細なログ出力や i18n が可能

### テスト
- セキュリティテスト 7 件を追加（悪意のある YAML タグの拒否、構文エラーの変換、anchor/alias の正常展開）
- 全 120 テストケース、467 アサーションで品質保証

## アップグレード方法

```ruby
# Gemfile
gem 'query-stream', '~> 1.2.2'
```

```bash
bundle update query-stream
```

## 互換性
- 1.0.0 からの後方互換性は維持されています
- `on_error:` / `on_warning:` コールバックは任意パラメータであり、既存コードへの影響はありません
- `YAML.safe_load_file` の導入により、`!ruby/object` 等のタグは明示的に拒否されます

## 謝辞
このリリースには、vivlio-starter プロジェクトでの実稼働実績に基づくフィードバックが反映されています。
