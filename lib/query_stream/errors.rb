# frozen_string_literal: true

# ================================================================
# File: lib/query_stream/errors.rb
# ================================================================
# 責務:
#   QueryStream の例外クラス体系を定義する。
#   ERROR系は処理を中断し、WARNING系は処理を続行する。
# ================================================================

module QueryStream
  # 基底クラス
  class Error   < StandardError; end
  class Warning < StandardError; end

  # ERROR系（処理を中断）
  #
  # 各エラークラスは構造化された属性を持つ。
  # gem 内ではログ出力を行わず、呼び出し元が属性を使って
  # 独自のメッセージ・i18n・フォーマットを構成する。

  # テンプレートファイルが存在しない
  # @attr_reader template_path [String] 期待されたテンプレートパス
  # @attr_reader query [String] 元の QueryStream 記法
  # @attr_reader location [String] ソースファイル名と行番号
  # @attr_reader hint [String, nil] 修正ヒント
  class TemplateNotFoundError < Error
    attr_reader :template_path, :query, :location, :hint

    def initialize(msg = nil, template_path: nil, query: nil, location: nil, hint: nil)
      super(msg || "テンプレートファイルが見つかりません: #{template_path}")
      @template_path = template_path
      @query         = query
      @location      = location
      @hint          = hint
    end
  end

  # データファイルが存在しない
  # @attr_reader expected_path [String] 期待されたデータファイルパス
  # @attr_reader query [String] 元の QueryStream 記法
  # @attr_reader location [String] ソースファイル名と行番号
  class DataNotFoundError < Error
    attr_reader :expected_path, :query, :location

    def initialize(msg = nil, expected_path: nil, query: nil, location: nil)
      super(msg || "データファイルが見つかりません: #{expected_path}")
      @expected_path = expected_path
      @query         = query
      @location      = location
    end
  end

  class UnknownKeyError  < Error; end    # テンプレート内に存在しないキー
  class InvalidDateError < Error; end    # 無効な日付

  # データファイルの読み込みに失敗した
  # （YAML/JSON 構文エラー、YAML で許可されていないクラス/タグ等）
  #
  # セキュリティ設計:
  #   YAML データファイルは `YAML.safe_load_file` で読み込まれ、
  #   `!ruby/object` など危険な Ruby オブジェクトタグは
  #   `Psych::DisallowedClass` として検出され、本例外に変換される。
  #
  # @attr_reader file_path [String] 読み込みに失敗したファイルパス
  # @attr_reader cause_error [StandardError, nil] 元の例外（Psych::DisallowedClass 等）
  class DataLoadError < Error
    attr_reader :file_path, :cause_error

    def initialize(msg = nil, file_path: nil, cause_error: nil)
      super(msg || "データファイルの読み込みに失敗しました: #{file_path}")
      @file_path = file_path
      @cause_error = cause_error
    end
  end

  # WARNING系（処理を続行）
  #
  # ERROR と同様に構造化された属性を持ち、gem 内ではログ出力を行わず、
  # 呼び出し元が on_warning コールバックで独自メッセージを構成する。

  # 一件検索で0件ヒット
  # @attr_reader query [String] 元の QueryStream 記法
  # @attr_reader location [String] ソースファイル名と行番号
  class NoResultWarning < Warning
    attr_reader :query, :location

    def initialize(msg = nil, query: nil, location: nil)
      super(msg || "一件検索で該当なし: #{query}")
      @query    = query
      @location = location
    end
  end

  # 一件検索で複数件ヒット
  # @attr_reader query [String] 元の QueryStream 記法
  # @attr_reader location [String] ソースファイル名と行番号
  # @attr_reader count [Integer] ヒット件数
  class AmbiguousQueryWarning < Warning
    attr_reader :query, :location, :count

    def initialize(msg = nil, query: nil, location: nil, count: nil)
      super(msg || "一件検索で複数件ヒット(#{count}件): #{query}")
      @query    = query
      @location = location
      @count    = count
    end
  end
end
