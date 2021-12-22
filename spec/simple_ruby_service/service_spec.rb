# frozen_string_literal: true

require 'action_controller'

RSpec.describe SimpleRubyService::Service do
  let(:attrs) { { foo: :bar } }
  let(:test_instance) { test_class.new(**attrs) }
  let(:test_class) do
    Class.new do
      include SimpleRubyService::Service
      attr_accessor :performed

      attribute :foo
      validates_presence_of :foo

      def self.model_name
        ActiveModel::Name.new(self, nil, 'TestClass')
      end

      service_methods do
        def call(trigger_failure = false)
          @performed = true
          errors.add(:trigger_failure, 'something bad happened') and return if trigger_failure

          self.value = 'hello world'
        end
      end
    end
  end

  describe '.new' do
    it 'accepts keyword arguments' do
      expect(test_class.new(foo: :bar)).to be_valid
      test_instance.call.errors.full_messages
    end

    it 'accepts a hash' do
      expect(test_class.new({ foo: :bar })).to be_valid
    end

    it 'accepts strong params' do
      params = ActionController::Parameters.new({ foo: :bar }).permit(:foo)
      expect(test_class.new(params)).to be_valid
    end
  end

  describe '#attributes' do
    subject { test_instance.attributes }

    it 'does not include performed' do
      expect(subject).to eq(attrs)
    end
  end

  describe '.service_methods' do
    describe '#call' do
      subject { test_instance.call trigger_failure }

      let(:trigger_failure) { false }

      context 'when perform passes' do
        context 'with invalid attrs' do
          let(:attrs) { { unknown: :bar } }

          it 'raises an error with unknown arg' do
            expect { subject }.to raise_error(ActiveModel::UnknownAttributeError)
          end
        end

        context 'with no attrs' do
          let(:attrs) { {} }

          it 'is invalid' do
            expect(subject).not_to be_valid
            expect(subject).to be_invalid
          end

          it 'fails' do
            expect(subject).not_to be_success
            expect(subject).to be_failure
            expect(subject.errors.full_messages).to eq(["Foo can't be blank"])
          end

          it 'does not execute' do
            expect(subject.performed).to eq(nil)
          end

          it 'does not set value' do
            expect(subject.value).to eq(nil)
          end
        end

        context 'with valid attrs' do
          it 'is valid' do
            expect(subject).to be_valid
            expect(subject).not_to be_invalid
          end

          it 'succeeds' do
            expect(subject).to be_success
            expect(subject).not_to be_failure
          end

          it 'sets value' do
            expect(subject.value).to eq('hello world')
          end

          context 'with error' do
            let(:trigger_failure) { true }

            it 'is valid' do
              expect(subject).to be_valid
              expect(subject).not_to be_invalid
            end

            it 'fails' do
              subject
              expect(subject).not_to be_success
              expect(subject).to be_failure
              expect(subject.errors.full_messages).to eq(['Trigger failure something bad happened'])
            end

            it 'executes' do
              expect(subject.performed).to eq(true)
            end

            it 'does not set value' do
              expect(subject.value).to eq(nil)
            end
          end
        end
      end
    end

    describe '#call!' do
      subject { test_instance.call! trigger_failure }

      let(:trigger_failure) { false }

      context 'when perform passes' do
        context 'with invalid attrs' do
          let(:attrs) { { unknown: :bar } }

          it 'raises an error with unknown arg' do
            expect { subject }.to raise_error(ActiveModel::UnknownAttributeError)
          end
        end

        context 'with no attrs' do
          let(:attrs) { {} }

          it 'raises an error' do
            expect { subject }.to raise_error(SimpleRubyService::Invalid)
          end

          context 'when rescued' do
            subject do
              test_instance.call! trigger_failure
            rescue SimpleRubyService::Invalid
              test_instance
            end

            it 'is invalid' do
              expect(subject).not_to be_valid
              expect(subject).to be_invalid
            end

            it 'fails' do
              expect(subject).not_to be_success
              expect(subject).to be_failure
              expect(subject.errors.full_messages).to eq(["Foo can't be blank"])
            end

            it 'does not execute' do
              expect(subject.performed).to eq(nil)
            end

            it 'does not set value' do
              expect(subject.value).to eq(nil)
            end
          end
        end

        context 'with valid attrs' do
          it 'returns value' do
            expect(subject).to eq('hello world')
          end

          it 'is valid' do
            subject
            expect(test_instance).to be_valid
            expect(test_instance).not_to be_invalid
          end

          it 'succeeds' do
            subject
            expect(test_instance).to be_success
            expect(test_instance).not_to be_failure
          end

          it 'sets value' do
            subject
            expect(test_instance.value).to eq('hello world')
          end

          context 'with error' do
            let(:trigger_failure) { true }

            it 'raises an error' do
              expect { subject }.to raise_error(SimpleRubyService::Failure)
            end

            context 'when rescued' do
              subject do
                test_instance.call! trigger_failure
              rescue SimpleRubyService::Failure
                test_instance
              end

              it 'is valid' do
                expect(subject).to be_valid
                expect(subject).not_to be_invalid
              end

              it 'fails' do
                expect(subject).not_to be_success
                expect(subject).to be_failure
                expect(subject.errors.full_messages).to eq(['Trigger failure something bad happened'])
              end

              it 'executes' do
                expect(subject.performed).to eq(true)
              end

              it 'does not set value' do
                expect(subject.value).to eq(nil)
              end
            end
          end
        end
      end
    end

    context 'set_value_when_service_methods_return' do
      subject { test_instance.call }
      let(:test_instance) { test_class.new }
      let(:test_class) do
        Class.new do
          include SimpleRubyService::Service

          def self.model_name
            ActiveModel::Name.new(self, nil, 'TestClass')
          end

          service_methods do
            def call
              'hello world'
            end
          end
        end
      end

      context 'when class attr is default' do
        context 'and instance attr is default' do
          it 'sets value' do
            expect(subject.value).to eq('hello world')
          end
        end

        context 'and instance attr is false' do
          before { test_instance.set_value_when_service_methods_return = false }
          it 'does not set value' do
            expect(subject.value).to eq(nil)
          end
        end

        context 'and instance attr is true' do
          before { test_instance.set_value_when_service_methods_return = true }
          it 'sets value' do
            expect(subject.value).to eq('hello world')
          end
        end
      end

      context 'when class attr is true' do
        before { test_class.set_value_when_service_methods_return = true }
        context 'and instance attr is default' do
          it 'sets value' do
            expect(subject.value).to eq('hello world')
          end
        end

        context 'and instance attr is false' do
          before { test_instance.set_value_when_service_methods_return = false }
          it 'does not set value' do
            expect(subject.value).to eq(nil)
          end
        end

        context 'and instance attr is true' do
          before { test_instance.set_value_when_service_methods_return = true }
          it 'sets value' do
            expect(subject.value).to eq('hello world')
          end
        end
      end

      context 'when class attr is false' do
        before { test_class.set_value_when_service_methods_return = false }
        context 'and instance attr is default' do
          it 'does not set value' do
            expect(subject.value).to eq(nil)
          end
        end

        context 'and instance attr is false' do
          before { test_instance.set_value_when_service_methods_return = false }
          it 'does not set value' do
            expect(subject.value).to eq(nil)
          end
        end

        context 'and instance attr is true' do
          before { test_instance.set_value_when_service_methods_return = true }
          it 'sets value' do
            expect(subject.value).to eq('hello world')
          end
        end
      end
    end

    context 'lexical scope tests' do
      let(:test_instance) { test_class.new }
      let(:test_class) do
        Class.new do
          include SimpleRubyService::Service

          SANDWICH ||= 'peanut butter'

          def self.model_name
            ActiveModel::Name.new(self, nil, 'TestClass')
          end

          def self.topping
            'jam'
          end

          service_methods do
            def self.chocolate
              'dark is best'
            end

            def bake
              self.value = [SANDWICH, self.class.topping].join(' & ')
            end

            def chocolate
              self.value = self.class.chocolate
            end

            def invoke_helper
              obj = self.class.new
              obj.errors.add :bake
              add_errors_from_object obj
            end

            def overridden
              self.value = 'original implementation'
            end

            def optional(param = 'hello world')
              self.value = param
            end

            def optional_kwargs(param: 'hello world')
              self.value = param
            end
          end

          def perform_overridden
            self.value = 'overridden implementation'
          end
        end
      end

      it 'binds with class scope' do
        expect(test_instance.bake!).to eq('peanut butter & jam')
        expect(test_instance.invoke_helper.errors[:bake]).to eq(['is invalid'])
      end

      it 'does not expose module methods' do
        expect { test_class.chocolate }.to raise_error(NoMethodError, "undefined method `chocolate' for #{test_class}")
      end

      it 'finds constants and module methods' do
        expect { test_instance.chocolate }.to raise_error(NoMethodError, "undefined method `chocolate' for #{test_class}")
      end

      it 'finds overriden methods' do
        expect(test_instance.overridden.value).to eq('overridden implementation')
        expect(test_instance.overridden!).to eq('overridden implementation')
      end

      it 'handles optional arguments correctly' do
        expect(test_instance.optional.value).to eq('hello world')
        expect(test_instance.optional('x').value).to eq('x')
        expect(test_instance.optional_kwargs.value).to eq('hello world')
        expect(test_instance.optional_kwargs(param: 'x').value).to eq('x')
      end
    end
  end
end
