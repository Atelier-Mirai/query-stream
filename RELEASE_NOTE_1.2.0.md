# QueryStream 1.2.0 Release Note

## 🔧 バグフィックスリリース

QueryStream 1.2.0 は、1.1.0 で残っていた警告メッセージのログ出力を完全に排除し、呼び出し元がメッセージを自由に構成できるよう変更したバグフィックスリリースです。

## 🐛 修正内容

### 警告例外クラスの構造化

1.1.0 で `logger.error` は廃止されていましたが、一件検索の警告メッセージに `logger.warn` が残存しており、呼び出し元が `⚠️` プレフィックスや i18n を付与できない問題がありました。これを解消するため、`NoResultWarning` / `AmbiguousQueryWarning` に構造化された属性を追加し、`logger.warn` 呼び出しを削除しました。

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

### `on_warning` コールバックの追加

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

## ⚠️ 破壊的変更について

`NoResultWarning` / `AmbiguousQueryWarning` の例外クラスに属性が追加されました。
これらの例外は内部でのみ使用されていたため、呼び出し元への影響はありません。

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
