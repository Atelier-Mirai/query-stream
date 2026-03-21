# frozen_string_literal: true

# ================================================================
# File: lib/query_stream/template_compiler.rb
# ================================================================
# 責務:
#   テンプレートファイル（_book.md 等）にデータを流し込み、
#   テキストを生成するコンパイラ。
#
# 変換ルール:
#   - `= key` のみの行 → key の値を展開（nil/空文字なら行スキップ）
#   - `prefix = key` → prefix を残してkey の値を展開
#   - `![](key)` → 変数展開（拡張子なし → 変数、拡張子あり → リテラル）
#   - `= key` を含まない行 → リテラル出力（ヘッダー等は一度だけ出力）
#   - 空行 → 改行出力
#
# テーブル記法対応:
#   `= key` を含む行のみ反復し、含まない行（ヘッダー・区切り行）は
#   一度だけ出力する。
#
# VFM フェンス記法対応:
#   :::{.book-card} 〜 ::: のようなフェンスが動的行を囲んでいる場合、
#   フェンス行も repeating 範囲に含めて各レコードごとに反復出力する。
#   {.person-card} 等の任意の VFM クラス名に汎用的に対応する。
# ================================================================

module QueryStream
  # テンプレートコンパイラモジュール
  module TemplateCompiler
    # 変数展開パターン: = key または =key（行内に出現、ドット記法対応）
    # (?<![=\w]) で width=40 や align=right 内の = を除外
    VARIABLE_PATTERN = /(?<![=\w])=\s*([a-zA-Z_][a-zA-Z0-9_.]*)/

    # 画像記法内の変数展開パターン: ![](key) / ![](= key)
    # 名前付きキャプチャで gsub ブロック内の $N 上書き問題を回避
    IMAGE_VAR_PATTERN = /!\[(?<alt>[^\]]*)\]\((?:=\s*)?(?<src>[^)]+)\)(?<attr>\{[^}]*\})?/

    # 画像の拡張子（リテラル判定用）
    IMAGE_EXTENSIONS = %w[png jpg jpeg webp gif svg].freeze

    # VFM フェンス開始行: :::{.class-name} 形式
    FENCE_OPEN_PATTERN = /\A:::\s*\{\.[\w-].*\}\s*\z/

    # VFM フェンス終了行: 単独の :::
    FENCE_CLOSE_PATTERN = /\A:::\s*\z/

    module_function

    # テンプレートにレコード群を流し込んでテキストを生成する
    # @param template [String] テンプレートの内容
    # @param records [Array<Hash>] データレコード群
    # @param source_filename [String, nil] エラー報告用ファイル名
    # @param line_number [Integer, nil] エラー報告用行番号
    # @return [String] 展開後のテキスト
    def render(template, records, source_filename: nil, line_number: nil)
      lines = template.lines
      validate_template_keys!(lines, records.first, source_filename:, line_number:) if records.any?

      parts = classify_lines(lines)
      return '' if records.empty?

      # 最初と最後の動的行を特定し、leading / repeating / trailing に三分割する
      first_dyn = parts.index { it[:type] == :dynamic }

      # 動的行がないテンプレートは全行をそのまま一度だけ出力
      unless first_dyn
        return parts.map { |p|
          p[:type] == :blank ? "\n" : p[:content]
        }.compact.join
      end

      last_dyn = parts.rindex { it[:type] == :dynamic }

      # --- Phase: フェンス行をrepeating範囲に取り込む ---
      # 動的行の直前にフェンス開始行がある場合、repeating 範囲を前方に拡張する
      # 動的行の直後にフェンス終了行がある場合、repeating 範囲を後方に拡張する
      # これにより :::{.book-card} 〜 ::: が各レコードごとに反復される
      first_dyn, last_dyn = expand_fence_range(parts, first_dyn, last_dyn)

      leading   = parts[0...first_dyn]
      repeating = parts[first_dyn..last_dyn]
      trailing  = last_dyn + 1 < parts.size ? parts[(last_dyn + 1)..] : []

      # テーブルテンプレート判定（区切り行 |---|…| の有無、またはデータ行が | で始まる）
      table_mode = leading.any? { it[:type] == :static && it[:content]&.match?(/^\|[-|:\s]+\|/) } ||
                   repeating.any? { it[:type] == :dynamic && it[:content]&.match?(/^\s*\|/) }

      output = []

      # leading: 静的ヘッダーを一度だけ出力
      leading.each do |part|
        case part
        in { type: :static, content: } then output << content
        in { type: :blank }            then output << "\n"
        end
      end

      # repeating: レコードごとに動的行を展開
      records.each_with_index do |record, idx|
        output << "\n" if idx > 0 && !table_mode

        repeating.each do |part|
          case part
          in { type: :dynamic, content: }
            expanded = expand_line(content, record)
            output << expanded if expanded
          in { type: :fence_open, content: } then output << content
          in { type: :fence_close, content: } then output << content
          in { type: :static, content: }
            output << content
          in { type: :blank }
            output << "\n" unless table_mode
          end
        end
      end

      # trailing: 末尾の静的行を一度だけ出力
      trailing.each do |part|
        case part
        in { type: :static, content: } then output << content
        in { type: :blank }            then output << "\n"
        end
      end

      output.join
    end

    # テンプレート行を分類する
    # @param lines [Array<String>] テンプレートの行リスト
    # @return [Array<Hash>] 分類済み行リスト
    def classify_lines(lines)
      lines.map do |line|
        stripped = line.strip
        if stripped.empty?
          { type: :blank }
        elsif stripped.match?(FENCE_OPEN_PATTERN)
          { type: :fence_open, content: line }
        elsif stripped.match?(FENCE_CLOSE_PATTERN)
          { type: :fence_close, content: line }
        elsif contains_variable?(line)
          { type: :dynamic, content: line }
        else
          { type: :static, content: line }
        end
      end
    end

    # VFM フェンス開始行かを判定する
    # @param line [String] テンプレート行
    # @return [Boolean]
    def fence_open?(line) = line.strip.match?(FENCE_OPEN_PATTERN)

    # VFM フェンス終了行かを判定する
    # @param line [String] テンプレート行
    # @return [Boolean]
    def fence_close?(line) = line.strip.match?(FENCE_CLOSE_PATTERN)

    # 動的行の前後にあるフェンス行を repeating 範囲に取り込む
    # フェンス開始→（空行）→動的行 のパターンや
    # 動的行→（空行）→フェンス終了 のパターンも考慮する
    # @param parts [Array<Hash>] 分類済み行リスト
    # @param first_dyn [Integer] 最初の動的行インデックス
    # @param last_dyn [Integer] 最後の動的行インデックス
    # @return [Array(Integer, Integer)] 拡張後の [first_dyn, last_dyn]
    def expand_fence_range(parts, first_dyn, last_dyn)
      # 前方拡張: フェンス開始行を取り込む（間に空行があっても可）
      idx = first_dyn - 1
      idx -= 1 if idx >= 0 && parts[idx][:type] == :blank
      first_dyn = idx if idx >= 0 && parts[idx][:type] == :fence_open

      # 後方拡張: フェンス終了行を取り込む（間に空行があっても可）
      idx = last_dyn + 1
      idx += 1 if idx < parts.size && parts[idx][:type] == :blank
      last_dyn = idx if idx < parts.size && parts[idx][:type] == :fence_close

      [first_dyn, last_dyn]
    end

    # 行に変数参照（= key）が含まれるかを判定する
    # @param line [String] テンプレート行
    # @return [Boolean]
    def contains_variable?(line)
      return true if line.match?(VARIABLE_PATTERN)
      return true if line.match?(IMAGE_VAR_PATTERN) && image_has_variable?(line)

      false
    end

    # 画像記法内に変数参照があるかを判定する
    # @param line [String] テンプレート行
    # @return [Boolean]
    def image_has_variable?(line)
      line.scan(IMAGE_VAR_PATTERN).any? do |(_, src, _)|
        src = src.sub(/\A=\s*/, '').strip
        !literal_image?(src)
      end
    end

    # 画像パスがリテラル（拡張子あり）かを判定する
    # @param src [String] 画像パス文字列
    # @return [Boolean]
    def literal_image?(src)
      ext = File.extname(src).delete_prefix('.').downcase
      IMAGE_EXTENSIONS.include?(ext)
    end

    # テンプレート行をレコードデータで展開する
    # nil/空文字のキーがあれば行ごとスキップ（nil を返す）
    # @param line [String] テンプレート行
    # @param record [Hash] データレコード
    # @return [String, nil] 展開後の行、またはスキップ時 nil
    def expand_line(line, record)
      result = line.dup

      # 画像記法の展開（先に処理）
      result = expand_images(result, record)
      return nil unless result

      # = key パターンの展開
      result = expand_variables(result, record)
      return nil unless result

      result
    end

    # 画像記法内の変数を展開する
    # @param line [String] テンプレート行
    # @param record [Hash] データレコード
    # @return [String, nil] 展開後の行、またはスキップ時 nil
    def expand_images(line, record)
      result = line.dup
      skip = false

      result.gsub!(IMAGE_VAR_PATTERN) do |match|
        md   = Regexp.last_match
        alt  = md[:alt]
        src  = md[:src].sub(/\A=\s*/, '').strip
        attr = md[:attr] || ''

        if literal_image?(src)
          # 拡張子ありはリテラルとしてそのまま出力
          match
        else
          # 変数として展開（ドット記法対応）
          value = resolve_nested_value(record, src)
          if value.nil? || value.to_s.strip.empty?
            skip = true
            match # gsub のブロックからは文字列を返す必要がある
          else
            "![#{alt}](#{value})#{attr}"
          end
        end
      end

      skip ? nil : result
    end

    # = key パターンの変数を展開する（ドット記法対応）
    # @param line [String] テンプレート行
    # @param record [Hash] データレコード
    # @return [String, nil] 展開後の行、またはスキップ時 nil
    def expand_variables(line, record)
      result = line.dup

      result.gsub!(VARIABLE_PATTERN) do |_match|
        key_path = $1
        value = resolve_nested_value(record, key_path)
        if value.nil? || value.to_s.strip.empty?
          return nil # 行ごとスキップ
        end
        value.to_s
      end

      result
    end

    # ドット記法のキーパスをたどってネストされた値を取得する
    # @param record [Hash] データレコード
    # @param key_path [String] キーパス（例: "author.name"）
    # @return [Object, nil] 値
    def resolve_nested_value(record, key_path)
      keys = key_path.split('.')
      value = record
      keys.each do |k|
        return nil unless value.is_a?(Hash)
        value = value[k.to_sym] || value[k.to_s]
      end
      value
    end

    # テンプレート内のキーがデータに存在するかを検証する
    # @param lines [Array<String>] テンプレートの行リスト
    # @param sample_record [Hash] サンプルレコード（最初の1件）
    # @param source_filename [String, nil] エラー報告用ファイル名
    # @param line_number [Integer, nil] エラー報告用行番号
    def validate_template_keys!(lines, sample_record, source_filename: nil, line_number: nil)
      return unless sample_record

      location = source_filename ? "#{source_filename}:#{line_number}" : ''
      available_keys = sample_record.keys

      lines.each do |line|
        # = key パターン（ドット記法の場合はルートキーのみ検証）
        line.scan(VARIABLE_PATTERN).each do |(key_path)|
          root_key = key_path.split('.').first.to_sym
          unless available_keys.include?(root_key)
            msg = "テンプレートに存在しないキーが記述されています: #{key_path}"
            QueryStream.logger.error("#{msg}(#{location})")
            QueryStream.logger.error("  利用可能なキー: #{available_keys.join(', ')}")
            raise UnknownKeyError, msg
          end
        end

        # 画像記法内の変数
        line.scan(IMAGE_VAR_PATTERN).each do |(_, src, _)|
          src = src.sub(/\A=\s*/, '').strip
          next if literal_image?(src)

          root_key = src.split('.').first.to_sym
          unless available_keys.include?(root_key)
            msg = "テンプレートに存在しないキーが記述されています: #{src}"
            QueryStream.logger.error("#{msg}(#{location})")
            QueryStream.logger.error("  利用可能なキー: #{available_keys.join(', ')}")
            raise UnknownKeyError, msg
          end
        end
      end
    end
  end
end
