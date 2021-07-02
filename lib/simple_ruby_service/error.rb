# frozen_string_literal: true

module SimpleRubyservice
  # simple exception class with target and message
  class Error < StandardError
    attr_accessor :target

    def initialize(target, msg)
      @target = target
      super msg
    end
  end
end
