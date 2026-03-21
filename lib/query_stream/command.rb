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
      end

      # コマンド実行
      def call
        if @options[:version]
          puts "query-stream #{QueryStream::VERSION}"
        else
          print_usage
        end
      end

      private

      def print_usage
        puts self.class.description
        puts "Usage: query-stream [options]"
        puts "  --version  Print version and exit"
      end
    end
  end
end
