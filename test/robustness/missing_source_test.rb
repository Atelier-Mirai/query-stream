# frozen_string_literal: true

# ================================================================
# Test: robustness/missing_source_test.rb
# ================================================================
# 検証内容:
#   データ／テンプレートが無いときの振る舞い。
#   gem 内ではログを出さず、構造化された属性を持つ例外を投げ、
#   render は該当行を素通しして残りの展開を続ける（1 行の失敗で全体を止めない）。
#
#   属性（expected_path / template_path / query / location / hint）は
#   呼び出し元がメッセージを組み立てるための情報なので、有無まで固定する。
# ================================================================

require_relative '../test_helper'
require_relative 'robustness_helper'

class MissingSourceTest < Minitest::Test
  include RobustnessHelper

  def test_should_raise_data_not_found_with_attributes
    in_project do
      error = assert_raises(QueryStream::DataNotFoundError) do
        QueryStream.render_query('= nosuch', line_number: 3, source_filename: 'doc.md',
                                             data_dir: 'data', templates_dir: 'templates')
      end

      assert_includes error.expected_path, 'nosuch'
      assert_equal '= nosuch', error.query
      assert_equal 'doc.md:3', error.location, '呼び出し元が出現箇所を示せること'
    end
  end

  # スタイル名だけ違う（既定テンプレートは在る）ときは、そこを直せば済むと伝える
  def test_should_hint_when_only_the_style_name_is_wrong
    in_project do
      write_data('books.yml', "- title: A\n")
      write_template('_book.md', "=title\n")

      error = assert_raises(QueryStream::TemplateNotFoundError) do
        QueryStream.render_query('= books | :nostyle', data_dir: 'data', templates_dir: 'templates')
      end

      assert_includes error.template_path, 'nostyle'
      assert_includes error.hint, '_book.md'
      assert_includes error.hint, 'スタイル名'
    end
  end

  # テンプレートが 1 つも無いときは hint を作れない。**当てずっぽうを返さない**のが
  # 正しく、呼び出し元は template_path だけで案内する
  def test_should_not_invent_a_hint_when_nothing_is_close
    in_project do
      write_data('books.yml', "- title: A\n")

      error = assert_raises(QueryStream::TemplateNotFoundError) do
        QueryStream.render_query('= books | :nostyle', data_dir: 'data', templates_dir: 'templates')
      end

      assert_nil error.hint
      assert_includes error.template_path, 'nostyle'
    end
  end

  # render は 1 行の失敗で止まらない。失敗行は原文のまま残る
  def test_render_should_keep_failing_line_and_continue
    in_project do
      write_data('books.yml', "- title: A\n")
      write_template('_book.md', "=title\n")

      errors = []
      result = QueryStream.render("= nosuch\n= books\n", data_dir: 'data', templates_dir: 'templates',
                                                        on_error: ->(e) { errors << e })

      assert_includes result, '= nosuch', '失敗した行は原文のまま残すこと'
      assert_includes result, 'A', '後続の行は展開すること'
      assert_equal [QueryStream::DataNotFoundError], errors.map(&:class)
    end
  end

  # データ名にパストラバーサルを書いても、記法として解釈されないので何も読まない
  def test_should_not_resolve_path_traversal_as_data_source
    in_project do
      result = QueryStream.render("= ../../etc/passwd\n", data_dir: 'data', templates_dir: 'templates')

      assert_equal "= ../../etc/passwd\n", result, '記法として解釈せず素通しすること'
    end
  end
end
