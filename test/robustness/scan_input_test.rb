# frozen_string_literal: true

# ================================================================
# Test: robustness/scan_input_test.rb
# ================================================================
# 検証内容:
#   QueryStream.scan は「ファイルパス」と「本文」のどちらも受け取る API である。
#   本文をそのまま File.exist? へ渡すと壊れるため、パスとして成立しうる形だけを
#   選別してから読む。
#     - NUL バイトを含む本文 → ArgumentError: path name contains null byte
#     - ディレクトリ         → File.exist? は true を返し File.read が Errno::EISDIR
#     - 極端に長い本文       → パスとして扱う意味がない
#   いずれも「本文」として扱い、例外を呼び出し元へ漏らさない。
# ================================================================

require_relative '../test_helper'
require_relative 'robustness_helper'

class ScanInputTest < Minitest::Test
  include RobustnessHelper

  def test_should_treat_content_with_null_byte_as_text
    assert_equal ['= books'], QueryStream.scan("= books\n\0埋め込まれた NUL\n")
  end

  def test_should_treat_multiline_content_as_text
    assert_equal ['= books', '= prefectures'], QueryStream.scan("= books\n本文\n= prefectures\n")
  end

  # PATH_MAX を超える長さの「パス」は実在しない。本文として走査する
  def test_should_treat_very_long_input_as_text
    long = "= books\n#{'あ' * 5000}\n"

    assert_equal ['= books'], QueryStream.scan(long)
  end

  # ディレクトリは File.exist? が true を返すため、File.file? で弾く必要がある
  def test_should_not_read_directory_as_file
    in_project do
      assert_empty QueryStream.scan('data')
    end
  end

  def test_should_read_an_actual_file_path
    in_project do
      File.write('doc.md', "= books\n本文\n")

      assert_equal ['= books'], QueryStream.scan('doc.md')
    end
  end

  def test_should_treat_empty_string_as_text
    assert_empty QueryStream.scan('')
  end

  # コードブロック内の記法は拾わない（既存の仕様。壊れた入力と混ざっても保つ）
  def test_should_skip_queries_inside_code_block
    content = "```\n= books\n```\n\0\n= prefectures\n"

    assert_equal ['= prefectures'], QueryStream.scan(content)
  end
end
