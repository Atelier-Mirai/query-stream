# QueryStream 1.2.0 Release Note

## 🔧 バグフィックスリリース

QueryStream 1.2.0 は、1.0.0 からの累積変更を含むバグフィックスリリースです。
エラーハンドリングの改善と継続展開のサポート（1.1.0）、および警告メッセージのログ出力排除（1.2.0）を行いました。

## 🐛 修正内容

### 1.2.0: 警告例外クラスの構造化

一件検索の警告メッセージに `logger.warn` が残存しており、呼び出し元が `⚠️` プレフィックスや i18n を付与できない問題がありました。これを解消するため、`NoResultWarning` / `AmbiguousQueryWarning` に構造化された属性を追加し、`logger.warn` 呼び出しを削除しました。

**変更前**: gem 内で `logger.warn("一件検索で該当なし(…): …")` を呼び出してから空文字列を返す
**変更後**: 構造化された属性を持つ警告を `on_warning` コールバック経由で呼び出し元に委譲

```ruby
# NoResultWarning の新しい属性
warning.query     # 元の QueryStream 記法
warning.location  # ソースファイル名と行番号

# AmbiguousQueryWarning の新しい属性
warning.query     # 元の QueryStream 記法
warning.location  # ソースファイル名と行番号
warning.count     # ヒット件数
```

### 1.2.0: `on_warning` コールバックの追加

`QueryStream.render` / `render_query` に `on_warning` コールバックを追加し、警告情報を構造化例外として呼び出し元へ委譲するようにしました。

```ruby
QueryStream.render(
  content,
  on_warning: ->(w) {
    puts "⚠️ QueryStream 一件検索: 該当レコードが見つかりません"
    puts "   記法: #{w.query} (#{w.location})"
  }
)
```

この変更により、gem 内のログ出力が完全になくなり、メッセージ構成・ログ出力・i18n はすべて呼び出し元の責務となりました。

### 1.1.0: 例外クラスの構造化

`TemplateNotFoundError` / `DataNotFoundError` が gem 内部でログ出力を行っていた設計を改め、呼び出し元がメッセージを自由に構成できるよう変更しました。

**変更前**: gem 内で `logger.error` を呼び出してからメッセージ文字列のみを raise
**変更後**: 構造化された属性を持つ例外を raise し、ログ出力は呼び出し元の責務とする

```ruby
# TemplateNotFoundError の属性
error.template_path  # 期待されたテンプレートパス
error.query          # 元の QueryStream 記法
error.location       # ソースファイル名と行番号
error.hint           # 修正ヒント（あれば）

# DataNotFoundError の属性
error.expected_path  # 期待されたデータファイルパス
error.query          # 元の QueryStream 記法
error.location       # ソースファイル名と行番号
```

### 1.1.0: 1行の展開失敗で残りの記法が止まる問題を修正

`render` メソッド内で `render_query` の例外をキャッチし、失敗した行は元の記法のまま残して後続の展開を継続するよう変更しました。

```markdown
= books | :full      ← 正常に展開される
= books | :typo      ← テンプレート不在でも元の行が残り、次の行へ継続
= prefectures        ← 正常に展開される
```

`on_error` コールバックを追加し、エラー情報を呼び出し元に通知できるようにしました。

```ruby
QueryStream.render(content, on_error: ->(e) { puts e.message })
```

### 1.1.0: `Singularize` で大文字 `People` が変換されない問題を修正

`people` パターンの正規表現に `/i` フラグを追加し、`People` → `person` の変換が正しく動作するようになりました。

## ⚠️ 破壊的変更について

1.1.0 で `TemplateNotFoundError` / `DataNotFoundError` の例外クラスに属性が追加されました。`rescue` で `e.message` のみを参照していた場合は引き続き動作しますが、gem 内のログ出力に依存していた場合は呼び出し元でのログ実装が必要です。

1.2.0 で `NoResultWarning` / `AmbiguousQueryWarning` の例外クラスに属性が追加されました。これらの例外は内部でのみ使用されていたため、呼び出し元への影響はありません。

## 📦 アップグレード

```ruby
# Gemfile
gem 'query-stream', '~> 1.2.0'
```

```bash
bundle update query-stream
```

## ✅ テスト品質

- **113 テストケース**
- **439 アサーション**
- 0 failures, 0 errors

---

**QueryStream 1.2.0**: gem 内ログ出力の完全排除と警告メッセージのカスタマイズ性向上
