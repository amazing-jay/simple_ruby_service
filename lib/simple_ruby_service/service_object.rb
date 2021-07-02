# frozen_string_literal: true

# See /README.md
module SimpleRubyService
  module ServiceObject
    extend ActiveSupport::Concern
    include Service

    included do
      class << self
        undef_method :service_methods
      end
    end

    # Class level DSL for convenience.
    class_methods do
      def call(attributes = {}, &callback)
        new(attributes).call(&callback)
      end

      def call!(attributes = {}, &callback)
        new(attributes).call!(&callback)
      end
    end

    # Returns self (for chainability).
    # Memoizes to `value` the result of the blk provided.
    # Evaluates validity prior to executing the block provided.
    def call(&callback)
      self.value = perform(&callback) if valid?

      self
    end

    # Returns #value (i.e. the result of block provided).
    # Raises Invalid if validation reports any errors.
    # Raises Failure if the blk provided reports any errors.
    def call!(&callback)
      call(&callback)
      raise Invalid.new self, errors.full_messages unless valid?
      raise Failure.new self, errors.full_messages unless success?

      value
    end

    protected
    # Abstract method
    def perform
      raise NoMethodError, "#perform must be implemented."
    end
  end
end
