# frozen_string_literal: true

# ================================================================
# Test: robustness/unreadable_file_test.rb
# ================================================================
# 検証内容:
#   読み取り権限の無いファイルに当たったとき、Errno::EACCES がそのまま伝わること。
#
#   ここは **DataLoadError へ包まない** のが意図した設計である。EACCES は
#   「データの中身の問題」ではなく「環境の問題」で、直し方（chmod）も別物になる。
#   包んで隠すと、著者は壊れていないファイルの中身を疑い続けることになる。
#
#   root 実行では権限が無視されるため skip する。
# ================================================================

require_relative '../test_helper'
require_relative 'robustness_helper'

class UnreadableFileTest < Minitest::Test
  include RobustnessHelper

  def test_should_propagate_eacces_for_unreadable_data_file
    in_project do
      write_data('books.yml', "- title: A\n")
      skip_unless_permission_enforced('data/books.yml')

      assert_raises(Errno::EACCES) { QueryStream::DataResolver.load_records('data/books.yml') }
    ensure
      File.chmod(0o644, 'data/books.yml') if File.exist?('data/books.yml')
    end
  end

  # render 経由でも同じ。Error 系に包まれないので on_error では捕まらず、
  # 呼び出し元まで環境の問題として届く
  def test_should_propagate_eacces_through_render
    in_project do
      write_data('books.yml', "- title: A\n")
      write_template('_book.md', "=title\n")
      skip_unless_permission_enforced('data/books.yml')

      assert_raises(Errno::EACCES) do
        QueryStream.render("= books\n", data_dir: 'data', templates_dir: 'templates',
                                        on_error: ->(_e) { flunk('環境の問題を Error 系へ包んではならない') })
      end
    ensure
      File.chmod(0o644, 'data/books.yml') if File.exist?('data/books.yml')
    end
  end

  # 読めないテンプレートも同様
  def test_should_propagate_eacces_for_unreadable_template
    in_project do
      write_data('books.yml', "- title: A\n")
      write_template('_book.md', "=title\n")
      skip_unless_permission_enforced('templates/_book.md')

      assert_raises(Errno::EACCES) do
        QueryStream.render_query('= books', data_dir: 'data', templates_dir: 'templates')
      end
    ensure
      File.chmod(0o644, 'templates/_book.md') if File.exist?('templates/_book.md')
    end
  end
end
