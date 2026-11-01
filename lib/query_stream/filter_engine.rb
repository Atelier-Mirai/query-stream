# frozen_string_literal: true

require 'date'

# ================================================================
# 責務:
#   AND/OR/比較/Range によるフィルタリングとソート処理を行う。
#   日付の自動正規化にも対応する。
# ================================================================

module QueryStream
  # フィルタリング＆ソートエンジンモジュール
  module FilterEngine
    # 西暦の日付（2024-01-01）
    SEIREKI_DATE = /\A\d{4}-\d{2}-\d{2}\z/

    # 和暦の日付（R06-01-01）。元号は頭文字で書く（M 明治・T 大正・S 昭和・H 平成・R 令和）。
    # 年は 1 桁でもよい（R6-01-01）。
    WAREKI_DATE = /\A(?<era>[MTSHR])(?<year>\d{1,2})-(?<month>\d{2})-(?<day>\d{2})\z/

    # 大小の条件と、<=> の結果の判定
    ORDER_TESTS = {
      gt:  ->(order) { order.positive? },
      gte: ->(order) { order >= 0 },
      lt:  ->(order) { order.negative? },
      lte: ->(order) { order <= 0 }
    }.freeze

    module_function

    # フィルタ条件をレコード群に適用する
    # @param records [Array<Hash>] レコード群
    # @param filters [Array<Hash>] フィルタ条件の配列
    # @return [Array<Hash>] フィルタ後のレコード群
    def apply_filters(records, filters)
      return records if filters.nil? || filters.empty?

      records.select do |record|
        filters.all? { evaluate_filter(record, it) }
      end
    end

    # ソート条件を適用する。
    # 比べるのは最も多い種類の値で、それ以外の値と、値が無いレコードは、向きによらず末尾に置く。
    # @param records [Array<Hash>] レコード群
    # @param sort [Hash] ソート条件 { field:, direction: }
    # @return [Array<Hash>] ソート後のレコード群
    def apply_sort(records, sort)
      keyed = records.map do |record|
        value = record[sort[:field]]
        [record, missing_value?(value) ? nil : to_comparable(value)]
      end
      kind = keyed.filter_map { |_, key| sort_kind(key) }.tally.max_by { |_, count| count }&.first

      sortable, others = keyed.partition { |_, key| sort_kind(key) == kind }
      sorted = sortable.sort_by(&:last).map(&:first)
      (sort[:direction] == :desc ? sorted.reverse : sorted) + others.map(&:first)
    end

    # 単一フィルタ条件をレコードに対して評価する
    # @param record [Hash] 単一レコード
    # @param filter [Hash] フィルタ条件 { field:, op:, value: }
    # @return [Boolean] 条件に合致するか
    def evaluate_filter(record, filter)
      # 主キー検索（_primary_key）の特別処理
      if filter[:field] == :_primary_key
        return evaluate_primary_key_lookup(record, filter[:value])
      end

      field_value = record[filter[:field]]

      case filter[:op]
      when :eq
        match_eq(field_value, filter[:value])
      when :neq
        !match_eq(field_value, filter[:value])
      when :gt, :gte, :lt, :lte
        satisfies_order?(field_value, filter)
      when :range
        within_range?(field_value, filter[:value])
      when :or
        filter[:branches].any? { |branch| branch.all? { evaluate_filter(record, it) } }
      else
        false
      end
    end

    # 大小の条件を満たすか。値が無いレコードと、比較できない値のレコードは満たさない
    # @param field_value [Object] レコードの値
    # @param filter [Hash] フィルタ条件 { op:, value: }
    # @return [Boolean]
    def satisfies_order?(field_value, filter)
      return false if missing_value?(field_value)

      order = to_comparable(field_value) <=> to_comparable(filter[:value])
      !order.nil? && ORDER_TESTS.fetch(filter[:op]).call(order)
    end

    # 範囲に含まれるか。両端も比較用にそろえる。パーサーは "2024-06-01".."2024-06-30" のような
    # 文字列の範囲を返すので、そのままでは Date の値を含まない。
    # @param field_value [Object] レコードの値
    # @param range [Range] 範囲
    # @return [Boolean]
    def within_range?(field_value, range)
      Range.new(to_comparable(range.begin), to_comparable(range.end), range.exclude_end?)
           .cover?(to_comparable(field_value))
    rescue ArgumentError
      # 両端を比較できない範囲（Range.new が受け付けない）
      false
    end

    # 値が無いか（キーが無い・nil・空文字列）
    def missing_value?(value) = value.nil? || value == ''

    # ソートで比べられる値の種類。値が無いときは nil
    def sort_kind(key)
      case key
      when nil then nil
      when Numeric then :number
      when Date then :date
      when Time then :time
      else :string
      end
    end

    # 主キー候補フィールドを順番に走査して一致するものを探す
    # @param record [Hash] 単一レコード
    # @param query_value [Object] 検索値
    # @return [Boolean] いずれかの主キー候補と一致するか
    def evaluate_primary_key_lookup(record, query_value)
      QueryStreamParser::PRIMARY_KEY_FIELDS.any? do |key|
        record[key]&.to_s == query_value.to_s
      end
    end

    # 等値比較（配列・カンマ区切り文字列を透過的に扱う）
    # データ側が配列/カンマ区切りの場合、ORの値リストと交差判定する
    def match_eq(field_value, filter_values)
      # 綴りの揺れは両側でそろえる。条件側だけそろえると、データに "2024_01" や
      # "R06-01-01" のような文字列があるとき、同じ綴りの条件で一致しなくなる。
      field_list = normalize_to_list(field_value).map { canonical_token(it) }
      value_list = Array(filter_values).map { canonical_token(it.to_s.strip) }

      # フィールド側の値リストと条件値リストに交差があれば一致
      (field_list & value_list).any?
    end

    # 等値比較のため、値を綴りの揺れのない形へそろえる。
    # 数は桁区切りを外し（9_000_000 → 9000000）、日付は西暦にする（R06-01-01 → 2024-01-01）。
    # 存在しない日付は、等値比較では文字列のまま比べる。
    def canonical_token(str)
      date = parse_date(str)
      date ? date.iso8601 : QueryStreamParser.strip_digit_separators(str)
    rescue InvalidDateError
      str
    end

    # フィールド値をリスト化する（配列/カンマ区切り/単値を統一）
    def normalize_to_list(value)
      case value
      when Array
        value.map { it.to_s.strip }
      when String
        value.split(',').map { it.strip }
      when nil
        []
      else
        [value.to_s.strip]
      end
    end

    # 西暦・和暦の日付を Date に直す。日付の形でなければ nil を返す。
    # 和暦は Date.jisx0301 に任せる。Date.parse は "R06-01-01" を 2006-01-01 と
    # 読み違えるので使えない。jisx0301 の区切りはドットで、年は 2 桁が要る。
    # 元号の境目は検査しない（H31-05-01 も 2019-05-01 として読む）。
    # @raise [InvalidDateError] 日付の形だが存在しない日（2024-02-30 など）
    def parse_date(value)
      if value.match?(SEIREKI_DATE)
        Date.parse(value)
      elsif (m = value.match(WAREKI_DATE))
        Date.jisx0301("#{m[:era]}#{m[:year].rjust(2, '0')}.#{m[:month]}.#{m[:day]}")
      end
    rescue Date::Error
      raise InvalidDateError, "無効な日付: #{value}"
    end

    # 比較用に値を正規化する（数値変換・日付変換を試みる）
    def to_comparable(value)
      case value
      when Date, Time
        value
      when String
        # 日付形式（西暦・和暦）を検出して Date に変換
        date = parse_date(value)
        return date if date

        # 数値変換を試みる
        case value
        when /\A-?\d+\z/
          value.to_i
        when /\A-?\d+\.\d+\z/
          value.to_f
        else
          value
        end
      when Integer, Float
        value
      else
        value.to_s
      end
    end
  end
end
