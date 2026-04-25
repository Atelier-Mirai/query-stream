# frozen_string_literal: true

# ================================================================
# File: lib/query_stream/singularize.rb
# ================================================================
# 責務:
#   英単語の複数形を単数形に変換する軽量ヘルパー。
#   ActiveSupport::Inflector に依存せず、パターンマッチングで実装する。
#
# 例:
#   books       → book
#   categories  → category
#   branches    → branch
#   shelves     → shelf
#   elements    → element
#   data        → data（不変）
# ================================================================

module QueryStream
  # 英単語の複数形→単数形変換モジュール
  module Singularize
    module_function

    # 複数形の英単語を単数形に変換する
    # @param word [String] 変換対象の単語
    # @return [String] 単数形の単語
    def call(word)
      str = word.to_s

      # アンダースコア付きの複合名は、末尾の s で終わるセグメントを単数化する
      # physics_books → physics_book, books_nested → book_nested, books2 → book2
      if str.include?('_')
        segments = str.split('_')
        # people は不規則変化なので優先的に単数化
        people_idx = segments.index { it.match?(/\Apeople\z/i) }
        if people_idx
          segments[people_idx] = singularize_simple(segments[people_idx])
          return segments.join('_')
        end
        # 末尾から探して最初に見つかった複数形セグメントを単数化
        idx = segments.rindex { singularize_simple(it) != it }
        if idx
          segments[idx] = singularize_simple(segments[idx])
          return segments.join('_')
        end
      end

      singularize_simple(str)
    end

    # 単一単語の単数化
    def singularize_simple(word)
      case word.to_s
      in /\Apeople(.*)\z/i             then "person#{$1}"
      in /\A(.+)ies\z/                 then "#{$1}y"
      in /\A(.+)([sxz]|ch|sh)es\z/    then "#{$1}#{$2}"
      in /\A(.+)ves\z/                 then "#{$1}f"
      in /\A(.+?)s([0-9].*)\z/         then "#{$1}#{$2}"
      in /\A(.+)s\z/                   then $1
      else word
      end
    end
  end
end