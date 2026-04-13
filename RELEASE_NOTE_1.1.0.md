# QueryStream 1.1.0 Release Note

## 🔧 バグフィックスリリース

QueryStream 1.1.0 は、1.0.0 で報告されたいくつかの問題を修正したバグフィックスリリースです。

## 🐛 修正内容

### 例外クラスの構造化（破壊的変更）

`TemplateNotFoundError` / `DataNotFoundError` が gem 内部でログ出力を行っていた設計を改め、呼び出し元がメッセージを自由に構成できるよう変更しました。

**変更前**: gem 内で `logger.error` を呼び出してからメッセージ文字列のみを raise
**変更後**: 構造化された属性を持つ例外を raise し、ログ出力は呼び出し元の責務とする

```ruby
# TemplateNotFoundError の新しい属性
error.template_path  # 期待されたテンプレートパス
error.query          # 元の QueryStream 記法
error.location       # ソースファイル名と行番号
error.hint           # 修正ヒント（あれば）

# DataNotFoundError の新しい属性
error.expected_path  # 期待されたデータファイルパス
error.query          # 元の QueryStream 記法
error.location       # ソースファイル名と行番号
```

この変更により、i18n 対応やカスタムフォーマットが gem 側の変更なしに可能になります。

### 1行の展開失敗で残りの記法が止まる問題を修正

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

### `Singularize` で大文字 `People` が変換されない問題を修正

`people` パターンの正規表現に `/i` フラグを追加し、`People` → `person` の変換が正しく動作するようになりました。

## ⚠️ 破壊的変更について

`TemplateNotFoundError` / `DataNotFoundError` の例外クラスに属性が追加されました。
`rescue` で `e.message` のみを参照していた場合は引き続き動作しますが、
gem 内のログ出力に依存していた場合は呼び出し元でのログ実装が必要です。

## 📦 アップグレード

```ruby
# Gemfile
gem 'query-stream', '~> 1.1.0'
```

```bash
bundle update query-stream
```

## ✅ テスト品質

- **113 テストケース**
- **439 アサーション**
- 0 failures, 0 errors

---

**QueryStream 1.1.0**: より堅牢なエラーハンドリングと継続展開
