# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


### Planned
- パフォーマンス最適化
- 追加のテンプレートスタイル

## [Unreleased]

### Added
- **値の無い項目の部分だけを消せるようにした** (`template_compiler.rb`): 変数が 2 つ以上ある行は、区切り（`／`・`・`・`、`・`，`・`,` と、前後に空白のある ` / `）と、変数を含む括弧（`（…）`・`(…)`）で部品に分け、値の無い変数を含む部品だけを、区切りを詰めて消す。`= author.name 著／= publisher／= year 年` は、発行年の分からない本でも `高橋征義 著／SBクリエイティブ` と出る（これまでは著者まで行ごと消えていた）。`= author.name 著（= year年）` も、発行年が無ければ `高橋征義 著` になる。部品が 1 つも残らなければ、今までどおり行ごと消す。すべての値がそろった行の出力は変わらない。
  - 変数が 1 つだけの行と、表の行（`|` で始まる行）は今までどおり行ごと消す（セルを消すと列がずれる）。
  - 行頭の Markdown の目印（`- `・`1. `・`> `・`# `）は、先頭の部品が消えても残す。
  - 空白なしの半角の `/` は区切りにせず（URL を割らない）、`]` の直後の括弧（リンク先）も部品にしない。
- **抽出条件の数を、アンダースコアで桁区切りして書けるようにした** (`query_stream_parser.rb` / `filter_engine.rb`): `population>=9_000_000` や `population=900_0000..` のように書ける。Ruby の数値リテラルと同じく区切りは数字と数字のあいだにだけ置け、区切る位置は問わない（万の位で区切る `900_0000` も書ける）。比較（`>=` など）・範囲（`..`）・主キー検索に加え、等値（`=`）でも区切りを外して比べる。等値ではデータ側の値からも区切りを外すので、データに `"2024_01"` のような文字列があっても同じ綴りの条件で一致する。`snake_case` のような数でない値のアンダースコアはそのまま残す。
- **日付を和暦（`R06-01-01`）でも書けるようにした** (`filter_engine.rb`): データでも抽出条件でも、西暦の `2024-01-01` と同じ日付として比べ、並べ替える。元号は頭文字（M・T・S・H・R）で書き、年は 1 桁でもよい（`R6-01-01`）。等値（`=`）でも和暦と西暦を同じ日として扱う。変換は `Date.jisx0301` に任せた——`Date.parse` は `"R06-01-01"` を 2006-01-01 と読み違えるため使えない。元号の境目は検査しない（`H31-05-01` も 2019-05-01 として読む）。存在しない日（`R06-02-30`）は、西暦と同じく `InvalidDateError` になる。

### Fixed
- **省ける項目が最初の 1 件に無いと、打ち間違いとして止まっていた** (`template_compiler.rb`): テンプレートのキーを確かめるとき、最初の 1 件のキーしか見ていなかった。1 冊目に `year` が無いだけで `UnknownKeyError` になり、値の無い項目を消す仕組みが働く前に止まった。どれか 1 件にあるキーは正しいキーとみなす。どの件にも無いキーは、今までどおり打ち間違いとして知らせる。
- **日付の範囲指定が 1 件も返さなかった** (`filter_engine.rb`): `date=2024-06-01..2024-06-30` のような範囲は、両端が文字列のまま比べられ、日付に直したデータの値を含まなかった。両端も比較用にそろえてから判定する。数の範囲は両端が最初から数なので影響を受けていなかった。
- **昇順ソートの書き方が README に無かった** (`README.md`): 例に並ぶのは降順（`-title`）だけで、昇順の `+title` はどこにも出てこない。実装は昇順を持っている——出口が塞がっていただけである。

  自然に思いつくのは符号を付けない `= books | title` のほうだが、これは**主キー検索**として解釈され、該当なしの警告とともに何も展開されない（`= book | 楽しいRuby` と綴りが同じで、符号の有無だけが見分ける手掛かりになっている）。警告は出るので黙って壊れはしないが、書いた本人は「ソートしたつもり」なので、読んで気づける場所に書いておく必要があった。例へ `+title` / `-year` を足し、符号が必須である理由も添えた。

- **一度も実行されない分岐が残っていた** (`query_stream_parser.rb`): `parse_sort` は符号を省いた `title` を昇順として扱う分岐（`/\A?(.+)\z/`）を持ち、コメントも受け付ける綴りとして `"title"` を挙げていた。しかし振り分け側（`parse_segment`）は `/\A[+-][a-zA-Z_]/` に一致した綴りしか渡さないため、**符号なしはここへ届かない**。

  素の名前を昇順にすると主キー検索と区別が付かなくなるので、**いまの仕様のほうが正しい**。分岐とコメントが古かったので、符号が必須であることを前提に書き直した。挙動は変えていない（`+` / `-` の両方を実測で確認）。

### Changed
- **対応 Ruby を 3.4.10 / 4.0.7 にした**。4.0.7 は 2026-09-15 公開。
- **依存を最新へ上げた**: Minitest → 6.0.6、samovar 2.4.1 → 2.5.1、rake 13.3.1 → 13.4.2。gemspec の minitest は `~> 5.22` から `>= 5.22` へ緩めた——5 系に固定する理由が無く、6 でも 158 件すべて通る（`stub` / `mock` を使っていないため、6 での `minitest/mock` 分離の影響も受けない）。
- **rubocop を入れた**（`.rubocop.yml`・`rake rubocop`・CI）。見るのは `Lint` と `Security` だけで、引用符や行数は見ない。他の 2 つの gem と同じ構えである。現状 0 件。
- **README と CHANGELOG の「vivlio-style」を「Vivlio Starter」にした**。製品名を崩した綴りだった。

## [1.4.0] - 2026-08-07

### Removed
- **`QueryStream.logger` と `Configuration#logger` を削除した** (`query_stream.rb`, `configuration.rb`, `query-stream.gemspec`): 下記の `logger.error` 撤去により、gem 内でロガーを読む箇所がゼロになった。設定できるのに何も起きない項目は、利用者に「ログ出力を制御できる」という誤った期待を持たせるだけなので残さない。`logger` gem への依存も外した。
  - **破壊的変更**: `config.logger = ...` を書いているコードは削除が必要（設定しても何も起きないため、消すだけでよい）。
  - 唯一の利用者である vivlio-starter は `QueryStream.configure` 自体を使っておらず、影響は無い。

### Changed
- **`UnknownKeyError` を構造化例外にし、gem 内に最後まで残っていた `logger.error` を撤去した** (`errors.rb`, `template_compiler.rb`): 1.1.0 で `logger.error`、1.2.0 で `logger.warn` を廃したが、`TemplateCompiler` がテンプレートのキーを検証する 2 箇所にだけ `logger.error` が残っており、「gem 内のログ出力を全廃した」という設計が最後まで通っていなかった。`UnknownKeyError` は属性を 1 つも持たなかったため、**呼び出し元は「利用できるキーの一覧」を受け取れず**、gem が直接吐くログに頼るしかなかったのが原因である。`key_path` / `available_keys` / `template_path` / `location` を持たせ、ログ出力を削除した。これで呼び出し元は「もしかして `=title`?」のような案内を自前で組み立てられる。
  - `location`（記法が書かれた原稿の位置）と `template_path`（打ち間違いがある雛形の位置）は別物として持つ。**直すのは雛形**なので、記法の位置だけでは著者はファイルを開けない。
  - `TemplateCompiler.render` に `template_path:` キーワードを追加した（任意・既定 `nil`）。
- **必要な Ruby を 4.0 以上から 3.4 以上へ緩めた** (`query-stream.gemspec`): Ruby 4.0 固有の機能は使っていない。Prism のバージョン指定パースで全 14 ファイルを解析したところ 4.0.0 / 3.4.0 / 3.3.0 いずれも構文エラー 0 件で、実際の下限を決めていたのは `it`（暗黙ブロック引数・16 箇所）**単独**だった。`it` は 3.3 でも構文エラーにならず「`it` というメソッドの呼び出し」として通り、実行時に `NameError` になる——静的解析では見つからないので、Ruby 3.4.10 で実走して全テスト通過を確認している。コード変更はゼロ（gemspec 1 行のみ）。

### Fixed
- **壊れた入力で生の例外が外へ漏れていたのを直した**: いずれも「著者が用意した原稿・データが壊れている」という正当に起こりうる状況で、`QueryStream::Error` 系ではない例外が呼び出し元へ届いていた。呼び出し元は例外型で扱いを分けるため、生の `ArgumentError` / `NoMethodError` が出ると「どのファイルのどこが悪いか」を著者へ案内できない。
  - **空のデータファイルで `NoMethodError`** (`data_resolver.rb`): YAML が `nil` を返すのを素通ししており、`TemplateCompiler` が `undefined method 'any?' for nil` で落ちていた。`load_records` は**常に配列を返す**契約に正規化した（`@return [Array<Hash>]` という既存の記述に実装を合わせた形）。レコードの配列でもハッシュでもない中身（スカラーだけの YAML）は、何が入っていたかを添えて `DataLoadError` にする。
  - **不正な UTF-8 を含む原稿で `ArgumentError`** (`query_stream.rb`): `String#match?` も `lstrip` も不正バイト列に対して `invalid byte sequence in UTF-8` を投げるため、原稿に 1 バイトの壊れが混ざっただけで展開が丸ごと止まっていた。読めない行は**本文としてそのまま返す**。scrub して通す設計は採らない——gem が黙ってバイト列を書き換えると、著者が気付けない形で本文が変わる。
  - **`scan` に本文を渡すと `ArgumentError` / `Errno::EISDIR`** (`query_stream.rb`): `scan` はパスと本文の両方を受け取る API なのに、引数を無条件で `File.exist?` へ渡していた。NUL バイトを含む本文で `path name contains null byte`、ディレクトリ名で `File.exist?` が true を返し `File.read` が `Errno::EISDIR` になっていた。パスとして成立しうる形（NUL・改行を含まず `MAX_PATH_BYTES` 以下で、かつ `File.file?`）だけを読み、判定自体の失敗も本文扱いに倒す。

### Added
- **堅牢性テストを整備した** (`test/robustness/`): 「正しく使ったとき正しく動くか」を見る既存のユニットテストとは別に、**想定外の入力・環境に対する振る舞い**を固定する 27 件を追加。守る不変条件は「gem の外へ出てよい例外は `QueryStream::Error` の系統だけ」。上記 3 件の修正はいずれもこのテストを書く過程で見つかったもの。
  - `data_file_safety_test.rb` — `!ruby/object` 等の危険なタグ・壊れた YAML/JSON・空ファイル・レコードでない中身
  - `broken_encoding_test.rb` — 不正な UTF-8 を含む原稿。**バイト列を書き換えずに返す**ことまで固定
  - `scan_input_test.rb` — `scan` のパス／本文判定（NUL・改行・超長入力・ディレクトリ）
  - `missing_source_test.rb` — データ／テンプレート不在時の例外属性と、1 行の失敗で全体を止めないこと。**当てずっぽうの hint を返さない**ことも固定
  - `unreadable_file_test.rb` — 権限エラーは `DataLoadError` へ包まず `Errno::EACCES` のまま伝える（環境の問題とデータの問題は直し方が違うため）

## [1.3.0] - 2026-07-12

### Added
- **`post_render` 後段フィルタコールバックを追加** (`lib/query_stream.rb`, `lib/query_stream/configuration.rb`): 1 記法の展開結果を、コンテキスト付きで呼び出し元へ通す汎用フックを新設。`QueryStream.render` / `render_query` に `post_render:` キーワードを追加し、`Configuration#post_render` からも指定できる。コールバックは `(text, context)` を受け取り、`context` は `source`（記法の論理名）・`data_file`（単複解決後の実パス）・`data_dir`・`template_path`・`query`・`location` を含む。戻り値が String ならそれを、String 以外（nil 含む）なら元の展開結果を採用する。gem 自身は用途を規定せず、画像パス解決などの呼び出し元固有の後処理を委譲できる。コールバック内の例外は握り潰さず伝播する（`render` の既存 rescue は `QueryStream::Error` のみ捕捉するため、それ以外の後処理例外の扱いは呼び出し元の責務）。

## [1.2.2] - 2026-04-26

### Fixed
- **アンダースコア付き複合名の単数形変換が誤る問題を修正** (`lib/query_stream/singularize.rb`): `physics_books` が `physic_books` に変換されていた問題を修正。アンダースコアで分割し、末尾から複数形セグメントを探して単数化するよう変更。`people` は不規則変化として優先処理。`physics_books` → `physics_book`、`books_nested` → `book_nested` が正しく変換されるようになった。

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
- Vivlio Starter での実装例

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
