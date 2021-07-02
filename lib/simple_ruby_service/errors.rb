# frozen_string_literal: true

module SimpleRubyservice
  # Extnding ActiveModel::Errors with additional features:
  # 1. Adds ability to return array of errors
  # 2. Adds ability to decorate errors
  # 2. Adds ability to internationalize errors
  class Errors
    delegate_missing_to :@active_model_errors

    attr_reader :original_errors
    attr_reader :active_model_errors

    def initialize(base)
      @base = base
      @original_errors = []
      @active_model_errors = ActiveModel::Errors.new(base)
    end

    def add(attribute, message = :invalid, options = {})
      # store original arguments, since Rails 5 errors don't store `message`, only it's translation.
      # can be avoided with Rails 6.
      original_errors << OpenStruct.new(
        attribute: attribute,
        message: message,
        options: options
      )
      active_model_errors.add(attribute, message, options)
    end

    def api_errors(&decorate_error)
      original_errors.map do |e|
        type = e.message.is_a?(Symbol) ? e.message : nil
        message = type ? active_model_errors.generate_message(e.attribute, e.message, e.options) : e.message
        full_message = full_message(e.attribute, message)

        error = {
          full_message: full_message,
          message: message,
          type: type,
          attribute: e.attribute,
          options: e.options
        }

        error = decorate_error.call(error) if decorate_error
        error
      end
    end

    # Support ovveriding format for each error (not avaliable in rails 5)
    def full_message(attribute, message)
      return message if attribute == :base

      attr_name = attribute.to_s.tr('.', '_').humanize
      attr_name = @base.class.human_attribute_name(attribute, default: attr_name)

      defaults = i18n_keys(attribute, '_format')
      defaults << :"errors.format"
      defaults << '%{attribute} %{message}'

      I18n.t(defaults.shift,
             default: defaults,
             attribute: attr_name,
             message: message)
    end

    def i18n_keys(attribute, key)
      if @base.class.respond_to?(:i18n_scope)
        i18n_scope = @base.class.i18n_scope.to_s
        @base.class.lookup_ancestors.flat_map do |klass|
          [:"#{i18n_scope}.errors.models.#{klass.model_name.i18n_key}.attributes.#{attribute}.#{key}"]
        end
      else
        []
      end
    end

    def clear
      original_errors.clear
      active_model_errors.clear
    end
  end
end
