# Simple Ruby Service

[![Build Status](https://travis-ci.com/amazing-jay/simple_ruby_service.svg?branch=master)](https://travis-ci.com/amazing-jay/simple_ruby_service)
[![Test Coverage](https://codecov.io/gh/amazing-jay/simple_ruby_service/graph/badge.svg)](https://codecov.io/gh/amazing-jay/simple_ruby_service)

Simple Ruby Service is a lightweight framework for Ruby that makes it easy to create Services and Service Objects (SOs).

The framework provides a simple DSL that:

1. Adds ActiveModel validations and error handling 
2. Encourages a succinct, idiomatic coding style 
3. Allows Service Objects to ducktype as Procs

## Requirements

* Ruby 1.9.2+

_Simple Ruby Service includes helpers for Rails 3.0+, but does not require Rails._

## Download and installation

Add this line to your application's Gemfile:

```ruby
gem 'simple_ruby_service'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install simple_ruby_service

Source code can be downloaded on GitHub
  [github.com/amazing-jay/simple_ruby_service/tree/master](https://github.com/amazing-jay/simple_ruby_service/tree/master)


### The following examples illustrate how Simple Ruby Service can help you refactor complex business logic

See [Usage](https://github.com/amazing-jay/simple_ruby_service#usage) & [Creating Simple Ruby Services](https://github.com/amazing-jay/simple_ruby_service#creating-simple-ruby-services) for more information.

#### ::Before:: Vanilla Rails with a fat controller (a contrived example)
```ruby
class SomeController < ApplicationController
  def show
    raise unless params[:id].present?
    resource = SomeModel.find(id)
    authorize! resource
    resource.do_something
    value = resource.do_something_related
    render value
  end
end
```

#### ::After:: Refactored using an SO
```ruby
class SomeController < ApplicationController
  def show
    # NOTE: Simple Ruby Service Objects ducktype as Procs and do not need to be instantiated
    render DoSomething.call(params).value
  end
end

class DoSomething
  include SimpleRubyService::ServiceObject
  
  attribute :id
  attr_accessor :resource

  # NOTE: Validations are executed prior to the business logic encapsulated in `perform`
  validate do                                 
    @resource ||= SomeModel.find(id)
    authorize! resource
  end
  
  # NOTE: The return value of `perform` is automatically stored as the SO's `value`
  def perform
    resource.do_something
    resource.do_something_related
  end
end
```

#### ::Alternate Form:: Refactored using a Service
```ruby
class SomeController < ApplicationController
  def show
    # NOTE: Simple Ruby Service methods can be chained together
    render SomeService.new(params)
      .do_something
      .do_something_related
      .value
  end
end

class SomeService
  include SimpleRubyService::Service
  
  attribute :id
  attr_accessor :resource

  # NOTE: Validations are executed prior to the first service method called
  validate do
    @resource ||= SomeModel.find(id)
    authorize! @resource
  end
  
  service_methods do
    def do_something
      resource.do_something_related
    end

    # NOTE: Unlike SOs, `value` must be explicitely set for Service methods
    def do_something_related
      self.value ||= resource.tap &:do_something_related
    end
  end
end
```

## Usage

### Service Objects

Service Object names should begin with a verb and should not include the words `service` or `object`:
- GOOD = `CreateUser`
- BAD = `UserCreator`, `CreateUserServiceObject`, etc.

Also, only one operation should be made public, it should always be named `call`, and it should not accept arguments (except for an optional block).

_See [To bang!, or not to bang](https://github.com/amazing-jay/simple_ruby_service/tree/master#to-bang-or-not-to-bang) to learn about `.call!` vs. `.call`._

#### Short form (_recommended_)

```ruby
result = DoSomething.call!(foo: 'bar')
```

#### Instance form
```ruby
result = DoSomething.new(foo: 'bar').call!
```

#### Rescue form
```ruby
result = begin
  DoSomething.call!(foo: 'bar')
rescue SimpleRubyService::Invalid => e
  # do something with e.target.attributes
rescue SimpleRubyService::Failure
  # do something with e.target.value
end
```

#### Conditional form 

```ruby
result = DoSomething.call(foo: 'bar')
if result.invalid?
  # do something with result.attributes
elsif result.failure?
  # do something with result.value
else
  # do something with result.errors
end
```

#### Block form 
_note: blocks, if present, are envoked prior to failure check._

```ruby
result = DoSomething.call!(foo: 'bar') do |obj|
  obj.errors.clear # clear errors
  'new value'      # set result = 'new value'
end
```

#### Dependency injection form
```ruby
DoSomething.call!(with: DoSomethingFirst.call!)
```

### Services

Unlike Service Objects, Service class names should begin with a noun (and may include the words `service` or `object`):
- GOOD = `UserCreator`
- BAD = `CreateUser`, `UserCreatorService`, etc.

Also, any number of operations may be made public, any of these operations may be named `call`, and any of these operations may accept arguments.

_See [To bang!, or not to bang](https://github.com/amazing-jay/simple_ruby_service/tree/master#to-bang-or-not-to-bang) to learn about `.service_method_name!` vs. `.service_method_name`._


#### Short form

_not available for Services_

#### Instance form
```ruby
result = SomeService.new(foo: 'bar').do_something!
```

#### Chained form 

```ruby
result = SomeService.new(foo: 'bar')
  .do_something
  .do_something_else
  .value
```

#### Rescue form
```ruby
result = begin
  SomeService.new(foo: 'bar').do_something!
rescue SimpleRubyService::Invalid => e
  # do something with e.target.attributes
rescue SimpleRubyService::Failure
  # do something with e.target.value
end
```

#### Conditional form
```ruby
result = SomeService.new(foo: 'bar').do_something
if result.invalid?
  # do something with result.attributes
elsif result.failure?
  # do something with result.value
else
  # do something with result.errors
end
```

#### Block form
_note: blocks, if present, are envoked prior to failure check._

```ruby
result = SomeService.new(foo: 'bar').do_something! do |obj|
  obj.errors.clear # clear errors
  'new value'      # set result = 'new value'
end
```

## Creating Simple Ruby Services

### Service Objects
To implement an Simple Ruby Service Object:

  1. include `SimpleRubyService::ServiceObject`
  2. declare attributes with the `attribute` keyword (class level DSL)
  3. declare validations see [Active Record Validations](https://guides.rubyonrails.org/active_record_validations.html)
  4. implement the special `perform` method (automatically invoked by `call` wrapper method)
  5. add errors to indicate the operation failed

_note: `perform` may optionally accept a block param, but no other args._
 
Example::
```ruby
class DoSomething
  include SimpleRubyService::ServiceObject
  
  attribute :attr1, :attr2             # should include all params required to execute, similar to ActiveRecord
  validates_presence_of :attr1         # validate params

  def perform
    errors.add(:some critical service, message: 'down') and return unless some_critical_service.up?
    yield if block_given?

    'hello world'                      # set `value` to the returned value of the operation
  end
end
```

### Services
To implement an Simple Ruby Service:

  1. include `SimpleRubyService::Service`
  2. declare attributes with the `attribute` keyword (class level DSL)
  3. declare validations see [Active Record Validations](https://guides.rubyonrails.org/active_record_validations.html)
  4. define operations within a `service_methods` block (each method defined will be wrapped)
  5. set (or modify) `self.value` (if your service method creates artifacts
  6. add errors to indicate the operation failed

_note: service methods may accept any arguments, required or otherwise._

Example::

```ruby
class SomeService 
  include SimpleRubyService::Service
  
  attribute :attr1, :attr2               # should include all params required to execute, similar to ActiveRecord
  validates_presence_of :attr1           # validate params

  service_methods do
    def hello
      self.value = 'hello world'         # set value
    end
    
    def oops
      errors.add(:foo, :bar)             # indicate failure
    end

    
    def goodbye(arg1, arg2 = nil, arg3: arg4: nil, &block)
      self.value += '...goodnight sweet world'                # modify value
    end
  end
end
```

## FAQ

### Why should I use Services & SOs?

[Click here](https://www.google.com/search?q=service+object+pattern+rails&rlz=1C5CHFA_enUS893US893&oq=service+object+pattern+rails) to learn more about the Services & SO design pattern.

**TLDR; fat models and fat controllers are bad! Services and Service Objects help you DRY things up.**

### How is a Service different from an SO?

An SO is just a Service that encapsulates a single operation (i.e. **one, and only one, responsibility**).

### When should I choose a Service over an SO, and vice-versa?

Use a `Service` when encapsulating related operations that share dependencies & validations.

i.e.:

* Create a Service with two service methods when operation `A` and operation `B` both act on a `User` (and are related in some way).
* Create two Service Objects when operation `A` and operation `B` are related, but `A` acts on a `User` while `B` acts on a `Company`.

_note: Things get fuzzy when operations share some, but not all, dependencies & validations. Use your best judgement when operation `A` and operation `B` are related but `A` acts on a `User` while `B` acts on both a `User` & a `Company`._

### Atomicity
The framework does not include transaction support by default. You are responsible for wrapping with a transaction if atomicity is desired.

### Control Flow
Rescue exceptions that represent internal control flow and propogate the rest.

For example, if an internal call to User.create! is expected to always succeed, allow `ActiveRecord::RecordInvalid` to propogate to the caller. If, on the otherhand, an internal call to User.create! is anticipated to conditionally fail on a uniqueness constraint, rescue `ActiveRecord::RecordInvalid` and rely on the framework to raise `SimpleRubyService::Failure`.

Example::
```ruby
class DoSomethingDangerous < SimpleRubyService::ObjectBase
  attribute :attr1, :attr2             # should include all params required to execute
  validates_presence_of :attr1         # validate params to call

  def perform
    ActiveRecord::Base.transaction do  # optional
      self.value = # ... do work ...   # save results for the caller
    end
  rescue SomeDependency::Failed
    errors[:base] << e.message         # notify the caller of error
  rescue ActiveRecord::RecordInvalid
    # ... fix things and retry ...
  end
end
```

## Workflows
SOs often need to call other SOs in order to implement various workflows:
```ruby
class PerformSomeWorkflow < SimpleRubyService::ObjectBase
  def perform
    dependency = SimpleRubyService1.call!
    result = SimpleRubyService2.call(dependency)
    raise unless result.success?                 
    SimpleRubyService3(dependency, result.value).call!
  end
end
```

## MISC

### Attributes
The `attribute` and `attributes` keywords behaves similar to [ActiveRecord::Base.attribute](https://api.rubyonrails.org/v6.1.3.1/classes/ActiveRecord/Attributes/ClassMethods.html), but they are not typed or bound to persistant storage.

### To bang!, or not to bang

Use the bang! version of an operation whenever you expect the operation to succeed more often than fail, and you don't need to chain operations together.

Similar in pattern to `ActiveRecord#save!`, the bang version of each operation:
* raises `SimpleRubyService::Invalid` if `valid?` is falsey
* raises `SimpleRubyService::Failure` if the block provided returns a falsey value
* returns `@value`

Whereas, similar in pattern to `ActiveRecord#save`, the regular version of each operation:
* doesn't raise any exceptions
* passes the return value of the block provided to `#success?` 
* returns self << _note: this is unlike `ActiveRecord#save`_

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/amazing-jay/simple_ruby_service. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## DEVELOPMENT ROADMAP

1. Create a helper to dynamically generate default SOs for ActiveRecord models (`create`, `update`, and `destroy`) _(when used in a project that includes [ActiveRecord](https://github.com/rails/rails/tree/main/activerecord))_.
2. Consider isolating validation errors from execution errors (so that invalid? is not always true when failed? is true)

