# /api/App Components/Batman.Model

For a general explanation of `Batman.Model` and how it works, see [the guide](/docs/models.html).

_Note_: This documentation uses the term _model_ to refer to the class `Model`
or a `Model` subclass, and the term _record_ to refer to one instance of a
model.

## Batman.Query

To allow for readable and chainable queries Batman introduces `Batman.Query`.

    test 'Batman.Query chains methods', ->
      class Post extends Batman.Model
        @resourceName: 'post'
        @persist TestStorageAdapter

      posts = Post.where(archived: true).limit(10).offset(20)
      ok posts instanceof Batman.Query

    asyncTest 'Batman.Query::load retrieves matching records from the storage adapter', ->
      class Post extends Batman.Model
        @resourceName: 'post'
        @encode 'archived'
        @persist TestStorageAdapter,
          storage:
            'posts1': {id: 1, archived: true}
            'posts2': {id: 2, archived: false}
            'posts3': {id: 3, archived: true}

      records = false
      posts = Post.where(archived: true)
      posts.load (err, result) ->
        throw err if err
        records = result

      delay ->
        equal records.length, 2
        equal records[0].get('id'), 1
        equal records[1].get('id'), 3

The available methods are:

- `where`: Retrieves records with given options.
- `limit`: Retrieves records with a given limit.
- `offset`: Retrieves records from a given offset.
- `order`: Retrieves records in a specific order.
- `distinct`: Retrieves distinct records.
- `action`: Searches against a specific action other than index.
- `only`: Only uses query methods in arguments
- `except`: Uses all query methods specified other than arguments

All these methods are passed as options to the configured `StorageAdapter`.

## @.primaryKey[= "id"] : String

Defines the `Model`'s primary key. This attribute will be used for determining:

- record identity (ie, records with the same `primaryKey` are assumed to be the same record)
- whether a record [`isNew`](/docs/api/batman.model.html#prototype_function_isnew)
- whether records are related (see [`Batman.Model` Associations](/docs/api/batman.model_associations.html))
- URL parameters via [`toParam`](/docs/api/batman.model.html#prototype_function_toparam)

Change the option using `set`, like so:

    test 'primary key can be set using @set', ->
      class Shop extends Batman.Model
        @set 'primaryKey', 'shop_id'
      equal Shop.get('primaryKey'), 'shop_id'

_Note:_ `primaryKey` will be coerced to an integer if possible. You can disable this by setting `coerceIntegerPrimaryKey: false` in your model definition.

## @.resourceName[= null] : String

`resourceName` is a minification-safe identifier for the `Model`. It is usually an underscore-cased version of the `Model`'s class name (for example, `App.BlogPost => "blog_post"`) . It is used by:

- Model assocations (for providing default `primaryKey`s and `foreignKey`s and for `urlNestsUnder`)
- Storage adapters (unless overriden by `storageKey`)
- `data-route` bindings (eg, `routes.items[item]`)

## @.storageKey[= null] : String

`storageKey` is used as a namespace by the model's storage adapter. `Batman.LocalStorage` and `Batman.SessionStorage` use it as a JSON namespace and `Batman.RestStorage` uses it as a URL segment. If `storageKey` isn't set, `resourceName` may be used.

## @persist(mechanism : StorageAdapter) : StorageAdapter

`@persist` is how a `Model` subclass is told to persist itself by means of a `StorageAdapter`. `@persist` accepts either a `StorageAdapter` class or instance and will return either the instantiated class or the instance passed to it for further modification.

    test 'models can be told to persist via a storage adapter', ->
      class Shop extends Batman.Model
        @resourceName: 'shop'
        @persist TestStorageAdapter

      record = new Shop
      ok record.hasStorage()

    test '@persist returns the instantiated storage adapter', ->
      adapter = false
      class Shop extends Batman.Model
        @resourceName: 'shop'
        adapter = @persist TestStorageAdapter

      ok adapter instanceof Batman.StorageAdapter

    test '@persist accepts already instantiated storage adapters', ->
      adapter = new Batman.StorageAdapter
      adapter.someHandyConfigurationOption = true
      class Shop extends Batman.Model
        @resourceName: 'shop'
        @persist adapter

      record = new Shop
      ok record.hasStorage()

## @encode(keys...[, encoderObject : [Object|Function]])

Specifies that `keys` will be persisted. Use it to white-list fields that should be loaded from JSON and sent back as JSON.

If no `encoderObject` is provided, the identity function (`(x) -> x`) will be used to encode and decode values.

If `encoderObject` is provided, it may have `encode`, `decode` and `as` properties, for example:

```coffeescript
@encode 'myProperty',
  decode: (value, key, incomingJSON, outgoingObject, record) -> # returns a value to set on the record
  encode: (value, key, builtJSON, record) ->                    # returns a value to put into the JSON
  as: "my_property"                                             # overrides "myProperty" as the JSON key
```

__`decode`__ is applied to _incoming JSON values_ before they're set on the record. It may be `false` to prevent receiving data from the storage adapter.

The `decode` function's arguments are:

 + `value` is the raw value received from the storage adapter.
 + `key` is the key that `value` is stored under on the incoming data.
 + `incomingJSON` is the object which is being decoded into the `record`. This can be used to create compound key decoders.
 + `outgoingObject` is the object built up by the decoders and mixed into the record.
 + `record` is the record on which `fromJSON` has been called.

__`encode`__ is applied to _outgoing record values_ before they're added to the JSON. It may be set to `false` to prevent sending data to the storage adapter.

The `encode` function's arguments are:

 + `value` is the client side value of the `key` on the `record`
 + `key` is the key that `value` is stored under on the `record`. This is useful when passing the same `encoderObject` which needs to pivot on what key is being encoded to different calls to `encode`.
 + `builtJSON` is the object passed to and modified by each encoder, and eventually becomes the return value of the `toJSON` call.
 + `record` is the record on which `toJSON` has been called.

__`as`__ will override the `encode` key when getting and setting values from JSON. It may be a string or a function.

If `as` is a function, it will receive the following arguments:

 + `key` is the name which the `value` is stored under in the raw data.
 + `value` is the `value` of the `key` which will end up on the `record`.
 + `data` is the object which is modified by each encoder or decoder.
 + `record` is the record on which `toJSON` or `fromJSON` has been called.

_Note_: `Batman.Model` subclasses have no encoders by default, except for the model's `primaryKey`.

    test '@encode accepts a list of keys which are used during decoding', ->
      class Shop extends Batman.Model
        @resourceName: 'shop'
        @encode 'name', 'url', 'email', 'country'

      json = {name: "Snowdevil", url: "snowdevil.ca"}
      record = new Shop()
      record.fromJSON(json)
      equal record.get('name'), "Snowdevil"

    test '@encode accepts a list of keys which are used during encoding', ->
      class Shop extends Batman.Model
        @resourceName: 'shop'
        @encode 'name', 'url', 'email', 'country'

      record = new Shop(name: "Snowdevil", url: "snowdevil.ca")
      deepEqual record.toJSON(), {name: "Snowdevil", url: "snowdevil.ca"}

    test '@encode accepts custom encoders', ->
      class Shop extends Batman.Model
        @resourceName: 'shop'
        @encode 'name',
          encode: (name) -> name.toUpperCase()

      record = new Shop(name: "Snowdevil")
      deepEqual record.toJSON(), {name: "SNOWDEVIL"}

    test '@encode accepts custom decoders', ->
      class Shop extends Batman.Model
        @resourceName: 'shop'
        @encode 'name',
          decode: (name) -> name.replace('_', ' ')

      record = new Shop()
      record.fromJSON {name: "Snow_devil"}
      equal record.get('name'), "Snow devil"

    test '@encode can be passed an encoderObject with false to prevent the default encoder or decoder', ->
      class Shop extends Batman.Model
        @resourceName: 'shop'
        @encode 'name', {encode: false, decode: (x) -> x}
        @encode 'url'

      record = new Shop()
      record.fromJSON {name: "Snowdevil", url: "snowdevil.ca"}
      equal record.get('name'), 'Snowdevil'
      equal record.get('url'), "snowdevil.ca"
      deepEqual record.toJSON(), {url: "snowdevil.ca"}, 'The name key is absent because of encode: false'

    test '@encode accepts an as option to encode a key under a name which differs from that in the raw data', ->
      class Shop extends Batman.Model
        @resourceName: 'shop'
        @encode 'countryCode',
          as: 'country_code'
          encode: @defaultEncoder.encode
          decode: @defaultEncoder.decode

      record = new Shop(countryCode: 'SE')
      deepEqual record.toJSON(), {country_code: 'SE'}

Some more handy examples:

    test '@encode can be used to turn comma separated values into arrays', ->
      class Post extends Batman.Model
        @resourceName: 'post'
        @encode 'tags',
          decode: (string) -> string.split(', ')
          encode: (array) -> array.join(', ')

      record = new Post()
      record.fromJSON({tags: 'new, hot, cool'})
      deepEqual record.get('tags'), ['new', 'hot', 'cool']
      deepEqual record.toJSON(), {tags: 'new, hot, cool'}

    test '@encode can be used to turn arrays into sets', ->
      class Post extends Batman.Model
        @resourceName: 'post'
        @encode 'tags',
          decode: (array) -> new Batman.Set(array)
          encode: (set) -> set.toArray()

      record = new Post()
      record.fromJSON({tags: ['new', 'hot', 'cool']})
      ok record.get('tags') instanceof Batman.Set
      deepEqual record.toJSON(), {tags: ['new', 'hot', 'cool']}

    test '@encode accepts the as option as a function', ->
      class Shop extends Batman.Model
        @resourceName: 'shop'
        @encode 'countryCode',
          as: (key) -> Batman.helpers.underscore(key)
          encode: @defaultEncoder.encode
          decode: @defaultEncoder.decode

      record = new Shop(countryCode: 'SE')
      deepEqual record.toJSON(), {country_code: 'SE'}

## @validate(keys...[, options : [Object|Function]])

Assigns validators to `keys` based on `options`. All instances of the defined model will be validated according to these keys.

See [Model Validations](/docs/api/batman.model_validations.html) for a detailed description of validation options.

See [`Model::validate`](/docs/api/batman.model.html#prototype_function_validate) for information on how to get a particular record's validity.

## @%loaded : Set

The `loaded` set is available on every model class and holds every model instance seen by the system in order to function as an identity map. Successfully loading or saving individual records or batches of records will result in those records being added to the `loaded` set. Destroying instances will remove records from the identity set.

    test 'the loaded set stores all records seen', ->
      class Post extends Batman.Model
        @resourceName: 'post'
        @persist TestStorageAdapter
        @encode 'name'

      ok Post.get('loaded') instanceof Batman.Set
      equal Post.get('loaded.length'), 0
      post = new Post()
      post.save()
      equal Post.get('loaded.length'), 1

    test 'the loaded adds new records caused by loads and removes records caused by destroys', ->
      class Post extends Batman.Model
        @resourceName: 'post'
        @encode 'name'

      adapter = new TestStorageAdapter(Post)
      adapter.storage =
          'posts1': {name: "One", id:1}
          'posts2': {name: "Two", id:2}

      Post.persist(adapter)
      Post.load()
      equal Post.get('loaded.length'), 2
      post = false
      Post.find(1, (err, result) -> post = result)
      post.destroy()
      equal Post.get('loaded.length'), 1

## @%all : Set

The `all` set is an alias to the `loaded` set but with an added implicit `load` on the model. `Model.get('all')` will synchronously return the `loaded` set and asynchronously call `Model.load()` without options to load a batch of records and populate the set originally returned (the `loaded` set) with the records returned by the server.

_Note_: The notion of "all the records" is relative only to the client. It completely depends on the storage adapter in use and any backends which they may contact to determine what comes back during a `Model.load`. This means that if for example your API paginates records, the set found in `all` may hold on the first 50 records instead of the entire backend set.

`all` is useful for listing every instance of a model in a view, and since the `loaded` set will change when the `load` returns, it can be safely bound to.

    asyncTest 'the all set asynchronously fetches records when gotten', ->
      class Post extends Batman.Model
        @resourceName: 'post'
        @encode 'name'

      adapter = new AsyncTestStorageAdapter(Post)
      adapter.storage =
          'posts1': {name: "One", id:1}
          'posts2': {name: "Two", id:2}

      Post.persist(adapter)
      equal Post.get('all.length'), 0, "The synchronously returned set is empty"
      delay ->
        equal Post.get('all.length'), 2, "After the async load the set is populated"

## @clear() : Set

`Model.clear()` empties that `Model`'s identity map. This is useful for tests and other unnatural situations where records new to the system are guaranteed to be as such.

    test 'clearing a model removes all records from the identity map', ->
      class Post extends Batman.Model
        @resourceName: 'post'
        @encode 'name'

      adapter = new TestStorageAdapter(Post)
      adapter.storage =
          'posts1': {name: "One", id:1}
          'posts2': {name: "Two", id:2}
      Post.persist(adapter)
      Post.load()
      equal Post.get('loaded.length'), 2
      Post.clear()
      equal Post.get('loaded.length'), 0, "After clear() the loaded set is empty"

## @find(id[, callback : Function]) : Promise

Retrieves a record with the specified `id` from the storage adapter. If `callback` is provided, it is invoked with `(err, record)`.

It returns a `Promise` which is either resolved with the found record or rejected with any error that occurs along the way.

    asyncTest 'Model.find returns a promise that resolves with the record or rejects with an error', 4, ->
      class Post extends Batman.Model
        @resourceName: 'post'
        @encode 'name'
        @persist AsyncTestStorageAdapter,
          storage: { 'posts2': {name: "Two", id:2} }

      post2Promise = Post.find 2, (err, record) ->
          equal record.get("name"), "Two", "Records are passed to a callback"
        .then (post) ->
          equal post.get('name'), "Two", "Found records are passed to promise handlers"

      post3Promise = Post.find 3, (err, record) ->
          ok err instanceof Error, "errors are passed to callbacks"
        .catch (promiseErr) -> ok promiseErr instanceof Error, "errors are passed to handlers"

      Promise.all([post2Promise, post3Promise])
        .then -> QUnit.start()


## @load(options = {}[, callback : Function]) : Promise

Retrieves records from storage based on `options`. The `loaded` set is updated by:

- Adding records which weren't already present
- Updating records which were already present

For the two main `StorageAdapter`s batman.js provides, the `options` do different things:

- `Batman.LocalStorage`: returns records which match _all_ key-value pairs in `options`.
- `Batman.RestStorage`: some `options` are used for special purposes (like `url`) and any others are used as request parameters.

If a callback is provided, it is invoked with `(err, records)` where `records` is an array of records and `err` is any error that occured during the operation. If the `load` operation didn't load any records, `records` will be an empty array.

    asyncTest '@load calls back an array of records retrieved from the storage adapter', 4, ->
      class Post extends Batman.Model
        @resourceName: 'post'
        @encode 'name'
        @persist TestStorageAdapter,
          storage:
            'posts1': {name: "One", id:1}
            'posts2': {name: "Two", id:2}

      Post.load (err, records) ->
          equal records.length, 2, "Records are passed to the callback"
          equal records[0].get('name'), "One"
        .then (records) ->
          equal records.length, 2, "Records are passed to promise handlers"
          equal records[0].get('name'), "One"
        .then -> QUnit.start()

    asyncTest '@load calls back with an empty array if no records are found', ->
      class Post extends Batman.Model
        @resourceName: 'post'
        @encode 'name'
        @persist TestStorageAdapter, storage: []

      posts = false
      Post.load (err, result) ->
        throw err if err
        posts = result

      delay ->
        equal posts.length, 0

## @create([attributes = {},] callback) : Model

`App.Model.create` is a convenience method that is equivalent to
calling `(new App.Model).save()`:

    asyncTest "@create instantiates a new record instance and saves it", ->
      class Post extends Batman.Model
        @resourceName: 'post'
        @encode 'name'
        @persist TestStorageAdapter, storage: []

      otherRecord = Post.create name: 'aName', ->

      delay ->
        equal otherRecord.get('name'), 'aName'
        equal otherRecord.isNew(), false


## @findOrCreate(attributes = {}, callback) : Model

## @createFromJSON(attributes = {}) : Model

Returns an instance of the model based on `attributes`. If the `primaryKey` is present in `attributes`, the  `loaded` set will be searched for a match. If a match is found, it will be updated with `attributes` (without tracking) and returned. If the `primaryKey` isn't present, a new instance is added to the `loaded` set and returned.

Since `createFromJSON` checks the `loaded` set, it's a great way to load data without duplicating records in memory.

## @createMultipleFromJSON(attributesArray: Array) : Array

Loads data from JSON like `Model.createFromJSON`, but `attributesArray` is an array of objects and returns an array of records. `createMultipleFromJSON` loads new records all at once, so `Model.loaded.itemsWereAdded` is only fired once.

## ::%id

A universally accessible accessor to the record's primary key. If the record's
primary key is `id` (the default), getting/setting this accessor simply passes
the call through to `id`, otherwise it proxies the call to the custom primary key.

    test "id proxies the primary key", ->
      class Post extends Batman.Model
        @primaryKey: 'name'

      post = new Post(name: 'Witty title')
      equal post.get('id'), 'Witty title'

      post.set('id', 'Wittier title')
      equal post.get('name'), 'Wittier title'

## ::isDirty() : Boolean

Returns `true` if any keys have been changed since the record was initialized or saved.

## ::%isDirty : Boolean

A bindable accessor on [`isDirty`](/docs/api/batman.model.html#prototype_function_isdirty).

## ::%dirtyKeys : Set

The [`Batman.Set`](/docs/api/batman.set.html) of keys which have been modified since the last time the record was saved.

## ::%errors : Batman.ErrorsSet

`errors` is a `Batman.ErrorsSet`, which is simply a [`Batman.Set`](/docs/api/batman.set.html) of [`Batman.ValidationError`](/docs/api/batman.validationerror.html)s present on the model instance.

- `user.get('errors')` returns the errors on the `user` record
- `user.get('errors.length')` returns the number of errors, total

You can also access the errors for a specific attribute of the record:

- `user.get('errors.email_address')` returns the errors on the `email_address` attribute
- `user.get('errors.email_address.length')` returns the number of errors on the `email_address` attribute

## ::constructor(idOrAttributes = {}) : Model

If `idOrAttributes` is an object, the values are mixed into the new record. Otherwise, `idOrAttrubutes` is set to the new record's [`id`](/docs/api/batman.model.html#prototype_accessor_id).

## ::isNew() : boolean

Returns true if the instance represents a record that hasn't yet been persisted to storage. The default implementation simply checks if `@get('id')` is undefined, but you can override this on your own models.

`isNew` is used to determine whether `record.save()` will perform a `create` action or a `save` action.

## ::%isNew : Boolean

A bindable accessor on [`isNew`](/docs/api/batman.model.html#prototype_function_isnew).

## ::updateAttributes(attributes) : Model

Mixes in `attributes` into the record (using `set`). Doesn't save the record.

## ::toString() : string

Returns a string representation suitable for debugging. By default this just contains the model's `resourceName` and `id`

## ::%attributes : Hash

`attributes` is a `Batman.Hash` where a record's attributes are stored. `Batman.Model`'s default accessor stores values in `attributes`, so it includes:

- attributes defined with `@encode`
- keys assigned with `set`, unless the key has a specifically defined accessor

But it doesn't include:

- keys that have specifically defined accessors (eg, `errors`, `lifecycle`, `isNew`)

A record's attributes are used by `Model::transaction` to create a deep copy of the record.

## ::toJSON() : Object

Returns a JavaScript object containing the attributes of the record, using any specified encoders.

    test "toJSON returns a JavaScript object with the record's attributes", ->
      class Criminal extends Batman.Model
        @encode "name", "notorious"

      criminal = new Criminal(name: "Talia al Ghul", notorious: true)
      criminal_json = criminal.toJSON()
      equal criminal_json.name, "Talia al Ghul"
      equal criminal_json.notorious, true

## ::fromJSON() : Model

Loads attributes from a bare object into this instance.

    test 'fromJSON overwrites existing attributes', ->
      class Criminal extends Batman.Model
        @encode "name", "notorious"

      criminal = new Criminal(name: "Dr. Jonathan Crane", notorious: false)
      new_params =
        name: "Scarecrow"
        notorious: true
      criminal.fromJSON(new_params)

      equal criminal.get("notorious"), true
      equal criminal.get("name"), "Scarecrow"

## ::toParam() : value

Returns a representation of the model suitable for use in a URL. By default, this is the record's `id`.

This method is used by the routing system for serializing records into a URL.

## ::hasStorage() : boolean

True when the record has a storage adapter defined.

## ::load(options = {}[, callback]) : Promise

Loads the record from storage. The options object will be passed to the storage adapter when it performs the `read` operation.

The callback takes three parameters: error, the loaded record, and the environment. `Load`ing a record clears all errors on that record.

If the read operation fails or if the record is in a state which doesn't permit `load`, (for example, calling `load` on a deleted record) the callback will be invoked with an error.

## ::save(options = {}[, callback]) : Promise

Saves the record to storage by:

1. Validating it, and if it is valid:
2. Saving it. If the record [`isNew`](/docs/api/batman.model.html#prototype_function_isnew) it will use `create`, otherwise it will `update`.

If the record is not valid, it will reject with the record's `Batman.ErrorsSet` and the storage operation will not be performed.

If a callback is provided, it will be invoked with `(err, record)`. `err` may be

Available options include:
- `only`: A whitelist that will submit only the specified model attributes from the storage adapter.  This is useful when you want to do partial updates of a model without sending the full model content.  e.g., `options = {only: ['name', 'bio']}`
- `except`: A blacklist that will prevent specified model attributes from being transmitted from the storage adapter.  e.g., `options = {except: ['sensitive_data']}`

## ::destroy(options = {}[, callback]) : Promise

Destroys the record from storage. If the operation is successful, the record is removed from its Model's [`loaded`](/docs/api/batman.model.html#class_function_loaded) set.

```coffeescript
criminal = new Criminal name: "The penguin"
criminal.destroy()
  .catch (err) ->
    console.log "Oh no! #{record.get('name')} is still on the loose!"
```

If `callback` is provided, it is invoked with `(err, record, env)`.

If the record's current lifecycle state doesn't allow the `destroy` action, the callback will be invoked with a `Batman.StateMachine.InvalidTransitionError`. For example, this could occur if `destroy` is called on an already-destroyed record.

## ::validate(callback)

`Model::validate` checks the model against the validations declared in the model definition (with [`Model@validate`](/docs/api/batman.model.html#class_function_validate)). This method accepts a callback with two arguments: any JS error that occurred within the validator function, and the set of [`Batman.ValidationError`](/docs/api/batman.validationerror.html)s that the input generated.

For example:

    test "validate(callback) will call the callback only after all keys have been validated", ->
      class Product extends Batman.Model
        @validate 'name', 'price', presence: yes

      newProduct = new Product
      newProduct.validate (javascriptError, validationErrors) ->
        throw javascriptError if javascriptError
        equal validationErrors.length, 2
        equal newProduct.get('errors.length'), 2
        equal newProduct.get('errors.name.length'), 1
        equal newProduct.get('errors.price.length'), 1

## ::transaction() : Model

Creates a deep copy of the record instance based on its `"attributes"`, allowing it to be modified without affecting the original. Also mixes in `Batman.Transaction`.
Useful for implementing actions that can be cancelled.

To apply the changes made to a transaction, call `applyChanges`.
To apply changes and save the record after running validations, call `save`.

    test "transaction creates an independent clone of a record", ->
      record = new Batman.Model(name: 'Felix')

      transaction = record.transaction()
      transaction.set('name', 'Camouflage')
      equal transaction.get('name'), 'Camouflage'
      equal record.get('name'), 'Felix'

      transaction.applyChanges()
      equal record.get('name'), 'Camouflage'


## ::reflectOnAssociation(label : String)

Returns the `Batman.Association` for the record's association named by `label`.
Returns `null` if the association does not exist.

## ::reflectOnAllAssociations([type: String])

If `type` is passed (eg, `hasMany`), returns a `Batman.SimpleSet` of all associations of that type on the record.
If no type is passed, all associations are returned.
If the record has no associations, returns `null`.

## ::coerceIntegerPrimaryKey[=true] : Boolean

By default, primary keys that match `/\d+/` will be coerced to integers when set on the model. You can disable this with:

```coffeescript
class MyApp.MyModel
  coerceIntegerPrimaryKey: false
```

