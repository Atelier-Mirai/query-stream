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

Ruby 3.4 以上が必要です。

## 基本的な使い方

```ruby
require 'query_stream'

# テキスト内の QueryStream 記法を展開
source = File.read('contents/05-references.md')
result = QueryStream.render(source, data_dir: 'data', templates_dir: 'templates')
```

`data_dir` / `templates_dir` は後述の `configure` で既定値を決めておけば省略できます。

## QueryStream 記法

```
= [源泉] | [抽出条件] | [ソート] | [件数] | [スタイル]
```

### 例

```
= books                           # 全件展開
= books | tags=ruby               # タグで絞り込み
= books | +title                  # タイトルの昇順
= books | -year                   # 発行年の降順
= books | tags=ruby | -title | 5  # 絞り込み＋降順ソート＋5件
= prefectures | population>=9_000_000  # 数は _ で桁を区切れる（900_0000 も可）
= weather_reports | date>=R06-01-01    # 日付は西暦（2024-01-01）でも和暦でも書ける
= book | 楽しいRuby               # 主キーで一件検索
= books | :full                   # fullスタイルで展開
```

**ソートには符号を必ず付けてください**（`+` が昇順、`-` が降順）。符号を省いた
`= books | title` はソートではなく**主キー検索**として扱われ、該当なしの警告とともに
何も展開されません。`= book | 楽しいRuby` のような一件検索と綴りが同じになるため、
符号の有無で見分けています。

日付は、データでも抽出条件でも `2024-01-01`（西暦）か `R06-01-01`（和暦）で書きます。
和暦の元号は頭文字で書き（`M` 明治・`T` 大正・`S` 昭和・`H` 平成・`R` 令和）、年は 1 桁でも
構いません（`R6-01-01`）。どちらで書いても同じ日付として比べ、並べ替えます。

### 具体例：Vivlio Starter での書籍データ展開

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

### 値の無い項目

値が無い（キーが無い・空の）項目を含む行は、行ごと出力しません。項目によって情報量の
違うデータにも、同じテンプレートが使えます。

1 行に変数が 2 つ以上ある行では、**値の無い項目の部分だけ**を消します。行は区切り
（`／`・`・`・`、`・`，`・`,` と、前後に空白のある ` / `）と、変数を含む括弧（`（…）`・`(…)`）で
部品に分かれ、値の無い変数を含む部品だけが、区切りを詰めて消えます。変数に付いた言葉
（`著`・`年`）は、変数と一緒に残るか、一緒に消えます。

```markdown
= author.name 著／= publisher／= year 年
= author.name 著（= year年）
```

| データ | 1 行目 | 2 行目 |
|---|---|---|
| 全部ある | 高橋征義 著／SBクリエイティブ／2019 年 | 高橋征義 著（2019年） |
| 発行年が無い | 高橋征義 著／SBクリエイティブ | 高橋征義 著 |
| 全部無い | （行ごと消える） | （行ごと消える） |

- 行頭の箇条書きの `- ` や見出しの `# ` は、先頭の部品が消えても残ります。
- 表の行（`|` で始まる行）は部品に分けず、値の無い項目があれば行ごと消えます（セルを消すと列がずれるため）。
- 空白なしの半角の `/` と、リンク先の括弧（`[= title](= url)`）は区切りになりません。
- テンプレートのキーは、どれか 1 件のデータにあれば正しいキーとみなします。どの件にも無いキーは打ち間違いとして `UnknownKeyError` になります。

## 設定

```ruby
QueryStream.configure do |config|
  config.data_dir       = 'data'
  config.templates_dir  = 'templates'
  config.default_format = :md
  config.post_render    = ->(text, context) { text }
end
```

## エラー・警告の扱い

**この gem はメッセージを組み立てません。** どう表示するか、どの言語で出すか、そもそもログに残すかは、すべて呼び出し元が決めます。そのため展開時の出来事は、構造化された例外としてコールバックへ渡されます。

```ruby
QueryStream.render(
  content,
  data_dir:        'data',
  templates_dir:   'templates',
  source_filename: 'chapter.md',      # 位置情報（location）の表示に使います
  on_error:        ->(e) { },         # 展開失敗。その行は元の記法のまま残ります
  on_warning:      ->(w) { },         # 一件検索の該当なし／複数ヒット
  post_render:     ->(text, ctx) { }  # 展開結果の後処理
)
```

**1 行の失敗で全体は止まりません。** 失敗した行は元の記法のまま残り、後続の記法は展開され続けます。

| 例外クラス | 属性 |
|:---|:---|
| `TemplateNotFoundError` | `template_path`, `query`, `location`, `hint` |
| `DataNotFoundError` | `expected_path`, `query`, `location` |
| `DataLoadError` | `file_path`, `cause_error` |
| `UnknownKeyError` | `key_path`, `available_keys`, `template_path`, `location` |
| `NoResultWarning` | `query`, `location` |
| `AmbiguousQueryWarning` | `query`, `location`, `count` |

前 4 つは `QueryStream::Error`、後 2 つは `QueryStream::Warning` を継承します。**gem の外へ出る例外はこの 2 系統だけ**です。壊れた YAML も、不正な UTF-8 を含む原稿も、生の `ArgumentError` や `NoMethodError` にはなりません。

たとえば `UnknownKeyError` は「使えるキーの一覧」と「直すべき雛形のパス」まで持って届くので、呼び出し元で打ち間違いの案内を組み立てられます。`location` は記法が書かれた原稿の位置、`template_path` は直す雛形の位置で、**直すのは雛形のほう**です。

```ruby
on_error: lambda do |e|
  next unless e.is_a?(QueryStream::UnknownKeyError)

  keys = e.available_keys.map(&:to_s)
  near = DidYouMean::SpellChecker.new(dictionary: keys).correct(e.key_path.split('.').first).first
  puts "#{e.location} もしかして =#{near}?（#{e.template_path} / 使えるキー: #{keys.join(', ')}）"
end
```

例外はファイル権限のみ扱いが異なり、`Errno::EACCES` のまま伝わります。環境の問題（`chmod` で直る）とデータの問題（中身を直す）は、対処が違うためです。

### `post_render`

展開結果を、その出どころの情報つきで受け取れます。gem 側は用途を規定しないので、画像パスの解決など固有の後処理を差し込めます。

```ruby
post_render: lambda do |text, context|
  # context: source, data_file, data_dir, template_path, query, location
  MyImageResolver.rewrite(text, context)
end
```

戻り値が `String` ならそれを、そうでなければ元の展開結果を採用します。

## ライセンス

MIT License
