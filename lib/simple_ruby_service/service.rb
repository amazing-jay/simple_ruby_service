# frozen_string_literal: true

# See /README.md
module SimpleRubyService
  module Service
    extend ActiveSupport::Concern
    include ActiveModel::AttributeAssignment
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks

    included do
      attr_accessor :value

      class_attribute :set_value_when_service_methods_return
      self.set_value_when_service_methods_return = true
    end

    class_methods do
      def attributes
        @attributes ||= []
      end

      # Class level DSL that registers attributes to inform #attributes getter.
      def attribute(*attrs)
        Module.new.tap do |m| # Using anonymous modules so that super can be used to extend accessor methods
          include m

          attrs = attrs.map(&:to_sym)
          (attrs - attributes).each do |attr_name|
            attributes << attr_name.to_sym
            m.attr_accessor attr_name
          end
        end
      end

      # Class level DSL that wraps the methods defined in inherited classes.
      def service_methods(&blk)
        Module.new.tap do |m| # Using anonymous modules so that super can be used to extend service methods
          m.module_eval(&blk)
          include m

          m.instance_methods.each do |service_method|
            m.alias_method "perform_#{service_method}", service_method

            # Returns self (for chainability).
            # Evaluates validity prior to executing the block provided.
            define_method service_method do |*args, **kwargs, &callback|
              result = perform(service_method, *args, **kwargs, &callback) if valid?
              self.value = result if set_value_when_service_methods_return

              self
            end

            # Returns #value (i.e. the result of block provided).
            # Raises Invalid if validation reports any errors.
            # Raises Failure if the blk provided reports any errors.
            define_method "#{service_method}!" do |*args, **kwargs, &callback|
              send(service_method, *args, **kwargs, &callback)
              raise Invalid.new self, errors.full_messages unless valid?
              raise Failure.new self, errors.full_messages unless success?

              value
            end
          end
        end
      end
    end

    # Always returns self (for chainability).
    def reset!
      errors.clear
      @valid = nil
      self.value = nil

      self
    end

    # Returns true unless validations or any actions added errors [even if no action(s) has been executed]
    def success?
      valid? && errors.empty? # valid? ensures validations have run, errors.empty? catchs errors added during execution
    end

    def failure?
      !success?
    end

    # Ensures all validations have run, then returns true if no errors were found, false otherwise.
    # NOTE: Overriding ActiveModel::Validations#valid?, so as to not re-validate (unless reset! is called).
    # SEE: https://www.rubydoc.info/gems/activemodel/ActiveModel/Validations#valid%3F-instance_method
    def valid?(context = nil)
      return @valid unless @valid.nil?

      @valid = super # memoize result to indicate validations have run
    end

    def attributes
      self.class.attributes.each_with_object({}) do |attr_name, h|
        h[attr_name] = send(attr_name)
      end
    end

    # Hook override to enable validation of non-attributes and error messages for random keys
    #   e.g. validates :random, presence: true
    #   e.g. errors.add :random, :message => 'evil is near'
    # SEE: https://www.rubydoc.info/docs/rails/ActiveModel%2FValidations:read_attribute_for_validation
    def read_attribute_for_validation(attribute)
      send(attribute) if respond_to?(attribute)
    end

    protected

    def initialize(attributes = {})
      assign_attributes attributes
    end

    def perform(service_method, *args, **kwargs, &callback)
      if kwargs.empty?
        send("perform_#{service_method}", *args, &callback)
      else
        send("perform_#{service_method}", *args, **kwargs, &callback)
      end
    end

    def add_errors_from_object(obj, key: nil, full_messages: false)
      if full_messages
        key ||= obj.class.name.underscore.to_sym
        obj.errors.full_messages.each do |msg|
          errors.add(key, msg)
        end
      else
        obj.errors.messages.each do |obj_key, msgs|
          msgs.each { |msg| errors.add(key || obj_key, msg) }
        end
      end
    end
  end
end
