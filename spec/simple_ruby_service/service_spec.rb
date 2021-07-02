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
    it 'should accept keyword arguments' do
      expect(test_class.new(foo: :bar).valid?).to be_truthy
      test_instance.call.errors.full_messages
    end

    it 'should accept a hash' do
      expect(test_class.new({foo: :bar}).valid?).to be_truthy
    end

    it 'should accept strong params' do
      params = ActionController::Parameters.new({foo: :bar}).permit(:foo)
      expect(test_class.new(params).valid?).to be_truthy
    end
  end

  describe '#attributes' do
    subject { test_instance.attributes }

    it 'should not include performed' do
      expect(subject).to eq(attrs)
    end
  end

  describe '.service_methods' do
    describe '#call' do
      let(:trigger_failure) { false }
      subject { test_instance.call trigger_failure }

      context 'when perform passes' do
        context 'with invalid attrs' do
          let(:attrs) { { unknown: :bar } }

          it 'should raise an error with unknown arg' do
            expect { subject }.to raise_error(ActiveModel::UnknownAttributeError)
          end
        end

        context 'with no attrs' do
          let(:attrs) { {} }

          it 'should be invalid' do
            expect(subject.valid?).to be_falsey
            expect(subject.invalid?).to be_truthy
          end

          it 'should fail' do
            expect(subject.success?).to be_falsey
            expect(subject.failure?).to be_truthy
            expect(subject.errors.full_messages).to eq(["Foo can't be blank"])
          end

          it 'should not execute' do
            expect(subject.performed).to eq(nil)
          end

          it 'should not set value' do
            expect(subject.value).to eq(nil)
          end
        end

        context 'with valid attrs' do
          it 'should be valid' do
            expect(subject.valid?).to be_truthy
            expect(subject.invalid?).to be_falsey
          end

          it 'should succeed' do
            expect(subject.success?).to be_truthy
            expect(subject.failure?).to be_falsey
          end

          it 'should set value' do
            expect(subject.value).to eq('hello world')
          end

          context 'with error' do
            let(:trigger_failure) { true }

            it 'should be valid' do
              expect(subject.valid?).to be_truthy
              expect(subject.invalid?).to be_falsey
            end

            it 'should fail' do
              subject
              expect(subject.success?).to be_falsey
              expect(subject.failure?).to be_truthy
              expect(subject.errors.full_messages).to eq(["Trigger failure something bad happened"])
            end

            it 'should execute' do
              expect(subject.performed).to eq(true)
            end

            it 'should not set value' do
              expect(subject.value).to eq(nil)
            end
          end
        end
      end
    end

    describe '#call!' do
      let(:trigger_failure) { false }
      subject { test_instance.call! trigger_failure }

      context 'when perform passes' do
        context 'with invalid attrs' do
          let(:attrs) { { unknown: :bar } }

          it 'should raise an error with unknown arg' do
            expect { subject }.to raise_error(ActiveModel::UnknownAttributeError)
          end
        end

        context 'with no attrs' do
          let(:attrs) { {} }

          it 'should raise an error' do
            expect { subject }.to raise_error(SimpleRubyService::Invalid)
          end

          context 'when rescued' do
            subject do
              test_instance.call! trigger_failure
            rescue SimpleRubyService::Invalid
              test_instance
            end

            it 'should be invalid' do
              expect(subject.valid?).to be_falsey
              expect(subject.invalid?).to be_truthy
            end

            it 'should fail' do
              expect(subject.success?).to be_falsey
              expect(subject.failure?).to be_truthy
              expect(subject.errors.full_messages).to eq(["Foo can't be blank"])
            end

            it 'should not execute' do
              expect(subject.performed).to eq(nil)
            end

            it 'should not set value' do
              expect(subject.value).to eq(nil)
            end
          end
        end

        context 'with valid attrs' do
          it 'should return value' do
            expect(subject).to eq('hello world')
          end

          it 'should be valid' do
            subject
            expect(test_instance.valid?).to be_truthy
            expect(test_instance.invalid?).to be_falsey
          end

          it 'should succeed' do
            subject
            expect(test_instance.success?).to be_truthy
            expect(test_instance.failure?).to be_falsey
          end

          it 'should set value' do
            subject
            expect(test_instance.value).to eq('hello world')
          end

          context 'with error' do
            let(:trigger_failure) { true }

            it 'should raise an error' do
              expect { subject }.to raise_error(SimpleRubyService::Failure)
            end

            context 'when rescued' do
              subject do
                test_instance.call! trigger_failure
              rescue SimpleRubyService::Failure
                test_instance
              end

              it 'should be valid' do
                expect(subject.valid?).to be_truthy
                expect(subject.invalid?).to be_falsey
              end

              it 'should fail' do
                expect(subject.success?).to be_falsey
                expect(subject.failure?).to be_truthy
                expect(subject.errors.full_messages).to eq(["Trigger failure something bad happened"])
              end

              it 'should execute' do
                expect(subject.performed).to eq(true)
              end

              it 'should not set value' do
                expect(subject.value).to eq(nil)
              end
            end
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


      it 'should bind with class scope' do
        expect(test_instance.bake!).to eq('peanut butter & jam')
        expect(test_instance.invoke_helper.errors[:bake]).to eq(['is invalid'])
      end

      it 'should not expose module methods' do
        expect{test_class.chocolate}.to raise_error(NoMethodError, "undefined method `chocolate' for #{test_class}")
      end

      it 'should find constants and module methods' do
        expect{test_instance.chocolate}.to raise_error(NoMethodError, "undefined method `chocolate' for #{test_class}")
      end

      it 'should find overriden methods' do
        expect(test_instance.overridden.value).to eq('overridden implementation')
        expect(test_instance.overridden!).to eq('overridden implementation')
      end

      it 'should handle optional arguments correctly' do
        expect(test_instance.optional.value).to eq('hello world')
        expect(test_instance.optional('x').value).to eq('x')
        expect(test_instance.optional_kwargs().value).to eq('hello world')
        expect(test_instance.optional_kwargs(param: 'x').value).to eq('x')
      end
    end
  end
end
