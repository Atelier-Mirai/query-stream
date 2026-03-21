# QueryStream

YAML/JSON データファイルとテンプレートファイルを組み合わせて、テキストコンテンツ内の QueryStream 記法を展開する汎用 Ruby ライブラリ。

## インストール

```ruby
# Gemfile
gem 'query-stream'
```

```bash
bundle install
```

## 基本的な使い方

```ruby
require 'query_stream'

# テキスト内の QueryStream 記法を展開
source = File.read('contents/05-references.md')
result = QueryStream.render(source)
```

## QueryStream 記法

```
= [源泉] | [抽出条件] | [ソート] | [件数] | [スタイル]
```

### 例

```
= books                           # 全件展開
= books | tags=ruby               # タグで絞り込み
= books | tags=ruby | -title | 5  # 絞り込み＋降順ソート＋5件
= book | 楽しいRuby               # 主キーで一件検索
= books | :full                   # fullスタイルで展開
```

### 具体例：vivlio-style での書籍データ展開

#### データファイル例 (`data/books.yml`)

```yaml
- title: 楽しいRuby
  author: 
    name: 高橋征義
  desc: Rubyを楽しく学べる入門書。
  cover: ruby.webp

- title: はじめてのC
  author: 
    name: 柴田望洋
  desc: C言語の定番入門書。
  cover: c.webp
```

#### テンプレートファイル例 (`templates/_book.md`)

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

---
```

#### 展開結果

```markdown
## 参考書籍

:::{.book-card}
![](ruby.webp)
**楽しいRuby**
Rubyを楽しく学べる入門書。
:::

:::{.book-card}
![](c.webp)
**はじめてのC**
C言語の定番入門書。
:::

---
```

VFMフェンス記法（`:::{.book-card}`）にも対応しており、各レコードが個別のフェンスで囲まれて展開されます。

## 設定

```ruby
QueryStream.configure do |config|
  config.data_dir       = 'data'
  config.templates_dir  = 'templates'
  config.default_format = :md
  config.logger         = Logger.new($stdout)
end
```

## ライセンス

MIT License
