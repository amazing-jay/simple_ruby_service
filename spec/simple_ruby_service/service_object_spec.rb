# frozen_string_literal: true

RSpec.describe SimpleRubyService::ServiceObject do
  let(:args) { { foo: :bar } }
  let(:test_class) do
    Class.new do
      include SimpleRubyService::ServiceObject

      attribute :foo
      validates_presence_of :foo

      def self.model_name
        ActiveModel::Name.new(self, nil, 'TestClass')
      end

      protected

      def perform
        return yield self if block_given?

        'hello world'
      end
    end
  end
  let(:error_class) do
    Class.new do
      include SimpleRubyService::ServiceObject

      attribute :foo
      validates_presence_of :foo

      def self.model_name
        ActiveModel::Name.new(self, nil, 'ErrorClass')
      end

      protected

      def perform
        errors.add('random', message: "error")
        block_given? ? yield(self) : 'hello world'
      end
    end
  end

  describe '.service_methods' do
    it do
      expect{test_class.service_methods}.to raise_error(NoMethodError)
    end
  end

  describe '#call' do
    subject { test_class.call(**args) }
    it 'should envoke call on new instance' do
      expect(test_class).to receive(:new).with(**args).and_call_original
      expect_any_instance_of(test_class).to receive(:call).with(no_args).and_call_original
      subject
    end

    context 'with block' do
      let(:block) { proc { 'asdf' } }
      subject { test_class.call(**args, &block) }
      it 'should envoke call on new instance' do
        expect(test_class).to receive(:new).with(**args).and_call_original
        expect_any_instance_of(test_class).to receive(:call).with(no_args) { |&b| expect(b.call).to eq(block.call) }
        subject
      end
    end
  end

  describe '#call!' do
    subject { test_class.call!(**args) }
    it 'should envoke call on new instance' do
      expect(test_class).to receive(:new).with(**args).and_call_original
      expect_any_instance_of(test_class).to receive(:call!).with(no_args).and_call_original
      subject
    end

    context 'with block' do
      let(:block) { proc { 'asdf' } }
      subject { test_class.call!(**args, &block) }
      it 'should envoke call on new instance' do
        expect(test_class).to receive(:new).with(**args).and_call_original
        expect_any_instance_of(test_class).to receive(:call!).with(no_args) { |&b| expect(b.call).to eq(block.call) }
        subject
      end
    end
  end

  describe '.call' do
    subject { test_class.new(**args).call }

    context 'when perform passes' do
      context 'when invalid args passed' do
        let(:args) { { unknown: :bar } }

        it 'should raise an error with unknown arg' do
          expect { subject }.to raise_error(ActiveModel::UnknownAttributeError)
        end
      end

      context 'when no args passed' do
        let(:args) { {} }

        it 'should be invalid' do
          expect(subject.valid?).to be_falsey
          expect(subject.invalid?).to be_truthy
        end

        it 'should fail' do
          expect(subject.success?).to be_falsey
          expect(subject.failure?).to be_truthy
        end

        it 'should not set value' do
          expect(subject.value).to eq(nil)
        end

        context 'with block' do
          subject { test_class.call(**args) { |obj| raise 'in block' } }

          it 'should skip the block' do
            expect{subject}.not_to raise_error
          end
        end
      end

      context 'when valid args passed' do
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

        context 'with block' do
          subject { test_class.call(**args) { |obj| 'changed' } }

          it 'should change value' do
            expect(subject.value).to eq('changed')
            expect(subject.success?).to be_truthy
          end
        end
      end
    end

    context 'when perform fails' do
      let(:test_class) { error_class }

      context 'when invalid args passed' do
        let(:args) { { unknown: :bar } }

        it 'should raise an error with unknown arg' do
          expect { subject }.to raise_error(ActiveModel::UnknownAttributeError)
        end
      end

      context 'when no args passed' do
        let(:args) { {} }

        it 'should be invalid' do
          expect(subject.valid?).to be_falsey
          expect(subject.invalid?).to be_truthy
        end

        it 'should fail' do
          expect(subject.success?).to be_falsey
          expect(subject.failure?).to be_truthy
        end

        it 'should not set value' do
          expect(subject.value).to eq(nil)
        end

        context 'with block' do
          subject { test_class.call(**args) { |obj| raise 'in block' } }

          it 'should skip the block' do
            expect{subject}.not_to raise_error
          end
        end
      end

      context 'when valid args passed' do
        let(:args) { { foo: :bar } }

        it 'should be valid' do
          expect(subject.valid?).to be_truthy
          expect(subject.invalid?).to be_falsey
        end

        it 'should fail' do
          expect(subject.success?).to be_falsey
          expect(subject.failure?).to be_truthy
        end

        it 'should set value' do
          expect(subject.value).to eq('hello world')
        end

        context 'with block' do
          subject { test_class.call(**args) { |obj| obj.reset!; 'changed' } }

          it 'should change value' do
            expect(subject.value).to eq('changed')
            expect(subject.success?).to be_truthy
          end
        end
      end
    end
  end

  describe '.call!' do
    subject { test_class.new(**args).call! }

    context 'when perform passes' do
      context 'when invalid args passed' do
        let(:args) { { unknown: :bar } }

        it 'should raise an error with unknown arg' do
          expect { subject }.to raise_error(ActiveModel::UnknownAttributeError)
        end
      end

      context 'when no args passed' do
        let(:args) { {} }

        it 'should raise an error' do
          expect { subject }.to raise_error(SimpleRubyService::Invalid)
        end

        context 'with pass block' do
          subject { test_class.new(**args).call! { |obj| obj.value = 'changed'; true } }

          it 'should raise an error' do
            expect { subject }.to raise_error(SimpleRubyService::Invalid)
          end
        end

        context 'with fail block' do
          subject { test_class.new(**args).call! { |obj| obj.value = 'changed'; false } }

          it 'should raise an error' do
            expect { subject }.to raise_error(SimpleRubyService::Invalid)
          end
        end
      end

      context 'when valid args passed' do
        it 'should return value' do
          expect(subject).to eq('hello world')
        end

        context 'with block' do
          subject { test_class.new(**args).call! { |obj| obj.reset!; 'changed' } }

          it 'should change value' do
            expect(subject).to eq('changed')
          end
        end
      end
    end

    context 'when perform fails' do
      let(:test_class) { error_class }

      context 'when invalid args passed' do
        let(:args) { { unknown: :bar } }

        it 'should raise an error with unknown arg' do
          expect { subject }.to raise_error(ActiveModel::UnknownAttributeError)
        end
      end

      context 'when no args passed' do
        let(:args) { {} }

        it 'should raise an error' do
          expect { subject }.to raise_error(SimpleRubyService::Invalid)
        end

        context 'with block' do
          subject { test_class.new(**args).call! { |obj| obj.reset!; 'changed' } }

          it 'should change value' do
            expect { subject }.to raise_error(SimpleRubyService::Invalid)
          end
        end
      end

      context 'when valid args passed' do
        let(:args) { { foo: :bar } }

        it 'should raise an error' do
          expect { subject }.to raise_error(SimpleRubyService::Failure)
        end

        context 'with block' do
          subject { test_class.new(**args).call! { |obj| obj.reset!; 'changed' } }

          it 'should change value' do
            expect(subject).to eq('changed')
          end
        end
      end
    end
  end
end
