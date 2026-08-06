# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'query_stream'
require 'minitest/autorun'
require 'minitest/pride'

# ログ出力の抑制は不要。gem はログを出さず、失敗は例外として呼び出し元へ渡す。
