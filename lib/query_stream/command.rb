# frozen_string_literal: true

require 'samovar'

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
      # public かつ `output:` を受ける形にする。Samovar は引数の解析に失敗すると、外から
      # `error.command.print_usage(output: output)` を呼ぶ。
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
