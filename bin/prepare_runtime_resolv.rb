# frozen_string_literal: true

require 'bundler/setup'
require 'fileutils'
require 'rbconfig'

specification = Gem.loaded_specs['resolv']
abort 'The application bundle must contain resolv.' unless specification

runtime_root = Gem.default_dir
library_root = RbConfig::CONFIG.fetch('rubylibdir')
extension_root = RbConfig::CONFIG.fetch('archdir')
unless [runtime_root, library_root, extension_root].all? { |path| path.start_with?('/usr/local/lib/ruby/') }
  abort 'This preparation is only supported in the official Ruby container.'
end

# Use the locked resolver for Ruby commands that do not start Bundler.
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

# Remove the old implementation as well as its default specification.
Dir.glob(File.join(Gem.default_specifications_dir, 'resolv-*.gemspec')).each do |path|
  default_specification = Gem::Specification.load(path)
  abort 'Unexpected default resolver specification.' unless default_specification&.name == 'resolv'
  default_gem = File.join(runtime_root, 'gems', default_specification.full_name)
  FileUtils.remove_entry_secure(default_gem) if File.directory?(default_gem) && default_gem != runtime_gem
  FileUtils.rm_f(path)
end

default_library = File.join(library_root, 'resolv')
FileUtils.remove_entry_secure(default_library) if File.directory?(default_library)
FileUtils.rm_f(File.join(library_root, 'resolv.rb'))

verification = <<~RUBY
  require 'resolv'
  abort 'Unexpected runtime resolver version.' unless Resolv::VERSION == #{specification.version.to_s.inspect}
  message = Resolv::DNS::Message.new(123)
  message.add_question('example.test', Resolv::DNS::Resource::IN::A)
  abort 'DNS round trip failed.' unless Resolv::DNS::Message.decode(message.encode).id == 123
RUBY
environment = {'RUBYOPT' => nil, 'GEM_HOME' => nil, 'GEM_PATH' => nil,
               'BUNDLE_GEMFILE' => nil, 'BUNDLE_BIN_PATH' => nil}
abort 'Runtime resolver verification failed.' unless system(environment, RbConfig.ruby, '-e', verification)
puts "Runtime resolver uses the application lockfile version #{specification.version}."
