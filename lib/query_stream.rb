# frozen_string_literal: true

# ================================================================
# File: lib/query_stream.rb
# ================================================================
# 責務:
#   QueryStream gem のエントリポイント。
#   YAML/JSON データファイルとテンプレートファイルを組み合わせて、
#   テキストコンテンツ内の QueryStream 記法を展開する汎用ライブラリ。
#
# 公開 API:
#   QueryStream.render(source, **options)      - テキスト内の記法をすべて展開
#   QueryStream.render_query(query, **options)  - 単一の QueryStream 記法を展開
#   QueryStream.scan(path_or_content)           - 記法を検出してリストを返す
#   QueryStream.configure { |config| ... }      - 設定
# ================================================================

require_relative 'query_stream/version'
require_relative 'query_stream/errors'
require_relative 'query_stream/configuration'
require_relative 'query_stream/singularize'
require_relative 'query_stream/query_stream_parser'
require_relative 'query_stream/template_compiler'
require_relative 'query_stream/data_resolver'
require_relative 'query_stream/filter_engine'

module QueryStream
  # QueryStream 記法を検出する正規表現
  # 行頭 = の直後に英数字/ハイフン/アンダースコアのデータ名（スペースは任意）
  QUERY_STREAM_PATTERN = /^=\s*([a-zA-Z][a-zA-Z0-9_-]*)(?:\s*\|.*)?$/

  class << self
    # グローバル設定を返す
    # @return [Configuration]
    def configuration
      @configuration ||= Configuration.new
    end

    # 設定をブロックで変更する
    # @yield [Configuration]
    def configure
      yield(configuration)
    end

    # ロガーへのショートカット
    # @return [Logger]
    def logger
      configuration.logger
    end

    # テキストコンテンツ内の QueryStream 記法をすべて展開する
    # 1行の展開に失敗しても残りの行の処理を継続する。
    # エラー情報は例外の属性として呼び出し元に委ねる（gem 内ではログ出力しない）。
    # @param content [String] テキストコンテンツ
    # @param source_filename [String, nil] エラー報告用のソースファイル名
    # @param data_dir [String, nil] データディレクトリ（nil時はconfigを使用）
    # @param templates_dir [String, nil] テンプレートディレクトリ（nil時はconfigを使用）
    # @param on_error [Proc, nil] エラー時コールバック。|exception| を受け取る。省略時は何もしない。
    # @return [String] 展開後のテキストコンテンツ
    def render(content, source_filename: nil, data_dir: nil, templates_dir: nil, on_error: nil)
      data_dir      ||= configuration.data_dir
      templates_dir ||= configuration.templates_dir

      lines = content.lines
      result = []
      in_code_block = false

      lines.each_with_index do |line, idx|
        line_number = idx + 1

        # コードブロック内はスキップ
        if line.lstrip.start_with?('```')
          in_code_block = !in_code_block
          result << line
          next
        end

        if in_code_block
          result << line
          next
        end

        # QueryStream 記法の検出
        if line.match?(QUERY_STREAM_PATTERN)
          begin
            expanded = render_query(
              line.chomp, line_number:, source_filename:, data_dir:, templates_dir:
            )
            result << expanded << "\n"
          rescue Error => e
            # 1行の失敗で残りの展開を止めない。エラー処理は呼び出し元に委ねる。
            on_error&.call(e)
            result << line
          end
        else
          result << line
        end
      end

      result.join
    end

    # 単一の QueryStream 記法を展開する
    # @param query [String] QueryStream 記法の行（例: "= books | tags=ruby | :full"）
    # @param line_number [Integer, nil] 行番号（エラー報告用）
    # @param source_filename [String, nil] ソースファイル名
    # @param data_dir [String, nil] データディレクトリ
    # @param templates_dir [String, nil] テンプレートディレクトリ
    # @return [String] 展開後のテキスト
    def render_query(query, line_number: nil, source_filename: nil, data_dir: nil, templates_dir: nil)
      data_dir      ||= configuration.data_dir
      templates_dir ||= configuration.templates_dir
      location = source_filename ? "#{source_filename}:#{line_number}" : "行#{line_number}"

      # --- Phase: Parse ---
      parsed = QueryStreamParser.parse(query)

      # --- Phase: Load Data ---
      # gem 内でログ出力せず、構造化された属性を持つ例外を raise する。
      # メッセージの構成・ログ出力・i18n は呼び出し元の責務とする。
      data_file = DataResolver.resolve(parsed[:source], data_dir)
      unless data_file
        expected = File.join(data_dir, "#{parsed[:source]}.yml")
        raise DataNotFoundError.new(
          expected_path: expected,
          query:         query,
          location:      location
        )
      end

      records = DataResolver.load_records(data_file)

      # --- Phase: Filter ---
      records = FilterEngine.apply_filters(records, parsed[:filters])

      # --- Phase: Sort ---
      records = FilterEngine.apply_sort(records, parsed[:sort]) if parsed[:sort]

      # --- Phase: Limit ---
      records = records.first(parsed[:limit]) if parsed[:limit]

      # --- Phase: Single record warning ---
      if parsed[:single_lookup]
        case records.size
        when 0
          logger.warn("一件検索で該当なし(#{location}): #{query}")
          return ''
        when 1
          # 正常
        else
          logger.warn("一件検索で複数件ヒット(#{location}): #{query}")
          logger.warn("  #{records.size}件見つかりました。条件を明示してください。")
        end
      end

      # --- Phase: Resolve Template ---
      singular = Singularize.call(parsed[:source])
      style = parsed[:style]
      format = parsed[:format]
      template_path = resolve_template_path(singular, style, format, templates_dir)

      unless File.exist?(template_path)
        hint = build_template_hint(singular, style, format, templates_dir)
        # gem 内でログ出力せず、構造化された属性を持つ例外を raise する。
        # メッセージの構成・ログ出力・i18n は呼び出し元の責務とする。
        raise TemplateNotFoundError.new(
          template_path: template_path,
          query:         query,
          location:      location,
          hint:          hint
        )
      end

      template_content = File.read(template_path, encoding: 'utf-8')

      # --- Phase: Render ---
      TemplateCompiler.render(template_content, records, source_filename:, line_number:)
    end

    # テキスト内の QueryStream 記法を検出してリストを返す
    # @param path_or_content [String] ファイルパスまたはテキストコンテンツ
    # @return [Array<String>] 検出された QueryStream 記法のリスト
    def scan(path_or_content)
      content = File.exist?(path_or_content) ? File.read(path_or_content, encoding: 'utf-8') : path_or_content
      lines = content.lines
      queries = []
      in_code_block = false

      lines.each do |line|
        if line.lstrip.start_with?('```')
          in_code_block = !in_code_block
          next
        end
        next if in_code_block

        queries << line.chomp if line.match?(QUERY_STREAM_PATTERN)
      end

      queries
    end

    private

    # テンプレートファイルパスを解決する
    # @param singular_name [String] 単数形のデータ名
    # @param style [String, nil] スタイル名
    # @param format [String, nil] 出力形式（拡張子）
    # @param templates_dir [String] テンプレートディレクトリ
    # @return [String] テンプレートファイルパス
    def resolve_template_path(singular_name, style, format, templates_dir)
      ext = format || configuration.default_format.to_s
      ext = 'md' if ext == 'md' || ext.empty?

      if style
        # :table.html → _book.table.html
        # :full → _book.full.md
        if format
          File.join(templates_dir, "_#{singular_name}.#{style}.#{format}")
        else
          File.join(templates_dir, "_#{singular_name}.#{style}.#{ext}")
        end
      else
        File.join(templates_dir, "_#{singular_name}.#{ext}")
      end
    end

    # テンプレート不在時のヒントメッセージを生成する
    def build_template_hint(singular_name, style, format, templates_dir)
      default_ext = format || configuration.default_format.to_s
      default_ext = 'md' if default_ext == 'md' || default_ext.empty?
      default_path = File.join(templates_dir, "_#{singular_name}.#{default_ext}")

      if style && File.exist?(default_path)
        "#{default_path} は存在します。スタイル名を確認してください。"
      else
        nil
      end
    end
  end
end
