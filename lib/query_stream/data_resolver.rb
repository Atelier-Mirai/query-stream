# frozen_string_literal: true

require 'yaml'
require 'json'

# ================================================================
# File: lib/query_stream/data_resolver.rb
# ================================================================
# 責務:
#   データファイルの探索・単数形/複数形の自動解決を行う。
#   YAML (.yml, .yaml) と JSON (.json) をサポートする。
#
# セキュリティ設計:
#   YAML データファイルは `YAML.safe_load_file` で読み込む。
#   `permitted_classes` は Symbol / Time / Date / DateTime に限定し、
#   `!ruby/object` 等の Ruby オブジェクトタグは `Psych::DisallowedClass`
#   として検出し、`QueryStream::DataLoadError` に変換する。
#   `aliases: true` は DRY な YAML 記述のために許可するが、
#   Psych 5.x の Billion Laughs 対策により DoS 耐性がある。
# ================================================================

require_relative 'errors'

module QueryStream
  # データファイル探索・読み込みモジュール
  module DataResolver
    # サポートする拡張子（優先順位順）
    EXTENSIONS = %w[.yml .yaml .json].freeze

    # YAML.safe_load_file で許可するクラス
    # Symbol: symbolize_names: true のために必要
    # Time/Date/DateTime: 日付/時刻を含む実用データに対応
    YAML_PERMITTED_CLASSES = [Symbol, Time, Date, DateTime].freeze

    module_function

    # データファイルのパスを解決する
    # 指定名そのまま → 複数形（末尾に s を付与）→ 単数形の順で探索する
    # @param source_name [String] データ名（単数形または複数形）
    # @param data_dir [String] データディレクトリ
    # @return [String, nil] 見つかったファイルパス、または nil
    def resolve(source_name, data_dir)
      # そのまま試行
      found = find_with_extensions(source_name, data_dir)
      return found if found

      # 複数形を試行（単数形→複数形: book → books）
      found = find_with_extensions("#{source_name}s", data_dir)
      return found if found

      # 単数形を試行（複数形→単数形: books → book）
      singular = Singularize.call(source_name)
      if singular != source_name
        found = find_with_extensions(singular, data_dir)
        return found if found
      end

      nil
    end

    # レコード群をファイルから読み込む
    #
    # YAML は `safe_load_file` で読み込み、`!ruby/object` 等の危険なタグを
    # `QueryStream::DataLoadError` に変換して呼び出し元に通知する。
    #
    # @param file_path [String] データファイルパス
    # @return [Array<Hash>] レコード群（シンボルキー）
    # @raise [DataLoadError] YAML/JSON の構文エラー、許可されていないクラス等
    def load_records(file_path)
      records = case File.extname(file_path).downcase
                when '.json'
                  JSON.parse(File.read(file_path, encoding: 'utf-8'), symbolize_names: true)
                else
                  YAML.safe_load_file(file_path,
                                      permitted_classes: YAML_PERMITTED_CLASSES,
                                      aliases: true,
                                      symbolize_names: true)
                end

      records = [records] if records.is_a?(Hash)
      records
    rescue Psych::DisallowedClass => e
      raise DataLoadError.new(
        "データファイルに許可されていないクラス/タグが含まれています: #{e.message} (#{file_path})",
        file_path: file_path, cause_error: e
      )
    rescue Psych::SyntaxError => e
      raise DataLoadError.new(
        "データファイルの YAML 構文エラー: #{e.message} (#{file_path})",
        file_path: file_path, cause_error: e
      )
    rescue JSON::ParserError => e
      raise DataLoadError.new(
        "データファイルの JSON 構文エラー: #{e.message} (#{file_path})",
        file_path: file_path, cause_error: e
      )
    end

    # 指定名ですべての拡張子を試行する
    # @param base_name [String] 拡張子なしファイル名
    # @param data_dir [String] データディレクトリ
    # @return [String, nil] 見つかったファイルパス、または nil
    def find_with_extensions(base_name, data_dir)
      EXTENSIONS.each do |ext|
        path = File.join(data_dir, "#{base_name}#{ext}")
        return path if File.exist?(path)
      end
      nil
    end
  end
end
