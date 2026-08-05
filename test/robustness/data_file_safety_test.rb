# frozen_string_literal: true

# ================================================================
# Test: robustness/data_file_safety_test.rb
# ================================================================
# 検証内容:
#   著者が用意した YAML/JSON が壊れていても、gem の外へ出るのは
#   QueryStream::DataLoadError だけであること。
#   - !ruby/object 等の危険なタグ（Psych::DisallowedClass）
#   - 壊れた YAML / JSON（構文エラー）
#   - 空のデータファイル（YAML が nil を返す）
#   - レコードの配列でもハッシュでもない中身
# ================================================================

require_relative '../test_helper'
require_relative 'robustness_helper'

class DataFileSafetyTest < Minitest::Test
  include RobustnessHelper

  # !ruby/object は読み込まない。任意オブジェクト生成の入口を塞ぐのが目的で、
  # 例外型が変わると呼び出し元が「どのファイルが悪いか」を案内できなくなる
  def test_should_reject_ruby_object_tag_as_data_load_error
    in_project do
      write_data('evil.yml', "- !ruby/object:Gem::Requirement\n  title: x\n")

      error = assert_raises(QueryStream::DataLoadError) do
        QueryStream::DataResolver.load_records('data/evil.yml')
      end

      assert_kind_of Psych::DisallowedClass, error.cause_error
      assert_equal 'data/evil.yml', error.file_path
      assert_includes error.message, 'data/evil.yml', '直すべきファイルを名指しすること'
    end
  end

  def test_should_convert_broken_yaml_to_data_load_error
    in_project do
      write_data('broken.yml', "- title: [unclosed\n")

      error = assert_raises(QueryStream::DataLoadError) do
        QueryStream::DataResolver.load_records('data/broken.yml')
      end

      assert_kind_of Psych::SyntaxError, error.cause_error
      assert_includes error.message, 'YAML 構文エラー'
    end
  end

  def test_should_convert_broken_json_to_data_load_error
    in_project do
      write_data('broken.json', '{"a": ')

      error = assert_raises(QueryStream::DataLoadError) do
        QueryStream::DataResolver.load_records('data/broken.json')
      end

      assert_kind_of JSON::ParserError, error.cause_error
      assert_includes error.message, 'JSON 構文エラー'
    end
  end

  # 空のデータファイルで YAML は nil を返す。素通しすると呼び出し先が
  # `undefined method 'any?' for nil` で落ち、著者は NoMethodError を見ることになる
  def test_should_treat_empty_data_file_as_no_records
    in_project do
      write_data('books.yml', '')

      assert_equal [], QueryStream::DataResolver.load_records('data/books.yml')
    end
  end

  # 空データでも render は落ちず、その行は空展開になる
  def test_should_render_empty_data_without_raising
    in_project do
      write_data('books.yml', '')
      write_template('_book.md', "=title\n")

      assert_equal "\n", render('= books')
    end
  end

  # ハッシュ 1 件はレコード 1 件として受ける（既存の仕様）
  def test_should_wrap_single_hash_into_one_record
    in_project do
      write_data('books.yml', "title: A\n")

      assert_equal [{ title: 'A' }], QueryStream::DataResolver.load_records('data/books.yml')
    end
  end

  # レコード群として解釈しようがない中身は、理由を添えて弾く
  def test_should_reject_scalar_data_with_actionable_message
    in_project do
      write_data('books.yml', "just a string\n")

      error = assert_raises(QueryStream::DataLoadError) do
        QueryStream::DataResolver.load_records('data/books.yml')
      end

      assert_includes error.message, 'レコードの配列'
      assert_includes error.message, 'String', '何が入っていたかを示すこと'
    end
  end
end
