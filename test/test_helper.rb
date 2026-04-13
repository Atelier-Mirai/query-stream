# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'query_stream'
require 'minitest/autorun'
require 'minitest/pride'

# テスト用のロガー（出力を抑制）
QueryStream.configure do |config|
  config.logger = Logger.new(File::NULL)
end
