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
  class TemplateNotFoundError < Error; end   # テンプレートファイルが存在しない
  class DataNotFoundError    < Error; end    # データファイルが存在しない
  class UnknownKeyError      < Error; end    # テンプレート内に存在しないキー
  class InvalidDateError     < Error; end    # 無効な日付

  # WARNING系（処理を続行）
  class AmbiguousQueryWarning < Warning; end # 一件検索で複数件ヒット
  class NoResultWarning       < Warning; end # 一件検索で0件ヒット
end
