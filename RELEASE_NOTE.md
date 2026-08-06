# QueryStream リリースノート

YAML / JSON のデータファイルとテンプレートを組み合わせて、文章中の 1 行記法を展開する Ruby ライブラリです。使い方は [README](README.md)、網羅的な変更履歴は [CHANGELOG](CHANGELOG.md) をご覧ください。

新しい版から順に並べています。

---

## 1.4.0 — 2026-08-07

**細かな不具合修正が中心のリリースです。** いずれも「著者が用意した原稿やデータが壊れている」という、実際に起こりうる場面で想定外の例外が漏れていた問題です。

- **空のデータファイルで落ちなくなりました。** 空 YAML は例外ではなく空配列として扱います。レコードでない中身（スカラーだけの YAML など）は、何が入っていたかを添えて `DataLoadError` で知らせます
- **壊れた文字が 1 バイト混ざっただけで展開が止まらなくなりました。** 読めない行は本文としてそのまま返します。gem が黙ってバイト列を書き換える（scrub する）設計は採っていません
- **`scan` に本文を渡しても落ちなくなりました。** パスと本文の両方を受け取る API なのに、引数を無条件でファイルとして開こうとしていました
- **`UnknownKeyError` が「使えるキーの一覧」と「直すべき雛形のパス」を持って届くようになりました。** これまでこの例外だけ属性が無く、キーの候補は gem が直接吐くログにしか出ていませんでした。`key_path` / `available_keys` / `template_path` / `location` を持たせ、**gem 内に最後まで残っていた `logger.error` を撤去**しています。呼び出し元は「もしかして `=title`?」のような案内を自前で組み立てられます
- **必要な Ruby を 4.0 以上から 3.4 以上へ緩めました**（コード変更はゼロ、gemspec 1 行のみ）

**破壊的変更が 1 つあります。** `QueryStream.logger` と `config.logger` を削除しました。上記の撤去で gem 内にロガーを読む箇所が無くなり、設定できるのに何も起きない項目になったためです。`config.logger = ...` と書いている箇所があれば、消してください（設定しても何も起きないので、消すだけで済みます）。`logger` gem への依存も外しました。

あわせて、これらを二度と起こさないための**堅牢性テスト 27 件**を `test/robustness/` に追加しました。守る約束は 1 つ、**gem の外へ出てよい例外は `QueryStream::Error` の系統だけ**です。呼び出し元は例外の型で扱いを分けるため、生の `ArgumentError` が出ると「どのファイルのどこが悪いか」を著者へ案内できません。上の 3 件は、このテストを書く過程で見つかりました。

ただし権限エラーだけは `Errno::EACCES` のまま伝えます。**環境の問題（`chmod` で直る）とデータの問題（中身を直す）は対処が違う**ためです。

## 1.3.0 — 2026-07-12

- **`post_render` 後段フィルタを追加しました。** 1 記法の展開結果を、コンテキスト付きで呼び出し元へ渡す汎用フックです。`context` には `source` / `data_file` / `data_dir` / `template_path` / `query` / `location` が入ります
- gem 自身は用途を規定しません。画像パス解決などの呼び出し元固有の後処理を、gem に固有知識を持ち込まずに差し込めます

## 1.2.2 — 2026-04-26

- **`physics_books` が `physic_books` になる単数形変換の誤りを修正しました。** アンダースコアで分割し、末尾から複数形セグメントを探して単数化します（`physics_books` → `physics_book`、`books_nested` → `book_nested`）

## 1.2.1 — 2026-04-20

- **データファイルの読み込みを `YAML.safe_load_file` へ移行しました（セキュリティ）。** `permitted_classes: [Symbol, Time, Date, DateTime]` を明示し、`!ruby/object:Kernel {}` のような Ruby オブジェクトタグを読ませて任意コード実行を狙う経路を塞いでいます。安全性が Psych のバージョンに依存しなくなりました
- **`DataLoadError` を追加しました。** `Psych::DisallowedClass` / `Psych::SyntaxError` / `JSON::ParserError` を、`file_path` と `cause_error` を持つ例外に変換します

## 1.2.0 — 2026-04-19

- **警告の `logger.warn` を全廃し、`on_warning:` コールバックで呼び出し元へ委譲しました。** `NoResultWarning` / `AmbiguousQueryWarning` に `query` / `location`（後者は `count` も）を持たせています
- これにより、`⚠️` の付け方も i18n も呼び出し元で決められるようになりました

> **補足**: このとき `TemplateCompiler` が `UnknownKeyError` を投げる経路にだけ `logger.error` が残っていました。1.4.0 で撤去し、**gem 内のログ出力はここで本当にゼロになりました**（設定項目 `config.logger` も同時に削除）。

## 1.1.0 — 2026-04-13

- **エラーを構造化例外へ移行しました。** `TemplateNotFoundError` に `template_path` / `query` / `location` / `hint`、`DataNotFoundError` に `expected_path` / `query` / `location` を持たせ、gem 内の `logger.error` を廃止しました
- **1 行の展開失敗で全体が止まる問題を修正しました。** 失敗した行は元の記法のまま残し、後続の展開を続けます。`on_error:` コールバックで通知します
- **`People`（大文字）が `person` に変換されない問題を修正しました**

## 1.0.0 — 2026-03-21

最初のメジャーリリースです。

- QueryStream 記法の完全実装（源泉・抽出条件・ソート・件数・スタイル）
- VFM フェンス記法対応（`:::{.book-card}` 〜 `:::`）。各レコードが個別のフェンスで囲まれて展開されます
- テンプレートコンパイラ（変数展開・画像記法・ネスト値アクセス・表記法）
- データリゾルバ（YAML / JSON の自動探索、複数形→単数形のテンプレート解決）
- フィルタリング（等値・AND / OR・比較演算子）とソート
- 設定システム（`data_dir` / `templates_dir` / `default_format` / `logger`）
