# frozen_string_literal: true

# ================================================================
# Test: robustness/broken_encoding_test.rb
# ================================================================
# 検証内容:
#   不正な UTF-8 バイト列を含む原稿でも render / scan が落ちないこと。
#
#   Ruby の String#match? も lstrip も、不正なバイト列に対して
#   `ArgumentError: invalid byte sequence in UTF-8` を投げる。素通しにすると
#   原稿に 1 バイトの壊れが混ざっただけで展開が丸ごと止まる。
#
#   **読めない行は本文としてそのまま返す**のが正しい振る舞いである。
#   scrub して通す設計は採らない——gem が黙ってバイト列を書き換えると、
#   著者が気付けない形で本文が変わる。
# ================================================================

require_relative '../test_helper'
require_relative 'robustness_helper'

class BrokenEncodingTest < Minitest::Test
  include RobustnessHelper

  # 不正バイトを含む「本文」（UTF-8 として壊れている）
  BROKEN = "\xFF\xFE壊れた行".dup.force_encoding(Encoding::UTF_8)

  def test_should_not_raise_when_content_has_invalid_utf8
    in_project do
      write_data('books.yml', "- title: A\n")
      write_template('_book.md', "=title\n")

      result = QueryStream.render("= books\n#{BROKEN}\n",
                                  data_dir: 'data', templates_dir: 'templates')

      assert_includes result, 'A', '正常な行の展開は止めないこと'
    end
  end

  # gem がバイト列を書き換えないこと。壊れた行は 1 バイトも変えずに返る
  def test_should_return_broken_bytes_untouched
    in_project do
      result = QueryStream.render("#{BROKEN}\n", data_dir: 'data', templates_dir: 'templates')

      assert_equal "#{BROKEN}\n".b, result.b, '壊れたバイト列を scrub してはならない'
    end
  end

  def test_scan_should_not_raise_on_invalid_utf8
    assert_equal ['= books'], QueryStream.scan("= books\n#{BROKEN}\n")
  end

  # 壊れた行がコードフェンス判定（lstrip）を通る位置にあっても落ちない
  def test_should_survive_broken_bytes_around_code_fence
    in_project do
      write_data('books.yml', "- title: A\n")
      write_template('_book.md', "=title\n")

      content = "```\n#{BROKEN}\n```\n= books\n"
      result = QueryStream.render(content, data_dir: 'data', templates_dir: 'templates')

      assert_includes result, 'A', 'フェンスを抜けた後の記法は展開されること'
    end
  end

  # 不正バイトを含む行は記法として解釈しない（誤展開させない）
  def test_should_not_treat_broken_line_as_query
    assert_empty QueryStream.scan("= books#{BROKEN}\n")
  end
end
