Modelist
=====

CLI and API to test and analyze ActiveRecord models.

### Setup

In your Rails 3+ project, add this to your Gemfile:

    gem 'modelist'

Then run:

    bundle install

### API Configuration

Not needed for CLI. Just used if you are using as an API:

    Modelist::quiet = true

### Usage

#### CLI

Modelist has a command-line interface with options to test for required circular dependencies, models that the specified models require due to nullable or validation constraints, or to test attributes and associations.

##### Circular

Check ActiveRecord circular dependencies. Find circular chains of dependencies where foreign keys that are not primary keys of the models are all not nullable in the schema or not nullable because of ActiveRecord presence validation with:

    bundle exec modelist circular

or:

    bundle exec modelist circular my_model_1 my_model_2 --output-file=/path/to/errors.log

Example output:

    The following non-nullable foreign keys used in ActiveRecord model associations are involved in circular dependencies:

    beers.waitress_id -> waitresses.bartender_id -> bartenders.beer_id -> beers.waitress_id

    beers.waitress_id -> waitresses.bartender_id -> bartenders.order_id -> order.beer_id -> beers.waitress_id


    Distinct foreign keys involved in a circular dependency:

    beers.waitress_id
    order.beer_id
    bartenders.beer_id
    bartenders.order_id
    waitresses.bartender_id


    Foreign keys by number of circular dependency chains involved with:

    2 (out of 2): beers.waitress_id -> waitresses
    2 (out of 2): waitresses.bartender_id -> bartenders
    1 (out of 2): order.beer_id -> beers
    1 (out of 2): bartenders.order_id -> order
    1 (out of 2): bartenders.beer_id -> beers

Specify --output-file to provide an pathname of an errors file.

##### Required

Find the models that the specified models have non-nullable or presence validations for directly and indirectly. You can use this to determine which models are really required with:

    bundle exec modelist required my_model_1 my_model_2

Example output:

    Required models:

    Bartender
    Beer
    Order
    Waitress
    
##### Test

Test ActiveRecord models, their attributes, and associations with:

    bundle exec modelist test

or:

    bundle exec modelist test my_model_1 my_model_2 --output-file=/path/to/errors.log

Example output:

    (...example data from models and attributes...)
    ---


    FAILED: MyModel

    ---
    MyModel.last.some_associations: PG::Error: ERROR:  operator does not exist: character varying = integer
    LINE 1: ...oobars"  WHERE "foobars"."my_model_id" = 7
                                        ^
    (...continued and backtrace...)
    ---
    (...more errors...)


    Passed (258):
    ---
    AnotherGoodModel
    GoodModel
    ...

    Warnings (123):
    ---
    Foo.first was nil. Assuming there is no data in the associated table, but please verify.
    Bar's belongs_to :waitresses may need to be singularized to waitress?
    ...

    Failed (85):
    ---
    Bar
    Foobar
    MyModel


Specify --output-file to provide an pathname of an errors file.

### API

    Modelist::Analyst.find_required_models(:model1, :model2)
    Modelist::CircularRefChecker.test_models(:model1, :model2, output_file: true)
    Modelist::Tester.test_models(:model1, :model2, output_file: true)

### License

Copyright (c) 2012 Gary S. Weaver, released under the [MIT license][lic].

[lic]: http://github.com/garysweaver/modelist/blob/master/LICENSE
