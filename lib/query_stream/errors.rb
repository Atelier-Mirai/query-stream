# frozen_string_literal: true

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

  # テンプレートに、データレコードが持たないキーが書かれている
  #
  # 「どのキーが無いか」だけでなく「代わりに何が使えるか」「どのファイルを直すか」まで
  # 属性で渡す。呼び出し元はこれを使って「もしかして =author?」のような案内を組み立てられる。
  #
  # location（記法の位置）と template_path（雛形の位置）は別物である。
  # 直すのは雛形なので、記法の位置だけでは著者はファイルを開けない。
  #
  # @attr_reader key_path [String] テンプレートに書かれていたキー（"author.name" 等）
  # @attr_reader available_keys [Array<Symbol>] レコードが実際に持つキー
  # @attr_reader template_path [String, nil] 打ち間違いがあるテンプレートのパス
  # @attr_reader location [String] 記法が書かれていたソースファイル名と行番号
  class UnknownKeyError < Error
    attr_reader :key_path, :available_keys, :template_path, :location

    def initialize(msg = nil, key_path: nil, available_keys: [], template_path: nil, location: nil)
      super(msg || "テンプレートに存在しないキーが記述されています: #{key_path}")
      @key_path       = key_path
      @available_keys = Array(available_keys)
      @template_path  = template_path
      @location       = location
    end
  end

  # テンプレートで、そのままでは表示できない値（ハッシュ、またはハッシュや配列を含む配列）を出そうとした
  #
  # `= author` と書いて author が `{name:, bio:}` のとき、どれを出すかを gem は決められない。
  # Ruby の表記（{name: "…"}）を紙面に出さず、直し方を示せるだけの素材を渡す。
  # 文字列や数の配列は表示できる（list_separator でつなぐ）ので、このエラーにならない。
  #
  # @attr_reader key_path [String] テンプレートに書かれたキー（"author" 等）
  # @attr_reader available_keys [Array<Symbol>] ハッシュの中のキー（`= author.name` と書き直す候補）。配列のときは空
  # @attr_reader list [Boolean] ハッシュや配列を含む配列か（書き直す先のキーが無い）
  # @attr_reader template_path [String, nil] 直すテンプレートのパス
  # @attr_reader location [String] 記法が書かれていたソースファイル名と行番号
  class NestedValueError < Error
    attr_reader :key_path, :available_keys, :list, :template_path, :location

    def initialize(msg = nil, key_path: nil, available_keys: [], list: false, template_path: nil, location: nil)
      super(msg || "そのままでは表示できない値です: #{key_path}")
      @key_path       = key_path
      @available_keys = Array(available_keys)
      @list           = list
      @template_path  = template_path
      @location       = location
    end

    # テンプレートの位置と記法の位置を付け足して投げ直すときに使う（値を表示する箇所は位置を知らない）
    def with_context(template_path:, location:)
      self.class.new(message, key_path:, available_keys:, list:, template_path:, location:)
    end
  end

  # 抽出条件・並べ替えの指定が使えない
  #
  # 条件を無視して全件を出すと、書いた本人は絞り込んだつもりのまま気づけない。
  # 理由は 2 通りで、reason で見分ける。
  # - :unparseable   — 条件として読めない（`年=2019`・`tags=`・項目名の無い `ruby AND go`）
  # - :unknown_field — どのレコードにも無い項目を指している（`tag=ruby` の打ち間違い）
  #
  # @attr_reader reason [Symbol] :unparseable / :unknown_field
  # @attr_reader condition [String] 問題の条件（読めない綴り、または無い項目名）
  # @attr_reader available_keys [Array<Symbol>] レコードが実際に持つキー（:unknown_field のとき）
  # @attr_reader query [String] 元の QueryStream 記法
  # @attr_reader location [String] ソースファイル名と行番号
  class InvalidQueryError < Error
    attr_reader :reason, :condition, :available_keys, :query, :location

    def initialize(msg = nil, reason: :unparseable, condition: nil, available_keys: [], query: nil, location: nil)
      super(msg || default_message(reason, condition))
      @reason         = reason
      @condition      = condition
      @available_keys = Array(available_keys)
      @query          = query
      @location       = location
    end

    # 記法の位置を付け足して投げ直すときに使う（パーサーは位置を知らない）
    def with_context(query:, location:)
      self.class.new(message, reason:, condition:, available_keys:, query:, location:)
    end

    private

    def default_message(reason, condition)
      case reason
      when :unknown_field then "どのレコードにも無い項目です: #{condition}"
      else "抽出条件を読めません: #{condition}"
      end
    end
  end

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
