# frozen_string_literal: true

require_relative 'lib/query_stream/version'

Gem::Specification.new do |spec|
  spec.name          = 'query-stream'
  spec.version       = QueryStream::VERSION
  spec.authors       = ['Atelier Mirai']
  spec.email         = ['contact@atelier-mirai.net']

  spec.summary       = 'QueryStream - YAML/JSON data renderer with template expansion'
  spec.description   = 'A generic Ruby library that expands QueryStream notation in text content ' \
                        'by combining YAML/JSON data files with template files.'
  spec.homepage      = 'https://github.com/Atelier-Mirai/query-stream'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 4.0'

  spec.files = Dir.glob('{lib,bin}/**/*') + %w[README.md LICENSE Gemfile query-stream.gemspec]
  spec.bindir        = 'bin'
  spec.executables   = ['query-stream']
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'logger'
  spec.add_dependency 'samovar', '~> 2.1'

  # Development dependencies
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake', '~> 13.2'
  spec.add_development_dependency 'minitest', '~> 5.22'
  spec.metadata['rubygems_mfa_required'] = 'false'
end
