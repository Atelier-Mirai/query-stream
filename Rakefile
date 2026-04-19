# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

task default: :test

# gem のアンインストール → ビルド → インストールを一括実行
task :reinstall do
  gemspec = Dir['*.gemspec'].first
  raise 'gemspec が見つかりません' unless gemspec

  require_relative 'lib/query_stream/version'
  version = QueryStream::VERSION
  gem_name = 'query-stream'
  gem_file = "#{gem_name}-#{version}.gem"

  sh "gem uninstall #{gem_name} --version #{version} --executables --ignore-dependencies 2>/dev/null || true"
  sh "gem build #{gemspec}"
  sh "gem install #{gem_file}"
end
