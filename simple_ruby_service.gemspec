# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "simple_ruby_service/version"

Gem::Specification.new do |spec|
  spec.name          = "simple_ruby_service"
  spec.version       = SimpleRubyService::VERSION
  spec.authors       = ["Jay Crouch"]
  spec.email         = ["i.jaycrouch@gmail.com"]

  spec.summary       = 'Simple Ruby Service is a lightweight framework for Ruby that makes it easy to create Services and Service Objects (SOs).'
  spec.description   = 'Simple Ruby Service is a lightweight framework for Ruby that makes it easy to create Services and Service Objects (SOs). The framework provides a simple DSL that: adds ActiveModel validations and error handling; encourages a succinct, idiomatic coding style; and allows Service Objects to ducktype as Procs.'
  spec.homepage      = 'https://github.com/amazing-jay/simple_ruby_service'
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = 'https://github.com/amazing-jay/simple_ruby_service'
    spec.metadata["changelog_uri"] = "https://github.com/amazing-jay/simple_ruby_service/blob/master/CHANGELOG.md"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|bin|config)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'activemodel'
  spec.add_dependency 'activesupport'

  # spec.add_development_dependency 'actionpack'
  spec.add_development_dependency "awesome_print", "~> 1.9.2"
  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "database_cleaner", "~> 2.0.1"
  spec.add_development_dependency "dotenv", "~> 2.5"
  spec.add_development_dependency "factory_bot", "~> 6.2.0"
  spec.add_development_dependency "faker", "~> 2.18"
  spec.add_development_dependency "listen", "~> 3.5.1"
  spec.add_development_dependency "pry-byebug", "~> 3.9"

  # spec.add_development_dependency "rails", "~> 6.1.3.2"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-rails", "~> 5.0.1"
  spec.add_development_dependency "rubocop", "~> 0.60"
  spec.add_development_dependency "rubocop-performance", "~> 1.5"
  spec.add_development_dependency "rubocop-rspec", "~> 1.37"
  spec.add_development_dependency "codecov", "~> 0.5.2"
  spec.add_development_dependency "simplecov", "~> 0.16"
  spec.add_development_dependency "sqlite3", "~> 1.4.2"
  spec.add_development_dependency "webmock", "~> 3.13"

  if ENV['TEST_RAILS_VERSION'].blank?
    spec.add_development_dependency 'rails', '~> 6.1.3.2'
  else
    spec.add_development_dependency 'rails', ENV['TEST_RAILS_VERSION'].to_s
  end
end
