# frozen_string_literal: true

# ================================================================
# Test helper: robustness/robustness_helper.rb
# ================================================================
# 堅牢性テストは「壊れた入力を置いたプロジェクト」を都度組み立てる。
# リポジトリのフィクスチャを汚さないよう、毎回 Dir.mktmpdir の中で完結させる。
# ================================================================

require 'tmpdir'
require 'fileutils'

module RobustnessHelper
  # data/ と templates/ を持つ空プロジェクトを一時ディレクトリに作り、その中で実行する
  def in_project
    Dir.mktmpdir('qs-robustness-') do |dir|
      Dir.chdir(dir) do
        FileUtils.mkdir_p('data')
        FileUtils.mkdir_p('templates')
        yield
      end
    end
  end

  def write_data(name, content) = File.write(File.join('data', name), content)

  def write_template(name, content) = File.write(File.join('templates', name), content)

  # in_project の中で使う render。ディレクトリ指定を毎回書かずに済ませる
  def render(content, **)
    QueryStream.render("#{content}\n", data_dir: 'data', templates_dir: 'templates', **)
  end

  # 権限を落とせない環境（root など）では検証にならないので skip する
  def skip_unless_permission_enforced(path)
    File.chmod(0o000, path)
    skip('root 実行では権限が無視されるため検証できません') if File.readable?(path)
  end
end
