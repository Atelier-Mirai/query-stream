# frozen_string_literal: true

require 'logger'

# ================================================================
# File: lib/query_stream/configuration.rb
# ================================================================
# 責務:
#   QueryStream のグローバル設定を管理する。
#   data_dir, templates_dir, default_format, logger の4項目。
# ================================================================

module QueryStream
  # グローバル設定クラス
  class Configuration
    # @return [String] データファイルのディレクトリ
    attr_accessor :data_dir

    # @return [String] テンプレートファイルのディレクトリ
    attr_accessor :templates_dir

    # @return [Symbol] スタイル省略時のデフォルト出力形式（:md / :html / :json）
    attr_accessor :default_format

    # @return [Logger] ログ出力先
    attr_accessor :logger

    def initialize
      @data_dir       = 'data'
      @templates_dir  = 'templates'
      @default_format = :md
      @logger         = Logger.new($stdout)
    end
  end
end
