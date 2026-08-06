# frozen_string_literal: true

# ================================================================
# Test: command_test.rb
# ================================================================
# 検証内容:
#   CLI（bin/query-stream）が、どの引数でも使い方を出して終わること。
#
#   ここは「利用者が最初に打つ 1 行」である。--help がスタックトレースで
#   落ちると、gem 自体が壊れているように見える。実際 print_usage を private に
#   置いていた頃は、Samovar が引数エラー時に外から呼ぶ経路で NoMethodError に
#   なっていた（--help と未知の引数の両方）。
# ================================================================

require_relative 'test_helper'
require 'query_stream/command'
require 'stringio'

class CommandTest < Minitest::Test
  # Samovar は引数エラー時に `error.command.print_usage(output:)` を外から呼ぶ。
  # private だとその場で NoMethodError になる
  def test_should_expose_print_usage_as_a_public_method
    assert_includes QueryStream::Command::Top.public_instance_methods, :print_usage
  end

  # Samovar から渡される output: を受け取れること
  def test_should_print_usage_to_the_given_output
    output = StringIO.new

    QueryStream::Command::Top.new([]).print_usage(output:)

    assert_includes output.string, 'Usage: query-stream'
    assert_includes output.string, '--version'
    assert_includes output.string, '--help'
  end

  # --version はバージョンだけを出す
  def test_should_print_version
    assert_output("query-stream #{QueryStream::VERSION}\n") do
      QueryStream::Command::Top.new(['--version']).call
    end
  end

  # 引数なしと --help はどちらも使い方を出す（落ちない）
  def test_should_print_usage_for_no_arguments_and_help
    [[], ['--help']].each do |argv|
      out, = capture_io { QueryStream::Command::Top.new(argv).call }

      assert_includes out, 'Usage: query-stream', "argv=#{argv.inspect} で使い方が出ること"
    end
  end
end
