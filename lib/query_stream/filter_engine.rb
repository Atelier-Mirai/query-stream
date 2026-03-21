# frozen_string_literal: true

require 'date'

# ================================================================
# File: lib/query_stream/filter_engine.rb
# ================================================================
# 責務:
#   AND/OR/比較/Range によるフィルタリングとソート処理を行う。
#   日付の自動正規化にも対応する。
# ================================================================

module QueryStream
  # フィルタリング＆ソートエンジンモジュール
  module FilterEngine
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

    # ソート条件を適用する
    # @param records [Array<Hash>] レコード群
    # @param sort [Hash] ソート条件 { field:, direction: }
    # @return [Array<Hash>] ソート後のレコード群
    def apply_sort(records, sort)
      sorted = records.sort_by { to_comparable(it[sort[:field]]) }
      sort[:direction] == :desc ? sorted.reverse : sorted
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
      when :gt
        to_comparable(field_value) > to_comparable(filter[:value])
      when :gte
        to_comparable(field_value) >= to_comparable(filter[:value])
      when :lt
        to_comparable(field_value) < to_comparable(filter[:value])
      when :lte
        to_comparable(field_value) <= to_comparable(filter[:value])
      when :range
        range = filter[:value]
        range.cover?(to_comparable(field_value))
      else
        false
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
      field_list = normalize_to_list(field_value)
      value_list = Array(filter_values).map { it.to_s.strip }

      # フィールド側の値リストと条件値リストに交差があれば一致
      (field_list & value_list).any?
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

    # 比較用に値を正規化する（数値変換・日付変換を試みる）
    def to_comparable(value)
      case value
      when Date, Time
        value
      when String
        # 日付形式（YYYY-MM-DD）を検出して Date に変換
        if value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          begin
            return Date.parse(value)
          rescue Date::Error
            raise InvalidDateError, "無効な日付: #{value}"
          end
        end
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
