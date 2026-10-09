# frozen_string_literal: true

require 'bundler/setup'
require 'fileutils'
require 'rbconfig'

specification = Gem.loaded_specs['json']
abort 'The application bundle must contain json.' unless specification

runtime_root = Gem.default_dir
library_root = RbConfig::CONFIG.fetch('rubylibdir')
extension_root = RbConfig::CONFIG.fetch('archdir')
unless [runtime_root, library_root, extension_root].all? { |path| path.start_with?('/usr/local/lib/ruby/') }
  abort 'This preparation is only supported in the official Ruby container.'
end

# Use the compiled, locked gem for Ruby commands that do not start Bundler.
runtime_gem = File.join(runtime_root, 'gems', specification.full_name)
FileUtils.mkdir_p(runtime_gem)
FileUtils.cp_r("#{specification.full_gem_path}/.", runtime_gem)
runtime_specification = File.join(runtime_root, 'specifications', "#{specification.full_name}.gemspec")
File.write(runtime_specification, specification.to_ruby_for_cache)

if File.directory?(specification.extension_dir)
  runtime_extensions = File.join(runtime_root, 'extensions', Gem::Platform.local.to_s,
                                 Gem.extension_api_version, specification.full_name)
  FileUtils.mkdir_p(runtime_extensions)
  FileUtils.cp_r("#{specification.extension_dir}/.", runtime_extensions)
end

# Remove the old implementation as well as its specification, not just its scanner metadata.
default_specifications = Dir.glob(File.join(Gem.default_specifications_dir, 'json-*.gemspec'))
default_specifications.each do |path|
  default_specification = Gem::Specification.load(path)
  abort 'Unexpected default JSON specification.' unless default_specification&.name == 'json'
  default_gem = File.join(runtime_root, 'gems', default_specification.full_name)
  FileUtils.remove_entry_secure(default_gem) if File.directory?(default_gem) && default_gem != runtime_gem
  FileUtils.rm_f(path)
end

[File.join(library_root, 'json'), File.join(extension_root, 'json')].each do |path|
  FileUtils.remove_entry_secure(path) if File.directory?(path)
end
FileUtils.rm_f(File.join(library_root, 'json.rb'))

verification = <<~RUBY
  require 'json'
  abort 'Unexpected runtime JSON version.' unless JSON::VERSION == #{specification.version.to_s.inspect}
  abort 'Unexpected JSON round trip.' unless JSON.parse(JSON.generate({'reader' => [0, 50, 100]})) == {'reader' => [0, 50, 100]}
RUBY
environment = {'RUBYOPT' => nil, 'GEM_HOME' => nil, 'GEM_PATH' => nil,
               'BUNDLE_GEMFILE' => nil, 'BUNDLE_BIN_PATH' => nil}
abort 'Runtime JSON verification failed.' unless system(environment, RbConfig.ruby, '-e', verification)
puts "Runtime JSON uses the application lockfile version #{specification.version}."
