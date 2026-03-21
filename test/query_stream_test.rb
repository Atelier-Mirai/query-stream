# frozen_string_literal: true

require_relative 'test_helper'

# ================================================================
# QueryStream テスト
# ================================================================
# QueryStream 記法の全ステージ（源泉・抽出・ソート・件数・スタイル）を
# 書籍・都道府県・気象・元素の4データ種別で網羅的にテストする。
#
# テスト構成:
#   1. Singularize       - 単数形/複数形の自動解決
#   2. QueryStreamParser - 記法のパース
#   3. TemplateCompiler  - テンプレートの変数展開
#   4. FilterEngine      - フィルタリング・ソート
#   5. DataResolver      - データファイル探索
#   6. QueryStream       - 統合テスト（パイプライン全体）
# ================================================================

FIXTURE_BASE = File.expand_path('fixtures', __dir__)
FIXTURE_DATA_DIR = File.join(FIXTURE_BASE, 'data')
FIXTURE_TEMPLATES_DIR = File.join(FIXTURE_BASE, 'templates')

# ================================================================
# 1. Singularize テスト
# ================================================================
class SingularizeTest < Minitest::Test
  # 通常の複数形（末尾 s）を単数形に変換できる
  def test_should_singularize_regular_plurals
    assert_equal 'book',           QueryStream::Singularize.call('books')
    assert_equal 'element',        QueryStream::Singularize.call('elements')
    assert_equal 'weather_report', QueryStream::Singularize.call('weather_reports')
    assert_equal 'prefecture',     QueryStream::Singularize.call('prefectures')
  end

  # -ies で終わる複数形を -y に変換できる
  def test_should_singularize_ies_to_y
    assert_equal 'category', QueryStream::Singularize.call('categories')
    assert_equal 'entry',    QueryStream::Singularize.call('entries')
  end

  # -ches/-shes/-ses/-xes/-zes で終わる複数形を変換できる
  def test_should_singularize_es_variants
    assert_equal 'branch', QueryStream::Singularize.call('branches')
    assert_equal 'brush',  QueryStream::Singularize.call('brushes')
    assert_equal 'box',    QueryStream::Singularize.call('boxes')
  end

  # -ves で終わる複数形を -f に変換できる
  def test_should_singularize_ves_to_f
    assert_equal 'shelf', QueryStream::Singularize.call('shelves')
  end

  # 接尾辞に数字やアンダースコアがある場合も単数形化できる
  def test_should_singularize_suffix_numbers_and_underscores
    assert_equal 'book2',        QueryStream::Singularize.call('books2')
    assert_equal 'book_nested',  QueryStream::Singularize.call('books_nested')
  end

  # 不規則名詞 people → person を処理できる
  def test_should_singularize_people_to_person
    assert_equal 'person', QueryStream::Singularize.call('people')
    assert_equal 'person', QueryStream::Singularize.call('People')
  end

  # people2 / people_authors のような派生形も person 接頭語に正規化される
  def test_should_singularize_people_with_suffixes
    assert_equal 'person2', QueryStream::Singularize.call('people2')
    assert_equal 'person_authors', QueryStream::Singularize.call('people_authors')
  end

  # 不変の語はそのまま返す
  def test_should_keep_invariant_words
    assert_equal 'data',  QueryStream::Singularize.call('data')
    assert_equal 'sheep', QueryStream::Singularize.call('sheep')
  end
end

# ================================================================
# 2. QueryStreamParser テスト
# ================================================================
class QueryStreamParserTest < Minitest::Test
  Parser = QueryStream::QueryStreamParser

  # スペースなしの=記法をパースできる
  def test_should_parse_nospace_source
    result = Parser.parse('=books')
    assert_equal 'books', result[:source]
    assert_empty result[:filters]
  end

  # 源泉のみの最小記法をパースできる
  def test_should_parse_source_only
    result = Parser.parse('= books')
    assert_equal 'books', result[:source]
    assert_empty result[:filters]
    assert_nil result[:sort]
    assert_nil result[:limit]
    assert_nil result[:style]
  end

  # スタイル指定をパースできる
  def test_should_parse_style
    result = Parser.parse('= books | :full')
    assert_equal 'books', result[:source]
    assert_equal 'full',  result[:style]
  end

  # スタイル＋拡張子をパースできる
  def test_should_parse_style_with_format
    result = Parser.parse('= books | :table.html')
    assert_equal 'table', result[:style]
    assert_equal 'html',  result[:format]
  end

  # 件数指定をパースできる
  def test_should_parse_limit
    result = Parser.parse('= books | 5')
    assert_equal 5, result[:limit]
  end

  # ソート指定（降順）をパースできる
  def test_should_parse_sort_desc
    result = Parser.parse('= books | -title')
    assert_equal({ field: :title, direction: :desc }, result[:sort])
  end

  # ソート指定（昇順）をパースできる
  def test_should_parse_sort_asc
    result = Parser.parse('= books | +title')
    assert_equal({ field: :title, direction: :asc }, result[:sort])
  end

  # 等値フィルタをパースできる
  def test_should_parse_eq_filter
    result = Parser.parse('= books | tags=ruby')
    assert_equal 1, result[:filters].size
    filter = result[:filters].first
    assert_equal :tags, filter[:field]
    assert_equal :eq,   filter[:op]
    assert_equal ['ruby'], filter[:value]
  end

  # カンマ区切りOR条件をパースできる
  def test_should_parse_or_filter_with_comma
    result = Parser.parse('= books | tags=ruby, javascript')
    filter = result[:filters].first
    assert_equal ['ruby', 'javascript'], filter[:value]
  end

  # AND 条件をパースできる
  def test_should_parse_and_filter
    result = Parser.parse('= books | tags=ruby && tags=beginner')
    assert_equal 2, result[:filters].size
    assert_equal :tags, result[:filters][0][:field]
    assert_equal :tags, result[:filters][1][:field]
  end

  # AND の別記法（and）をパースできる
  def test_should_parse_and_with_word
    result = Parser.parse('= weather_reports | location=東京 AND condition=晴')
    assert_equal 2, result[:filters].size
  end

  # 比較演算子（>=）をパースできる
  def test_should_parse_gte_operator
    result = Parser.parse('= weather_reports | temp_min_c>=20')
    filter = result[:filters].first
    assert_equal :temp_min_c, filter[:field]
    assert_equal :gte,        filter[:op]
    assert_equal 20,          filter[:value]
  end

  # 比較演算子（<=）をパースできる
  def test_should_parse_lte_operator
    result = Parser.parse('= prefectures | population<=5000000')
    filter = result[:filters].first
    assert_equal :lte, filter[:op]
  end

  # 比較演算子（>）をパースできる
  def test_should_parse_gt_operator
    result = Parser.parse('= elements | atomic_number>5')
    filter = result[:filters].first
    assert_equal :gt, filter[:op]
    assert_equal 5,   filter[:value]
  end

  # 比較演算子（<）をパースできる
  def test_should_parse_lt_operator
    result = Parser.parse('= elements | atomic_number<5')
    filter = result[:filters].first
    assert_equal :lt, filter[:op]
  end

  # 不等値演算子（!=）をパースできる
  def test_should_parse_neq_operator
    result = Parser.parse('= elements | category!=nonmetal')
    filter = result[:filters].first
    assert_equal :neq, filter[:op]
  end

  # 包括的範囲指定（..）をパースできる
  def test_should_parse_inclusive_range
    result = Parser.parse('= elements | atomic_number=1..6')
    filter = result[:filters].first
    assert_equal :range, filter[:op]
    assert_equal 1..6,   filter[:value]
  end

  # 排他的範囲指定（...）をパースできる
  def test_should_parse_exclusive_range
    result = Parser.parse('= elements | atomic_number=1...6')
    filter = result[:filters].first
    assert_equal :range, filter[:op]
    assert_equal 1...6,  filter[:value]
  end

  # 下限のみの範囲指定（20..）をパースできる
  def test_should_parse_open_ended_range
    result = Parser.parse('= weather_reports | temp_min_c=20..')
    filter = result[:filters].first
    assert_equal :gte, filter[:op]
    assert_equal 20,   filter[:value]
  end

  # 上限のみの範囲指定（..25）をパースできる
  def test_should_parse_open_start_range
    result = Parser.parse('= weather_reports | temp_min_c=..25')
    filter = result[:filters].first
    assert_equal :lte, filter[:op]
    assert_equal 25,   filter[:value]
  end

  # 上限のみの排他的範囲（...25 → 25未満）をパースできる
  def test_should_parse_open_start_exclusive_range
    result = Parser.parse('= weather_reports | temp_min_c=...25')
    filter = result[:filters].first
    assert_equal :lt, filter[:op]
    assert_equal 25,  filter[:value]
  end

  # 主キー検索をパースできる
  def test_should_parse_primary_key_lookup
    result = Parser.parse('= book | 楽しいRuby')
    assert result[:single_lookup]
    assert_equal 1, result[:filters].size
    assert_equal :_primary_key, result[:filters].first[:field]
  end

  # slug による主キー検索をパースできる
  def test_should_parse_slug_primary_key_lookup
    result = Parser.parse('= post | my-first-post')
    assert result[:single_lookup]
    assert_equal :_primary_key, result[:filters].first[:field]
  end

  # 全ステージの組み合わせをパースできる
  def test_should_parse_full_pipeline
    result = Parser.parse('= books | tags=ruby | -title | 5 | :full')
    assert_equal 'books', result[:source]
    assert_equal 1,       result[:filters].size
    assert_equal :desc,   result[:sort][:direction]
    assert_equal :title,  result[:sort][:field]
    assert_equal 5,       result[:limit]
    assert_equal 'full',  result[:style]
  end

  # パイプ省略時の自動判別が正しく動作する
  def test_should_auto_classify_tokens_with_omitted_pipes
    result = Parser.parse('= books | tags=ruby | :full')
    assert_equal 'full', result[:style]
    assert_equal 1, result[:filters].size
    assert_nil result[:sort]
    assert_nil result[:limit]
  end

  # 複雑な条件式をパースできる
  def test_should_parse_complex_expression
    result = Parser.parse('= weather_reports | condition=晴, 曇 and temp_min_c>=20 | -date | 5 | :full')
    assert_equal 'weather_reports', result[:source]
    assert_equal 2, result[:filters].size
    assert_equal :eq,  result[:filters][0][:op]
    assert_equal :gte, result[:filters][1][:op]
    assert_equal 'full', result[:style]
    assert_equal 5, result[:limit]
  end

  # AND 連結時に2件目以降のフィールド省略を許容する
  def test_should_allow_fieldless_and_clause
    result = Parser.parse('= books | tags = ruby && beginner')
    assert_equal 1, result[:filters].size
    filter = result[:filters].first
    assert_equal :eq, filter[:op]
    assert_equal [:ruby, :beginner].map(&:to_s), filter[:value]
  end
end

# ================================================================
# 3. TemplateCompiler テスト
# ================================================================
class TemplateCompilerTest < Minitest::Test
  Compiler = QueryStream::TemplateCompiler

  # 単一レコードの変数展開が正しく動作する
  def test_should_expand_single_record
    template = "### = title\n**著者**: = author\n"
    records = [{ title: '楽しいRuby', author: '高橋征義' }]

    result = Compiler.render(template, records)
    assert_includes result, '### 楽しいRuby'
    assert_includes result, '**著者**: 高橋征義'
  end

  # 複数レコードの反復展開が正しく動作する
  def test_should_expand_multiple_records
    template = "### = title\n= desc\n"
    records = [
      { title: '楽しいRuby', desc: 'Rubyを楽しく学べる入門書。' },
      { title: 'はじめてのC', desc: 'C言語の定番入門書。' }
    ]

    result = Compiler.render(template, records)
    assert_includes result, '### 楽しいRuby'
    assert_includes result, '### はじめてのC'
    assert_includes result, 'Rubyを楽しく学べる入門書。'
    assert_includes result, 'C言語の定番入門書。'
  end

  # nil フィールドの行がスキップされる
  def test_should_skip_line_when_value_is_nil
    template = "### = title\n![](cover){width=40%}\n"
    records = [{ title: 'はじめてのC', cover: nil }]

    result = Compiler.render(template, records)
    assert_includes result, '### はじめてのC'
    refute_includes result, '![](cover)'
    refute_includes result, '![]()'
  end

  # 空文字フィールドの行がスキップされる
  def test_should_skip_line_when_value_is_empty
    template = "### = title\n= desc\n"
    records = [{ title: 'テスト', desc: '' }]

    result = Compiler.render(template, records)
    assert_includes result, '### テスト'
    refute_includes result, 'desc'
  end

  # 画像記法の変数展開が正しく動作する
  def test_should_expand_image_variable
    template = "![](cover){width=40%}\n"
    records = [{ cover: 'ruby-enjoyer.webp' }]

    result = Compiler.render(template, records)
    assert_includes result, '![](ruby-enjoyer.webp){width=40%}'
  end

  # 画像記法のリテラル（拡張子あり）はそのまま出力される
  def test_should_keep_literal_image_path
    template = "![](Einstein.png){width=40%}\n"
    records = [{ title: 'テスト' }]

    result = Compiler.render(template, records)
    assert_includes result, '![](Einstein.png){width=40%}'
  end

  # 画像記法の明示的変数展開（= cover）も動作する
  def test_should_expand_explicit_image_variable
    template = "![](= cover){width=40%}\n"
    records = [{ cover: 'ruby-enjoyer.webp' }]

    result = Compiler.render(template, records)
    assert_includes result, '![](ruby-enjoyer.webp){width=40%}'
  end

  # テーブル記法のヘッダー行が一度だけ出力される
  def test_should_output_table_header_once
    template = "| タイトル | 説明 | 著者 |\n|---|---|---|\n| = title | = desc | = author |\n"
    records = [
      { title: '楽しいRuby', desc: '入門書', author: '高橋' },
      { title: 'はじめてのC', desc: '定番', author: '柴田' }
    ]

    result = Compiler.render(template, records)

    # ヘッダー行は1回だけ
    assert_equal 1, result.scan('| タイトル |').size
    assert_equal 1, result.scan('|---|---|---|').size

    # データ行は2件
    assert_includes result, '| 楽しいRuby | 入門書 | 高橋 |'
    assert_includes result, '| はじめてのC | 定番 | 柴田 |'
  end

  # ヘッダーなしのテーブルテンプレートで空行が入らない
  def test_should_render_table_without_header_no_blank_lines
    template = "| = title | = author |\n| = desc | ![](cover){width=20% align=right} |\n\n"
    records = [
      { title: '楽しいRuby', author: '高橋', desc: '入門書', cover: 'ruby.webp' },
      { title: 'はじめてのC', author: '柴田', desc: '定番', cover: 'c.webp' }
    ]

    result = Compiler.render(template, records)

    # テーブル行間に空行が入らない
    assert_includes result, "| 楽しいRuby | 高橋 |\n| 入門書 | ![](ruby.webp){width=20% align=right} |\n| はじめてのC | 柴田 |"
  end

  # ドット記法でネストされた値を展開できる
  def test_should_expand_nested_value_with_dot_notation
    template = "| =title | =author.name |\n"
    records = [{ title: '楽しいRuby', author: { name: '高橋征義', bio: 'Rubyist' } }]

    result = Compiler.render(template, records)
    assert_includes result, '| 楽しいRuby | 高橋征義 |'
  end

  # =key（スペースなし）の変数展開が動作する
  def test_should_expand_nospace_variable
    template = "|=title |=author |\n"
    records = [{ title: '楽しいRuby', author: '高橋' }]

    result = Compiler.render(template, records)
    assert_includes result, '|楽しいRuby |高橋 |'
  end

  # 存在しないキーがテンプレートにある場合エラーになる
  def test_should_raise_error_for_unknown_key
    template = "### = unknown_field\n"
    records = [{ title: 'テスト' }]

    assert_raises(QueryStream::UnknownKeyError) do
      Compiler.render(template, records)
    end
  end

  # レコードが空の場合は空文字列を返す
  def test_should_return_empty_for_no_records
    template = "### = title\n"
    result = Compiler.render(template, [])
    assert_equal '', result
  end

  # ----------------------------------------------------------------
  # VFM フェンス記法テスト
  # ----------------------------------------------------------------

  # classify_lines がフェンス開始行を :fence_open に分類する
  def test_should_classify_fence_open_line
    lines = [":::{.book-card}\n"]
    parts = Compiler.classify_lines(lines)
    assert_equal :fence_open, parts[0][:type]
  end

  # classify_lines がフェンス終了行を :fence_close に分類する
  def test_should_classify_fence_close_line
    lines = [":::\n"]
    parts = Compiler.classify_lines(lines)
    assert_equal :fence_close, parts[0][:type]
  end

  # フェンスで囲まれたテンプレートで単一レコードが正しく展開される
  def test_should_render_fenced_template_with_single_record
    template = ":::{.book-card}\n![](cover)\n**=title**\n=desc\n:::\n"
    records = [{ title: '楽しいRuby', desc: 'Rubyを楽しく学べる入門書。', cover: 'ruby.webp' }]

    result = Compiler.render(template, records)

    assert_includes result, ':::{.book-card}'
    assert_includes result, '![](ruby.webp)'
    assert_includes result, '**楽しいRuby**'
    assert_includes result, 'Rubyを楽しく学べる入門書。'
    assert_includes result, ":::\n"
  end

  # フェンスで囲まれたテンプレートで複数レコードが各自フェンスを持つ
  def test_should_render_fenced_template_with_multiple_records
    template = ":::{.book-card}\n![](cover)\n**=title**\n=desc\n:::\n"
    records = [
      { title: '楽しいRuby', desc: 'Rubyを楽しく学べる入門書。', cover: 'ruby.webp' },
      { title: 'はじめてのC', desc: 'C言語の定番入門書。', cover: 'c.webp' }
    ]

    result = Compiler.render(template, records)

    # 各レコードが個別の :::{.book-card} 〜 ::: で囲まれる
    assert_equal 2, result.scan(':::{.book-card}').size, 'フェンス開始が2回出現すべき'
    assert_equal 2, result.scan(/^:::\s*$/).size, 'フェンス終了が2回出現すべき'

    # 各レコードの内容が含まれる
    assert_includes result, '**楽しいRuby**'
    assert_includes result, '**はじめてのC**'
    assert_includes result, '![](ruby.webp)'
    assert_includes result, '![](c.webp)'
  end

  # nilフィールドでフェンス内の行がスキップされつつフェンス自体は維持される
  def test_should_skip_nil_field_line_inside_fence
    template = ":::{.book-card}\n![](cover)\n**=title**\n=desc\n:::\n"
    records = [{ title: 'はじめてのC', desc: 'C言語の定番入門書。', cover: nil }]

    result = Compiler.render(template, records)

    assert_includes result, ':::{.book-card}'
    assert_includes result, '**はじめてのC**'
    refute_includes result, '![]()'
  end

  # 汎用VFMクラス（{.person-card} 等）でもフェンスが各レコードごとに反復される
  def test_should_repeat_fence_for_any_vfm_class
    template = ":::{.person-card}\n**= name**\n= bio\n:::\n"
    records = [
      { name: 'Alice', bio: 'Engineer' },
      { name: 'Bob', bio: 'Designer' }
    ]

    result = Compiler.render(template, records)

    assert_equal 2, result.scan(':::{.person-card}').size
    assert_equal 2, result.scan(/^:::\s*$/).size
    assert_includes result, '**Alice**'
    assert_includes result, '**Bob**'
  end

  # フェンスなしテンプレートの既存挙動（leading/trailing分割）が保持される
  def test_should_not_affect_non_fenced_template
    template = "### = title\n= desc\n"
    records = [
      { title: '楽しいRuby', desc: '入門書' },
      { title: 'はじめてのC', desc: '定番書' }
    ]

    result = Compiler.render(template, records)

    assert_includes result, '### 楽しいRuby'
    assert_includes result, '### はじめてのC'
  end

  # expand_fence_range が前方のフェンス開始行を取り込む
  def test_expand_fence_range_should_include_preceding_fence_open
    parts = [
      { type: :fence_open, content: ":::{.card}\n" },
      { type: :dynamic, content: "= title\n" },
      { type: :fence_close, content: ":::\n" }
    ]
    first_dyn, last_dyn = Compiler.expand_fence_range(parts, 1, 1)
    assert_equal 0, first_dyn
    assert_equal 2, last_dyn
  end

  # expand_fence_range が空行を挟んでもフェンスを取り込む
  def test_expand_fence_range_should_skip_blank_between_fence_and_dynamic
    parts = [
      { type: :fence_open, content: ":::{.card}\n" },
      { type: :blank },
      { type: :dynamic, content: "= title\n" },
      { type: :blank },
      { type: :fence_close, content: ":::\n" }
    ]
    first_dyn, last_dyn = Compiler.expand_fence_range(parts, 2, 2)
    assert_equal 0, first_dyn
    assert_equal 4, last_dyn
  end

  # フェンスが隣接しない場合は範囲が拡張されない
  def test_expand_fence_range_should_not_expand_without_adjacent_fence
    parts = [
      { type: :static, content: "# Header\n" },
      { type: :dynamic, content: "= title\n" },
      { type: :static, content: "footer\n" }
    ]
    first_dyn, last_dyn = Compiler.expand_fence_range(parts, 1, 1)
    assert_equal 1, first_dyn
    assert_equal 1, last_dyn
  end
end

# ================================================================
# 4. FilterEngine テスト
# ================================================================
class FilterEngineTest < Minitest::Test
  Engine = QueryStream::FilterEngine

  # 等値フィルタが動作する
  def test_should_filter_by_eq
    records = [
      { name: 'Alice', role: 'admin' },
      { name: 'Bob', role: 'user' }
    ]
    filters = [{ field: :role, op: :eq, value: ['admin'] }]
    result = Engine.apply_filters(records, filters)
    assert_equal 1, result.size
    assert_equal 'Alice', result.first[:name]
  end

  # 比較フィルタ（>=）が動作する
  def test_should_filter_by_gte
    records = [
      { name: 'A', score: 80 },
      { name: 'B', score: 90 },
      { name: 'C', score: 70 }
    ]
    filters = [{ field: :score, op: :gte, value: 80 }]
    result = Engine.apply_filters(records, filters)
    assert_equal 2, result.size
  end

  # 範囲フィルタが動作する
  def test_should_filter_by_range
    records = [
      { name: 'A', score: 80 },
      { name: 'B', score: 90 },
      { name: 'C', score: 70 }
    ]
    filters = [{ field: :score, op: :range, value: 75..85 }]
    result = Engine.apply_filters(records, filters)
    assert_equal 1, result.size
    assert_equal 'A', result.first[:name]
  end

  # ソートが動作する（昇順）
  def test_should_sort_asc
    records = [
      { name: 'B', score: 90 },
      { name: 'A', score: 80 }
    ]
    result = Engine.apply_sort(records, { field: :name, direction: :asc })
    assert_equal 'A', result.first[:name]
  end

  # ソートが動作する（降順）
  def test_should_sort_desc
    records = [
      { name: 'A', score: 80 },
      { name: 'B', score: 90 }
    ]
    result = Engine.apply_sort(records, { field: :score, direction: :desc })
    assert_equal 'B', result.first[:name]
  end

  # 主キー検索が slug フィールドで動作する
  def test_should_evaluate_primary_key_with_slug
    record = { slug: 'my-first-post', title: 'テスト' }
    assert Engine.evaluate_primary_key_lookup(record, 'my-first-post')
    refute Engine.evaluate_primary_key_lookup(record, 'nonexistent')
  end
end

# ================================================================
# 5. DataResolver テスト
# ================================================================
class DataResolverTest < Minitest::Test
  Resolver = QueryStream::DataResolver

  # YAML ファイルが解決できる
  def test_should_resolve_yaml_file
    path = Resolver.resolve('books', FIXTURE_DATA_DIR)
    assert path
    assert path.end_with?('.yml')
  end

  # 複数形→単数形の自動解決が動作する
  def test_should_resolve_singular_from_plural
    path = Resolver.resolve('book', FIXTURE_DATA_DIR)
    assert path
    assert_includes path, 'books'
  end

  # JSON ファイルが読み込める
  def test_should_load_json_records
    json_path = File.join(FIXTURE_DATA_DIR, 'books.json')
    records = Resolver.load_records(json_path)
    assert_kind_of Array, records
    assert_equal '楽しいRuby', records.first[:title]
  end

  # 存在しないファイルは nil を返す
  def test_should_return_nil_for_missing_file
    path = Resolver.resolve('nonexistent', FIXTURE_DATA_DIR)
    assert_nil path
  end
end

# ================================================================
# 6. QueryStream 統合テスト
# ================================================================
class QueryStreamIntegrationTest < Minitest::Test
  # ----------------------------------------------------------------
  # 書籍データ
  # ----------------------------------------------------------------

  # 全件展開が正しく動作する
  def test_should_expand_all_books
    content = "# 参考書籍\n\n= books\n\n次の章へ\n"
    result = render(content)

    assert_includes result, '### 楽しいRuby'
    assert_includes result, '### はじめてのC'
    assert_includes result, '### JavaScript入門'
    assert_includes result, '### Rubyレシピブック'
    assert_includes result, '次の章へ'
  end

  # books2 データセットでも単数形テンプレートが解決される
  def test_should_expand_books2_dataset
    content = "= books2\n"
    result = render(content)

    assert_includes result, 'Book2: Ruby Hacks 2'
    assert_includes result, 'Book2: C Primer 2'
  end

  # books_nested データセットでも単数形テンプレートが解決される
  def test_should_expand_books_nested_dataset
    content = "= books_nested\n"
    result = render(content)

    assert_includes result, 'Nested: Ruby Nested Stories'
    assert_includes result, '**section**: reference'
  end

  # タグでの絞り込みが正しく動作する
  def test_should_filter_books_by_tag
    content = "= books | tags=ruby\n"
    result = render(content)

    assert_includes result, '楽しいRuby'
    assert_includes result, 'JavaScript入門'   # tags: "ruby, javascript"
    assert_includes result, 'Rubyレシピブック'
    refute_includes result, 'はじめてのC'
  end

  # AND 条件の絞り込みが正しく動作する
  def test_should_filter_books_with_and_condition
    content = "= books | tags=ruby && tags=beginner\n"
    result = render(content)

    assert_includes result, '楽しいRuby'
    refute_includes result, 'Rubyレシピブック'  # advanced
  end

  # OR 条件の絞り込みが正しく動作する
  def test_should_filter_books_with_or_values
    content = "= books | tags=c, javascript\n"
    result = render(content)

    assert_includes result, 'はじめてのC'
    assert_includes result, 'JavaScript入門'
    refute_includes result, 'Rubyレシピブック'
  end

  # 主キー検索（title）で一件取得できる
  def test_should_lookup_book_by_title
    content = "= book | 楽しいRuby\n"
    result = render(content)

    assert_includes result, '楽しいRuby'
    refute_includes result, 'はじめてのC'
  end

  # スタイル指定が正しく動作する
  def test_should_use_full_style_template
    content = "= books | tags=ruby && tags=beginner | :full\n"
    result = render(content)

    assert_includes result, '## 楽しいRuby'     # fullスタイルは ## を使用
    assert_includes result, '**タグ**:'          # fullスタイルにはタグがある
  end

  # テーブルスタイルが正しく動作する
  def test_should_render_table_style
    content = "= books | tags=ruby && tags=beginner | :table\n"
    result = render(content)

    assert_includes result, '| タイトル |'
    assert_includes result, '| 楽しいRuby |'
  end

  # nil cover の行がスキップされる
  def test_should_skip_nil_cover_line
    content = "= book | はじめてのC\n"
    result = render(content)

    assert_includes result, 'はじめてのC'
    refute_includes result, '![]()'
    refute_match(/!\[\]\([^)]*\)\{width/, result)
  end

  # ソートが正しく動作する
  def test_should_sort_books_by_title_desc
    content = "= books | -title\n"
    result = render(content)

    titles = result.scan(/### (.+)/).flatten
    assert_equal titles, titles.sort.reverse
  end

  # 件数制限が正しく動作する
  def test_should_limit_results
    content = "= books | 2\n"
    result = render(content)

    titles = result.scan(/### (.+)/).flatten
    assert_equal 2, titles.size
  end

  # ----------------------------------------------------------------
  # 都道府県データ
  # ----------------------------------------------------------------

  # 全件展開ができる
  def test_should_expand_all_prefectures
    content = "= prefectures\n"
    result = render(content)

    assert_includes result, '北海道'
    assert_includes result, '東京都'
    assert_includes result, '大阪府'
  end

  # 地方での絞り込みが動作する
  def test_should_filter_prefectures_by_region
    content = "= prefectures | region=関東\n"
    result = render(content)

    assert_includes result, '東京都'
    assert_includes result, '神奈川県'
    refute_includes result, '北海道'
    refute_includes result, '大阪府'
  end

  # 複数地方のOR絞り込みが動作する
  def test_should_filter_prefectures_by_multiple_regions
    content = "= prefectures | region=関東, 関西\n"
    result = render(content)

    assert_includes result, '東京都'
    assert_includes result, '神奈川県'
    assert_includes result, '大阪府'
    refute_includes result, '北海道'
  end

  # code による主キー検索ができる
  def test_should_lookup_prefecture_by_code
    content = "= prefecture | 13\n"
    result = render(content)

    assert_includes result, '東京都'
    refute_includes result, '大阪府'
  end

  # name による主キー検索ができる
  def test_should_lookup_prefecture_by_name
    content = "= prefecture | 東京都\n"
    result = render(content)

    assert_includes result, '東京都'
    assert_includes result, '新宿区'
  end

  # 人口での比較フィルタが動作する
  def test_should_filter_prefectures_by_population_gte
    content = "= prefectures | population>=9000000\n"
    result = render(content)

    assert_includes result, '東京都'
    assert_includes result, '神奈川県'
    refute_includes result, '北海道'
  end

  # ----------------------------------------------------------------
  # 気象データ
  # ----------------------------------------------------------------

  # 地点＋天候の複合AND条件が動作する
  def test_should_filter_weather_by_location_and_condition
    content = "= weather_reports | location=東京 AND condition=晴\n"
    result = render(content)

    assert_includes result, '2024-01-01'
    assert_includes result, '2024-07-20'
    refute_includes result, '2024-06-15'   # 雨
  end

  # 気温の範囲指定が動作する
  def test_should_filter_weather_by_temp_range
    content = "= weather_reports | temp_min_c=20..27\n"
    result = render(content)

    assert_includes result, '2024-07-20'   # 26.3
    assert_includes result, '2024-07-21'   # 25.0
    refute_includes result, '2024-01-01'   # 1.5
  end

  # 排他的範囲指定が動作する
  def test_should_filter_weather_by_exclusive_range
    content = "= weather_reports | temp_min_c=25...27\n"
    result = render(content)

    assert_includes result, '2024-07-20'   # 26.3
    assert_includes result, '2024-07-21'   # 25.0
    refute_includes result, '2024-08-10'   # 27.8（27未満なので含まない）
  end

  # 日付降順ソート＋件数制限が動作する
  def test_should_sort_weather_by_date_desc_with_limit
    content = "= weather_reports | -date | 3\n"
    result = render(content)

    # 最新3件のみ
    assert_includes result, '2024-08-10'
    assert_includes result, '2024-07-21'
    assert_includes result, '2024-07-20'
    refute_includes result, '2024-01-01'
  end

  # OR天候 + 気温条件の複合クエリが動作する
  def test_should_handle_complex_weather_query
    content = "= weather_reports | condition=晴, 曇 and temp_min_c>=20 | -date | 5\n"
    result = render(content)

    # 晴または曇で最低気温20度以上
    assert_includes result, '2024-08-10'   # 晴, 27.8
    assert_includes result, '2024-07-21'   # 曇, 25.0
    assert_includes result, '2024-07-20'   # 晴, 26.3
    refute_includes result, '2024-01-01'   # 晴だが気温1.5
    refute_includes result, '2024-06-15'   # 雨
  end

  # ----------------------------------------------------------------
  # 元素データ
  # ----------------------------------------------------------------

  # カテゴリ+状態のANDフィルタが動作する
  def test_should_filter_elements_by_category_and_phase
    content = "= elements | category=nonmetal AND phase_at_stp=gas\n"
    result = render(content)

    assert_includes result, '水素'
    assert_includes result, '窒素'
    assert_includes result, '酸素'
    refute_includes result, '炭素'    # solid
    refute_includes result, 'ヘリウム' # noble_gas
  end

  # 原子番号の範囲フィルタが動作する
  def test_should_filter_elements_by_atomic_number_range
    content = "= elements | atomic_number=1..3\n"
    result = render(content)

    assert_includes result, '水素'
    assert_includes result, 'ヘリウム'
    assert_includes result, 'リチウム'
    refute_includes result, '炭素'
  end

  # name による主キー検索ができる
  def test_should_lookup_element_by_name
    content = "= element | 水素\n"
    result = render(content)

    assert_includes result, '水素'
    assert_includes result, 'H'
    refute_includes result, 'ヘリウム'
  end

  # fullスタイルで元素を表示できる
  def test_should_render_element_with_full_style
    content = "= element | 水素 | :full\n"
    result = render(content)

    assert_includes result, '## 水素'      # fullスタイルは ## を使用
    assert_includes result, '**カテゴリ**:' # fullスタイルにはカテゴリがある
  end

  # 不等値フィルタが動作する
  def test_should_filter_elements_with_neq
    content = "= elements | category!=nonmetal\n"
    result = render(content)

    assert_includes result, 'ヘリウム'   # noble_gas
    assert_includes result, 'リチウム'   # alkali_metal
    refute_includes result, '水素'       # nonmetal
  end

  # ----------------------------------------------------------------
  # slug による主キー検索（posts データ）
  # ----------------------------------------------------------------
  def test_should_lookup_post_by_slug
    content = "= post | my-first-post\n"
    result = render(content)

    assert_includes result, 'はじめての投稿'
    refute_includes result, 'Rubyの小技集'
  end

  # ----------------------------------------------------------------
  # コードブロック内のQueryStreamはスキップされる
  # ----------------------------------------------------------------
  def test_should_not_expand_inside_code_block
    content = "```\n= books\n```\n"
    result = render(content)

    assert_equal content, result
  end

  # ----------------------------------------------------------------
  # エラーハンドリング
  # ----------------------------------------------------------------

  # 存在しないデータファイルでエラーになる
  def test_should_raise_error_for_missing_data_file
    content = "= nonexistent\n"
    assert_raises(QueryStream::DataNotFoundError) do
      render(content)
    end
  end

  # 存在しないテンプレートでエラーになる
  def test_should_raise_error_for_missing_template
    content = "= books | :nonexistent_style\n"
    assert_raises(QueryStream::TemplateNotFoundError) do
      render(content)
    end
  end

  # 一件検索で0件の場合は空文字列になる
  def test_should_return_empty_for_zero_results_single_lookup
    content = "= book | 存在しない本\n"
    result = render(content)

    # QueryStream 行は空に置換されるが、前後のコンテンツは保持
    refute_includes result, '存在しない本'
  end

  # ----------------------------------------------------------------
  # パイプライン統合
  # ----------------------------------------------------------------

  # 通常のテキストとQueryStreamが共存できる
  def test_should_preserve_surrounding_content
    content = <<~MD
      # 参考書籍

      この章では参考書籍を紹介します。

      = books | tags=ruby && tags=beginner

      次の章では都道府県データを扱います。
    MD

    result = render(content)

    assert_includes result, '# 参考書籍'
    assert_includes result, 'この章では参考書籍を紹介します。'
    assert_includes result, '楽しいRuby'
    assert_includes result, '次の章では都道府県データを扱います。'
  end

  # 複数のQueryStreamが同一ファイル内で展開できる
  def test_should_expand_multiple_query_streams
    content = <<~MD
      = books | tags=ruby && tags=beginner

      ---

      = prefectures | region=関東
    MD

    result = render(content)

    assert_includes result, '楽しいRuby'
    assert_includes result, '東京都'
    assert_includes result, '---'
  end

  # ----------------------------------------------------------------
  # scan API
  # ----------------------------------------------------------------

  # scan でQueryStream記法を検出できる
  def test_should_scan_query_streams
    content = "# Title\n\n= books | tags=ruby\n\ntext\n\n= elements | :full\n"
    queries = QueryStream.scan(content)
    assert_equal 2, queries.size
    assert_equal '= books | tags=ruby', queries[0]
    assert_equal '= elements | :full', queries[1]
  end

  # =books（スペースなし）でも展開できる
  def test_should_expand_nospace_query_stream
    content = "=books\n"
    result = render(content)

    assert_includes result, '楽しいRuby'
    assert_includes result, 'はじめてのC'
  end

  # =books | :table（スペースなし）でスタイル指定も動作する
  def test_should_expand_nospace_query_stream_with_style
    content = "=books | :table\n"
    result = render(content)

    assert_includes result, '| タイトル |'
    assert_includes result, '| 楽しいRuby |'
  end

  # ----------------------------------------------------------------
  # VFM フェンス記法統合テスト
  # ----------------------------------------------------------------

  # :card スタイルでフェンス付きテンプレートが正しく展開される
  def test_should_expand_books_with_card_style
    content = "## Books\n\n= books | tags=ruby && tags=beginner | :card\n\n次へ\n"
    result = render(content)

    # 各書籍が個別のフェンスで囲まれる
    assert_equal 1, result.scan(':::{.book-card}').size, 'タグ絞り込みで1件のみ'
    assert_includes result, '**楽しいRuby**'
    assert_includes result, '## Books'
    assert_includes result, '次へ'
  end

  # :card スタイルで全件展開した場合、各レコードが個別フェンスを持つ
  def test_should_expand_all_books_with_card_style
    content = "= books | :card\n"
    result = render(content)

    # 4件の書籍データがあり、各自フェンスを持つ
    fence_count = result.scan(':::{.book-card}').size
    assert_operator fence_count, :>, 1, '複数レコードが個別フェンスを持つべき'
  end

  # scan でコードブロック内はスキップされる
  def test_scan_should_skip_code_blocks
    content = "= books\n\n```\n= elements\n```\n\n= prefectures\n"
    queries = QueryStream.scan(content)
    assert_equal 2, queries.size
    assert_equal '= books', queries[0]
    assert_equal '= prefectures', queries[1]
  end

  private

  # テスト用のrender ヘルパー
  def render(content)
    QueryStream.render(
      content,
      source_filename: 'test.md',
      data_dir: FIXTURE_DATA_DIR,
      templates_dir: FIXTURE_TEMPLATES_DIR
    )
  end
end
