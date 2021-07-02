# Simple Ruby Service

[![Build Status](https://travis-ci.com/amazing-jay/simple_ruby_service.svg?branch=master)](https://travis-ci.com/amazing-jay/simple_ruby_service)
[![Test Coverage](https://codecov.io/gh/amazing-jay/simple_ruby_service/graph/badge.svg)](https://codecov.io/gh/amazing-jay/simple_ruby_service)

Simple Ruby Service is a lightweight framework for creating Services and Service Objects (SOs) in Ruby.

The framework makes Services and SOs look and feel like ActiveModels, complete with:

1. Validations and robust error handling
2. Workflows and method chaining
3. Consistent interfaces

Additionally, Simple Ruby Service Objects can stand in for Procs, wherever Procs are expected (via ducktyping).

#### What problem does Simple Ruby Service solve?

Currently, most ruby developers roll their own services from scratch. As a result, most services are hastely built (in isolation), and this leads to inconsistant interfaces that are difficult to read. Also, error handling tends to vary wildly within an application, and support code tends to be implemented over and over again.

Simple Ruby Service addresses these problems and encourages succinct, idiomatic coding styles.

#### Should I be using Services & SOs in Ruby / Rails?

[LMGTFY](https://www.google.com/search?q=service+object+pattern+rails&rlz=1C5CHFA_enUS893US893&oq=service+object+pattern+rails) to learn more about Services & SOs.

**TLDR** - Fat models and fat controllers are bad! Services and Service Objects help you DRY things up.

#### How is a Service different from an SO?

An SO is just a Service that encapsulates a single operation (i.e. **one, and only one, responsibility**).

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


## Quick Start

See [Usage](https://github.com/amazing-jay/simple_ruby_service#usage) & [Creating Simple Ruby Services](https://github.com/amazing-jay/simple_ruby_service#creating-simple-ruby-services) for more information.

### How to refactor complex business logic with Simple Ruby Service

#### ::Before:: Vanilla Rails with a fat controller (a contrived example)
```ruby
# in app/controllers/some_controller.rb
class SomeController < ApplicationController
  def show
    raise unless params[:id].present?
    resource = SomeModel.find(id)
    authorize! resource
    resource.do_something
    value = resource.do_something_related
    raise unless resource.errors
    render value
  end
end
```

#### ::After:: Refactored using an Simple Ruby Service Object
```ruby
# in app/controllers/some_controller.rb
class SomeController < ApplicationController
  def show
    # NOTE: That's right... just one, readable line of code
    render DoSomething.call!(params)
  end
end
```
 
#### ::Alternate After:: Refactored using a Simple Ruby Service
```ruby
# in app/controllers/some_controller.rb
class SomeController < ApplicationController
  def show
    # NOTE: Simple Ruby Service methods can be chained together
    render SomeService.new(params)
      .do_something
      .do_something_related
      .value
  end
end
```

### Taking a peek under the hood

`DoSomething.call!(params)` is deliberately designed to look and feel like `ActiveRecord::Base#save!`.

The following (simplified) implementation illustrates what happens under the hood:

```ruby
module SimpleRubyService::Object
  def self.call!(params)
    instance = new(params)
    raise Invalid unless instance.valid?
    self.value = instance.call
    raise Invalid unless instance.failed?
    value
  end
end
```

### Anatomy of a Simple Ruby Service Object
```ruby
# in app/service_objects/do_something.rb
class DoSomething
  include SimpleRubyService::ServiceObject
  
  # `attribute` behaves similar to ActiveRecord::Base#attribute, but is not typed, or bound to persistant storage
  attribute :id
  attr_accessor :resource

  # Validations are executed prior to the business logic encapsulated in `perform`
  validate do                                 
    @resource ||= SomeModel.find(id)
    authorize! resource
  end
  
  # The result of `perform` is automatically stored as the SO's `value`
  def perform
    resource.do_something    
    result = resource.do_something_related  
    
    # Adding any kind of error indicates failure
    add_errors_from_object resource    
    result
  end
end
```

### Anatomy of a Simple Ruby Service
```ruby
# in app/services/do_something.rb
class SomeService
  include SimpleRubyService::Service
  
  attribute :id
  attr_accessor :resource

  # Similar to SOs, validations are executed prior to the first service method called
  validate do
    @resource ||= SomeModel.find(id)
    authorize! @resource
  end
  
  # Unlike SOs, Services can define an arbitrary number of service methods with arbitrary names
  service_methods do
    def do_something
      resource.do_something      
    end

    # Unlike SOs, `value` must be explicitely set for Service methods
    def do_something_related
      self.value ||= resource.tap &:do_something_related
      add_errors_from_object resource
    end
  end
end
```

## A special note about Simple Ruby Service Objects, Procs, and Ducktyping

Simple Ruby Service Objects respond to (`#call`) so they can stand in for Procs, i.e.:
```ruby
# in app/models/some_model.rb
class SomeModel < ApplicationRecord
  validates :some_attribute, if: SomeServiceObject
  [...]
```
_See [To bang!, or not to bang](https://github.com/amazing-jay/simple_ruby_service/tree/master#to-bang-or-not-to-bang) to learn about `.call!` vs. `.call`._

## Usage

### Service Objects

Service Object names should begin with a verb and should not include the words `service` or `object`:
- GOOD = `CreateUser`
- BAD = `UserCreator`, `CreateUserServiceObject`, etc.

Also, only one operation should be made public, it should always be named `call`, and it should not accept arguments (except for an optional block).

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
To implement a Simple Ruby Service Object:

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
To implement a Simple Ruby Service:

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

### Workflows
Simple Ruby Services are inherently a good fit for workflows because they support chaining, i.e.:

```ruby
SomeService.new(params)
  .do_something
  .do_something_related
  .value
```

But SOs can also implement various workflows with dependency injection:

```ruby
class PerformSomeWorkflow < SimpleRubyService::ServiceObject
  def perform
    dependency = SimpleRubyService1.call!
    result = SimpleRubyService2.call(dependency)
    raise unless result.success?                 
    SimpleRubyService3(dependency, result.value).call!
  end
end
```

## MISC

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

### Service or SO?

Use a `Service` when encapsulating related operations that share dependencies & validations.

i.e.:

* Create a Service with two service methods when operation `A` and operation `B` both act on a `User` (and are related in some way).
* Create two Service Objects when operation `A` and operation `B` are related, but `A` acts on a `User` while `B` acts on a `Company`.

_note: Things get fuzzy when operations share some, but not all, dependencies & validations. Use your best judgement when operation `A` and operation `B` are related but `A` acts on a `User` while `B` acts on both a `User` & a `Company`._

### Control Flow
Rescue exceptions that represent internal control flow and propogate the rest.

For example, if an internal call to User.create! is expected to always succeed, allow `ActiveRecord::RecordInvalid` to propogate to the caller. If, on the otherhand, an internal call to User.create! is anticipated to conditionally fail on a uniqueness constraint, rescue `ActiveRecord::RecordInvalid` and rely on the framework to raise `SimpleRubyService::Failure`.

Example::
```ruby
class DoSomethingDangerous < SimpleRubyService::ServiceObject
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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/amazing-jay/simple_ruby_service. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## DEVELOPMENT ROADMAP

1. Create a class level DSL to stop before each Service method unless errors.empty?
2. Create a helper to dynamically generate default SOs for ActiveRecord models (`create`, `update`, and `destroy`) _(when used in a project that includes [ActiveRecord](https://github.com/rails/rails/tree/main/activerecord))_.
3. Consider isolating validation errors from execution errors (so that invalid? is not always true when failed? is true)

