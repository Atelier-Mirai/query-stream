# frozen_string_literal: true

require 'samovar'

# ================================================================
# File: lib/query_stream/command.rb
# ================================================================
# 責務:
#   QueryStream の CLI コマンド。--version のみ提供する。
# ================================================================

module QueryStream
  module Command
    # トップレベルコマンド
    class Top < Samovar::Command
      self.description = 'QueryStream - YAML/JSON data renderer'

      options do
        option '--version', 'Print version and exit'
        option '--help', 'Print this message and exit'
      end

      # コマンド実行
      def call
        if @options[:version]
          puts "query-stream #{QueryStream::VERSION}"
        else
          print_usage
        end
      end

      # 使い方を表示する。
      #
      # public かつ `output:` を受ける形でなければならない。Samovar は引数の解析に
      # 失敗すると、外から `error.command.print_usage(output: output)` を呼んで
      # 使い方を出そうとする。private に置いていた頃は、そこで
      # `private method 'print_usage' called` の NoMethodError になり、
      # **`--help` と未知の引数がスタックトレースで落ちていた**。
      # @param output [IO] 出力先（Samovar からはエラー出力が渡される）
      def print_usage(output: $stdout)
        output.puts self.class.description
        output.puts 'Usage: query-stream [options]'
        output.puts '  --version  Print version and exit'
        output.puts '  --help     Print this message and exit'
      end
    end
  end
end
