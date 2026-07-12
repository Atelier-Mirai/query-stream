# QueryStream 1.3.0 リリースノート

## リリース日
2026-07-12

## 概要
QueryStream 1.3.0 は、展開結果を呼び出し元へ引き渡す汎用の後段フィルタ `post_render` コールバックを追加したリリースです。gem 自身は用途を規定せず、展開後のテキストを「コンテキスト付き」で呼び出し元に委ねることで、画像パス解決などの呼び出し元固有の後処理を柔軟に差し込めるようになりました。既存の `on_error:` / `on_warning:` と同じく任意パラメータであり、後方互換性は完全に維持されています。

## 主な変更点

### 新規追加

- **`post_render` 後段フィルタコールバックを追加** (`lib/query_stream.rb`, `lib/query_stream/configuration.rb`)
  - 1 記法の展開結果を、コンテキスト付きで呼び出し元へ通す汎用フックを新設
  - `QueryStream.render` / `QueryStream.render_query` に `post_render:` キーワードを追加。`Configuration#post_render` からも指定可能
  - コールバックは `(text, context)` を受け取る。`context` は次のキーを含む Hash:
    - `source` — 記法に書かれた論理名（例: `"physics_book"`）
    - `data_file` — 単複解決後の実データファイルパス（例: `"data/physics_books.yml"`）
    - `data_dir` — データディレクトリ
    - `template_path` — 解決されたテンプレートのパス
    - `query` — 元の記法文字列
    - `location` — `"filename:line"` 形式の位置情報
  - 戻り値が `String` ならそれを採用し、`String` 以外（`nil` を含む）なら元の展開結果を安全側で採用する
  - gem 自身は用途を規定せず、画像パス解決などの呼び出し元固有の後処理を委譲できる
  - コールバック内の例外は握り潰さず伝播する（`render` の既存 rescue は `QueryStream::Error` のみを捕捉するため、それ以外の後処理例外の扱いは呼び出し元の責務）

### テスト
- `post_render` コールバックのテスト 5 件を追加（展開結果とコンテキスト全キーの受け渡し・`String` 戻り値の採用・非 `String` 戻り値時の元テキストへのフォールバック・`configuration` 経路・記法が無い行では未呼び出し）
- 全 125 テストケース、486 アサーションで品質保証

## 利用例

```ruby
QueryStream.render(
  content,
  data_dir: 'data',
  templates_dir: 'templates',
  post_render: lambda do |text, context|
    # 展開結果 text と、そのデータ由来の context を用いた後処理を行う。
    # 例: data_file の基底名を手がかりに、text 内の画像参照を解決する。
    MyImageResolver.rewrite(text, context)
  end
)
```

## アップグレード方法

```ruby
# Gemfile
gem 'query-stream', '~> 1.3'
```

```bash
bundle update query-stream
```

## 互換性
- 1.0.0 からの後方互換性は維持されています
- `post_render:` は任意パラメータであり、指定しなければ従来どおりの挙動になります（既存コードへの影響はありません）
- `on_error:` / `on_warning:` コールバックの挙動に変更はありません

## 謝辞
このリリースには、vivlio-starter プロジェクトでの実稼働実績に基づくフィードバックが反映されています。`post_render` は、QueryStream のデータ用画像を `data/` 配下に同居させる機能の実装過程で、gem に画像固有の知識を持ち込まずに拡張するための汎用フックとして設計されました。
