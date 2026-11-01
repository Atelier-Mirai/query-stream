# frozen_string_literal: true

require_relative 'lib/query_stream/version'

Gem::Specification.new do |spec|
  spec.name          = 'query-stream'
  spec.version       = QueryStream::VERSION
  spec.authors       = ['Atelier Mirai']
  spec.email         = ['contact@atelier-mirai.net']

  spec.summary       = 'YAML / JSON のデータとテンプレートから、文章中の 1 行の記法を展開する Ruby ライブラリ'
  spec.description   = 'QueryStream は、文章中に書いた `= books | tags=ruby | -year | 5` のような 1 行の記法を、' \
                       'YAML / JSON のデータファイルとテンプレートを組み合わせて展開する汎用の Ruby ライブラリです。' \
                       '抽出条件、並べ替え、件数、スタイルを指定できます。'
  spec.homepage      = 'https://github.com/Atelier-Mirai/query-stream'
  spec.license       = 'MIT'

  spec.metadata['source_code_uri'] = 'https://github.com/Atelier-Mirai/query-stream'
  spec.metadata['changelog_uri']   = 'https://github.com/Atelier-Mirai/query-stream/blob/master/CHANGELOG.md'

  spec.required_ruby_version = '>= 3.4'

  spec.files = Dir.glob('{lib,bin}/**/*') +
               %w[README.md CHANGELOG.md RELEASE_NOTE.md LICENSE query-stream.gemspec]
  spec.bindir        = 'bin'
  spec.executables   = ['query-stream']
  spec.require_paths = ['lib']

  spec.add_dependency 'samovar', '~> 2.1'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake', '~> 13.2'
  spec.add_development_dependency 'minitest', '>= 5.22'
  spec.add_development_dependency 'rubocop', '~> 1.81'
  spec.metadata['rubygems_mfa_required'] = 'false'
end
