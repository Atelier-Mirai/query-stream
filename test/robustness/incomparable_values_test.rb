# frozen_string_literal: true

# ================================================================
# 検証内容:
#   比較やソートの対象の項目に、値が無いレコードや比較できない値のレコードが
#   混ざっていても、render が例外を外へ出さないこと。
#
#   比較と範囲では該当のレコードを除き、ソートでは末尾に置く。
# ================================================================

require_relative '../test_helper'
require_relative 'robustness_helper'

class IncomparableValuesTest < Minitest::Test
  include RobustnessHelper

  def setup_books(yaml)
    write_data('books.yml', yaml)
    write_template('_book.md', "=title\n")
  end

  def titles(output) = output.lines.map(&:strip).reject(&:empty?)

  def test_should_filter_records_without_the_field
    in_project do
      setup_books("- {title: 有, year: 2020}\n- {title: 無}\n")

      assert_equal ['有'], titles(render('= books | year>=2020'))
      assert_equal [], titles(render('= books | year>2020'))
    end
  end

  def test_should_sort_records_without_the_field_last
    in_project do
      setup_books("- {title: 無}\n- {title: 古, year: 2019}\n- {title: 新, year: 2021}\n")

      assert_equal %w[古 新 無], titles(render('= books | +year'))
      assert_equal %w[新 古 無], titles(render('= books | -year'))
      assert_equal %w[新 古], titles(render('= books | -year | 2'))
    end
  end

  def test_should_handle_text_mixed_with_numbers
    in_project do
      setup_books("- {title: 数, year: 2020}\n- {title: 字, year: 不明}\n")

      assert_equal ['数'], titles(render('= books | year>=2020'))
      assert_equal %w[数 字], titles(render('= books | -year'))
    end
  end

  def test_should_handle_text_mixed_with_dates
    in_project do
      setup_books("- {title: 日, date: 2024-01-01}\n- {title: 字, date: 未定}\n")

      assert_equal ['日'], titles(render('= books | date>=2024-01-01'))
      assert_equal %w[日 字], titles(render('= books | -date'))
    end
  end

  # 範囲の両端を比較できない記法も、例外にしない
  def test_should_not_raise_on_incomparable_range
    in_project do
      setup_books("- {title: 数, year: 2020}\n")

      assert_equal [], titles(render('= books | year=2020..abc'))
    end
  end
end
