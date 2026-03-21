# QueryStream 1.0.0 Release Note

## 🎉 最初のメジャーリリース

QueryStream 1.0.0 をリリースできることを大変嬉しく思います。これは YAML/JSON データファイルとテンプレートファイルを組み合わせて、テキストコンテンツ内の QueryStream 記法を展開する汎用 Ruby ライブラリです。

## 🚀 主要機能

### QueryStream 記法
```
= [源泉] | [抽出条件] | [ソート] | [件数] | [スタイル]
```

- **源泉指定**: `= books`, `= book | タイトル`
- **フィルタリング**: `tags=ruby`, `condition=晴`
- **ソート**: `-title`, `+date`
- **件数制限**: `5`
- **スタイル指定**: `:full`, `:table`, `:card`

### VFM フェンス記法対応 🆕
- `:::{.class-name}` 〜 `:::` 形式のフェンス記法を完全サポート
- 各レコードが個別のフェンスで囲まれて展開
- vivlio-starter との連携で書籍カード等の生成に最適

### テンプレート機能
- 変数展開: `=title`, `=author.name`
- 画像記法: `![](cover)`
- ネストされた値へのアクセス
- テーブル記法対応

### データ処理
- YAML/JSON ファイルの自動探索
- 複数形→単数形の自動テンプレート解決
- 高度なフィルタリング（AND/OR、比較演算子）
- 柔軟なソート機能

## 📦 インストール

```ruby
# Gemfile
gem 'query-stream', '~> 1.0.0'
```

```bash
bundle install
```

## 💡 使用例

### vivlio-style での書籍データ展開

#### データファイル (`data/books.yml`)
```yaml
- title: 楽しいRuby
  author: 
    name: 高橋征義
  desc: Rubyを楽しく学べる入門書。
  cover: ruby.webp
```

#### テンプレート (`templates/_book.md`)
```markdown
:::{.book-card}
![](cover)
**=title**
=desc
:::
```

#### Markdown記述
```markdown
## 参考書籍
= books
```

#### 展開結果
```markdown
## 参考書籍

:::{.book-card}
![](ruby.webp)
**楽しいRuby**
Rubyを楽しく学べる入門書。
:::
```

## 🔧 設定

```ruby
QueryStream.configure do |config|
  config.data_dir       = 'data'
  config.templates_dir  = 'templates'
  config.default_format = :md
  config.logger         = Logger.new($stdout)
end
```

## ✅ テスト品質

- **109 テストケース**
- **395 アサーション**
- **網羅的カバレッジ**
- **VFM フェンス記法対応テスト完備**

## 🔄 0.3.0 からの変更点

### 新機能
- VFM フェンス記法完全対応
- フェンス行の repeating 範囲拡張
- 汎用的な VFM クラス名対応

### 改善
- テストカバレッジ向上
- ドキュメント整備
- エラーハンドリング強化

## 🎯 実績

- **vivlio-starter** プロジェクトで実稼働
- **VFM フェンス記法** との相性問題を完全解決
- **Ruby 4.0+** モダン開発標準に準拠

## 📋 互換性

- **Ruby**: 4.0+
- **依存**: logger, samovar (~> 2.1)
- **セマンティックバージョニング**: 1.x.x 系は後方互換性を保証

## 🙏 感謝

QueryStream の開発にあたり、vivlio-starter プロジェクトでの実使用経験が大きな助けとなりました。特に VFM フェンス記法との連携についてのフィードバックは、本ライブラリをより実用的なものにする上で不可欠でした。

---

**QueryStream 1.0.0**: データ駆動コンテンツ生成の新たな標準
