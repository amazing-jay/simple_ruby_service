# frozen_string_literal: true

# requre the runtime dependencies that aren't automatically loaded by bundler
require 'active_model'

# namespace
module SimpleRubyservice; end

require 'simple_ruby_service/version'
require 'simple_ruby_service/error'
require 'simple_ruby_service/errors'
require 'simple_ruby_service/failure'
require 'simple_ruby_service/invalid'
require 'simple_ruby_service/service'
require 'simple_ruby_service/service_object'
