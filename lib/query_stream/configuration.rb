# frozen_string_literal: true

# ================================================================
# File: lib/query_stream/configuration.rb
# ================================================================
# 責務:
#   QueryStream のグローバル設定を管理する。
#   data_dir, templates_dir, default_format, post_render の4項目。
#
# ログ出力の設定は持たない。gem 自身がログを出さないためである
# （失敗はすべて構造化例外として on_error / on_warning へ渡す）。
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

    # 1 記法の展開結果を、コンテキスト付きで呼び出し元へ通す後段フィルタ。
    # gem 自身は用途を規定しない（画像パス解決など呼び出し元固有の後処理を担わせる）。
    # @return [Proc, nil] (text, context) -> String。String 以外を返した場合は元の展開結果を採用する
    attr_accessor :post_render

    def initialize
      @data_dir       = 'data'
      @templates_dir  = 'templates'
      @default_format = :md
      @post_render    = nil
    end
  end
end
