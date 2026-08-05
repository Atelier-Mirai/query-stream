# QueryStream 堅牢性テスト

通常のユニットテスト（`test/query_stream_test.rb`）が「正しく使ったとき正しく動くか」を
見るのに対し、ここは **「想定外の入力・環境に対してどう振る舞うか」** を見る。

QueryStream は**著者が書いた原稿と、著者が用意した YAML/JSON** を受け取る。
どちらも壊れうるし、壊れたときに生の `ArgumentError` や `NoMethodError` が出ると、
呼び出し元（Vivlio Starter）は「どの原稿のどこが悪いのか」を著者へ案内できない。
**gem の外へ出てよい例外は `QueryStream::Error` の系統だけ**、というのがここで守る不変条件である。

## 実行方法

```sh
rake test                                            # 全テスト（堅牢性を含む）
ruby -Ilib -Itest test/robustness/<name>_test.rb     # 個別
```

## テスト一覧

| テストファイル | 検証内容 |
|:---|:---|
| `data_file_safety_test.rb` | `!ruby/object` 等の危険なタグ・壊れた YAML/JSON・レコードでない中身を `DataLoadError` へ変換する。空のデータファイルは `[]` として扱い、`NoMethodError` を漏らさない |
| `broken_encoding_test.rb` | 不正な UTF-8 バイト列を含む原稿でも `render` / `scan` が落ちず、読めない行は**本文としてそのまま返す**（gem がバイト列を書き換えない） |
| `scan_input_test.rb` | `scan` はパスと本文の両方を受け取る。NUL バイト・改行入り・極端に長い文字列・ディレクトリを渡しても本文として扱い、`ArgumentError` / `Errno::EISDIR` を漏らさない |
| `missing_source_test.rb` | データ／テンプレートが無いとき、構造化された `DataNotFoundError` / `TemplateNotFoundError` になり、`render` は該当行を素通しして残りの展開を続ける |
| `unreadable_file_test.rb` | 読み取り権限の無いデータファイルは `Errno::EACCES` が自然に伝わる（root 実行時は skip） |

## ガイドライン

1. **純粋なユニットテストは `test/query_stream_test.rb` に置く。**
   ここは「攻撃的入力」「壊れた入力」「環境欠落」に特化する。
2. **一時ディレクトリで完結させる。** `Dir.mktmpdir` + `Dir.chdir` を使い、
   リポジトリのフィクスチャを汚さない。
3. **環境依存は `skip` でフォールバック。** 権限操作が効かない環境（root）では
   理由を明示して skip する。
4. **「落ちないこと」だけを見ない。** 何を返すか・どの例外型かまで固定する。
   型が変わると呼び出し元の案内が壊れるためである。
