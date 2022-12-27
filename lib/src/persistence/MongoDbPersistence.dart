import 'dart:async';
import 'dart:convert';

import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:mongo_dart_query/mongo_dart_query.dart' as mngquery;
import 'package:pip_services3_commons/pip_services3_commons.dart';
import 'package:pip_services3_components/pip_services3_components.dart';

import './MongoDbConnection.dart';
import './MongoDbIndex.dart';

/// Abstract persistence component that stores data in MongoDB using plain driver.
///
/// This is the most basic persistence component that is only
/// able to store data items of any type. Specific CRUD operations
/// over the data items must be implemented in child classes by
/// accessing this.client or this.collection properties.
///
/// ### Configuration parameters ###
///
/// - [collection]:                  (optional) MongoDB collection name
/// - [connection](s):
///   - [discovery_key]:             (optional) a key to retrieve the connection from [connect.idiscovery.html IDiscovery]]
///   - [host]:                      host name or IP address
///   - [port]:                      port number (default: 27017)
///   - [uri]:                       resource URI or connection string with all parameters in it
/// - [credential](s):
///   - [store_key]:                 (optional) a key to retrieve the credentials from [auth.icredentialstore.html ICredentialStore]]
///   - [username]:                  (optional) user name
///   - [password]:                  (optional) user password
/// - [options]:
///   - [max_pool_size]:             (optional) maximum connection pool size (default: 2)
///   - [keep_alive]:                (optional) enable connection keep alive (default: true)
///   - [connect_timeout]:           (optional) connection timeout in milliseconds (default: 5000)
///   - [socket_timeout]:            (optional) socket timeout in milliseconds (default: 360000)
///   - [auto_reconnect]:            (optional) enable auto reconnection (default: true)
///   - [reconnect_interval]:        (optional) reconnection interval in milliseconds (default: 1000)
///   - [max_page_size]:             (optional) maximum page size (default: 100)
///   - [replica_set]:               (optional) name of replica set
///   - [ssl]:                       (optional) enable SSL connection (default: false)
///   - [auth_source]:               (optional) authentication source
///   - [debug]:                     (optional) enable debug output (default: false).
///
/// ### References ###
///
/// - \*:logger:\*:\*:1.0           (optional) [ILogger](https://pub.dev/documentation/pip_services3_components/latest/pip_services3_components/ILogger-class.html) components to pass log messages
/// - \*:discovery:\*:\*:1.0        (optional) [IDiscovery](https://pub.dev/documentation/pip_services3_components/latest/pip_services3_components/IDiscovery-class.html) services
/// - \*:credential-store:\*:\*:1.0 (optional) Credential stores to resolve credentials
///
/// ### Example ###
///
///     class MyMongoDbPersistence extends MongoDbPersistence<MyData> {
///
///       MyMongoDbPersistence():base('mydata');
///
///       Future<MyData> getByName(String? correlationId, String name) {
///           var filter = {'name': name};
///           var query = mngquery.SelectorBuilder();
///           var selector = <String, dynamic>{};
///           selector[r'$query'] = filter;
///           query.raw(selector);
///           var item = await collection.findOne(filter);
///           if (item == null) {
///             return null;
///           }
///           item = convertToPublic(item);
///           var instance = MyData.fromJson(item);
///           return instance;
///       });
///
///       Future<MyData> set(String correlatonId, MyData item) {
///         if (item == null) {
///           return null;
///         }
///         var jsonMap = json.decode(json.encode(item));
///         // Assign unique id
///         if (jsonMap['id'] == null) {
///           jsonMap['id'] = IdGenerator.nextLong();
///         }
///         convertFromPublic(jsonMap);
///         var filter = {r'$query': {'name': jsonMap['name']}};
///         var result = await collection.findAndModify(
///             query: filter, update: jsonMap, returnNew: true, upsert: true);
///         if (result != null) {
///             convertToPublic(result);
///             var newItem = MyData.fromJson(result);;
///             return newItem;
///         }
///         return null;
///       }
///
///     }
///
///     var persistence = MyMongoDbPersistence();
///     persistence.configure(ConfigParams.fromTuples([
///         'host', 'localhost',
///         'port', 27017
///     ]));
///
///     await persitence.open('123');
///
///     await persistence.set('123', { name: 'ABC' });
///     var item = await persistence.getByName('123', 'ABC');
///     print(item);         // Result: { name: 'ABC' }

class MongoDbPersistence<T>
    implements
        IReferenceable,
        IUnreferenceable,
        IConfigurable,
        IOpenable,
        ICleanable {
  static final _defaultConfig = ConfigParams.fromTuples([
    'collection', null,
    'dependencies.connection', '*:connection:mongodb:*:1.0',

    // connections.*
    // credential.*

    'options.max_pool_size', 2,
    'options.keep_alive', 1,
    'options.connect_timeout', 5000,
    'options.auto_reconnect', true,
    'options.max_page_size', 100,
    'options.debug', true
  ]);

  ConfigParams? _config;
  IReferences? _references;
  bool _opened = false;
  bool? _localConnection;
  final _indexes = <MongoDbIndex>[];
  var maxPageSize = 100;

  /// The dependency resolver.
  var dependencyResolver =
      DependencyResolver(MongoDbPersistence._defaultConfig);

  /// The logger.
  var logger = CompositeLogger();

  /// The MongoDB connection component.
  MongoDbConnection? connection;

  /// The MongoDB connection object.
  mongo.Db? client;

  /// The MongoDB database name.
  String? databaseName;

  /// The MongoDB colleciton object.
  String? collectionName;

  /// The MongoDb database object.
  //protected _db: any;

  /// The MongoDb collection object.
  mongo.DbCollection? collection;

  /// Creates a new instance of the persistence component.
  ///
  /// - [collection]    (optional) a collection name.
  MongoDbPersistence([String? collection]) {
    collectionName = collection;
  }

  /// Configures component by passing configuration parameters.
  ///
  /// - [config]    configuration parameters to be set.
  @override
  void configure(ConfigParams config) {
    config = config.setDefaults(MongoDbPersistence._defaultConfig);
    _config = config;
    dependencyResolver.configure(config);
    collectionName =
        config.getAsStringWithDefault('collection', collectionName ?? '');
  }

  /// Sets references to dependent components.
  ///
  /// - [references] 	references to locate the component dependencies.
  @override
  void setReferences(IReferences references) {
    _references = references;
    logger.setReferences(references);

    // Get connection
    dependencyResolver.setReferences(references);
    connection = dependencyResolver.getOneOptional('connection');
    // Or create a local one
    if (connection == null) {
      connection = _createConnection();
      _localConnection = true;
    } else {
      _localConnection = false;
    }
  }

  /// Unsets (clears) previously set references to dependent components.
  @override
  void unsetReferences() {
    connection = null;
  }

  MongoDbConnection _createConnection() {
    var connection = MongoDbConnection();

    if (_config != null) {
      connection.configure(_config!);
    }

    if (_references != null) {
      connection.setReferences(_references!);
    }

    return connection;
  }

  /// Adds index definition to create it on opening
  /// - [keys] index keys (fields)
  /// - [options] index options
  void ensureIndex(keys,
      {String key = '',
      bool unique = false,
      bool sparse = false,
      bool background = false,
      bool dropDups = false,
      Map<String, dynamic>? partialFilterExpression,
      String name = ''}) {
    if (keys == null) return;
    _indexes.add(MongoDbIndex(keys, key, unique, sparse, background, dropDups,
        partialFilterExpression ?? <String, dynamic>{}, name));
  }

  /// Checks if the component is opened.
  ///
  /// Returns true if the component has been opened and false otherwise.
  @override
  bool isOpen() {
    return _opened;
  }

  /// Opens the component.
  ///
  /// - correlationId 	(optional) transaction id to trace execution through call chain.
  /// Return 			Future that receives error or null no errors occured.
  @override
  Future open(String? correlationId) async {
    if (_opened) {
      return null;
    }

    if (connection == null) {
      connection = _createConnection();
      _localConnection = true;
    }

    if (_localConnection == true) {
      await connection!.open(correlationId);
    }

    if (connection == null) {
      throw InvalidStateException(
          correlationId, 'NO_CONNECTION', 'MongoDB connection is missing');
    }

    if (!connection!.isOpen()) {
      throw ConnectionException(
          correlationId, 'CONNECT_FAILED', 'MongoDB connection is not opened');
    }

    _opened = false;

    client = connection!.getConnection();
    databaseName = connection!.getDatabaseName();
    mongo.DbCollection coll;
    try {
      coll = client!.collection(collectionName!);
    } catch (err) {
      client = null;

      throw ConnectionException(
              correlationId, 'CONNECT_FAILED', 'Connection to mongodb failed')
          .withCause(err);
    }
    try {
      // Recreate indexes
      for (var index in _indexes) {
        //TODO: Need fix work with indexes!
        var keys = {};
        //  var keys = await client.createIndex(collectionName,
        //      keys: index.keys,
        //     unique: index.unique,
        //     sparse: index.sparse,
        //     background: index.background,
        //     dropDups: index.dropDups,
        //     partialFilterExpression: index.partialFilterExpression,
        //     name: index.name
        // );

        var indexName = keys['name'] ?? index.keys.keys.join(',');
        logger.debug(correlationId, 'Created index %s for collection %s',
            [indexName, collectionName]);
      }
    } catch (err) {
      client = null;
      throw ConnectionException(
              correlationId, 'CONNECT_FAILED', 'Connection to mongodb failed')
          .withCause(err);
    }
    _opened = true;
    collection = coll;
    logger.debug(
        correlationId,
        'Connected to mongodb database %s, collection %s',
        [databaseName, collectionName]);
  }

  /// Closes component and frees used resources.
  ///
  /// - [correlationId] 	(optional) transaction id to trace execution through call chain.
  /// Return 			Future that receives error or null no errors occured.
  @override
  Future close(String? correlationId) async {
    if (!_opened) {
      return null;
    }

    if (connection == null) {
      throw InvalidStateException(
          correlationId, 'NOconnection', 'MongoDb connection is missing');
    }

    if (_localConnection == true) {
      await connection!.close(correlationId);
    }
    _opened = false;
    client = null;
    collection = null;
  }

  /// Clears component state.
  ///
  /// - [correlationId] 	(optional) transaction id to trace execution through call chain.
  /// Return 			Future that receives error or null no errors occured.

  @override
  Future clear(String? correlationId) async {
    // Return error if collection is not set
    if (collectionName == null) {
      throw Exception('Collection name is not defined');
    }

    try {
      await collection!.remove(<String, String>{});
    } catch (err) {
      throw ConnectionException(
              correlationId, 'CONNECT_FAILED', 'Connection to mongodb failed')
          .withCause(err);
    }
  }

  /// Converts object value from internal to public format.
  ///
  /// - [item]    an Map object from MongoDB to convert.
  /// Returns     new created object of type [T] in public format.
  dynamic convertToPublic(Map<String, dynamic>? item) {
    if (item != null) {
      if (item['_id'] != null) {
        item['id'] = item['_id'];
        item.remove('_id');
      }
    }
    var instance = TypeReflector.createInstanceByType(T, []);
    instance.fromJson(item);
    return instance;
  }

  /// Convert object value from public to internal format.
  ///
  /// - [item]     an object of type [T] in public format to convert.
  /// Returns      converted Map in internal format for MongoDB.
  Map<String, dynamic>? convertFromPublic(dynamic item,
      {bool createUid = false}) {
    if (item != null) {
      // var jsonMap = item.toJson();
      var jsonMap = json.decode(json.encode(item));
      // Assign unique id, if need
      if (createUid && jsonMap['id'] == null) {
        jsonMap['id'] = IdGenerator.nextLong();
      }

      if (jsonMap['id'] != null) {
        jsonMap['_id'] = jsonMap['_id'] ?? jsonMap['id'];
        jsonMap.remove('id');
      }
      return jsonMap;
    }
    return null; //<String, dynamic>{};
  }

  /// Converts the given object from the public partial format.
  ///
  /// - [value]     the object to convert from the public partial format.
  /// Returns the initial object.
  Map<String, dynamic>? convertFromPublicPartial(Map<String, dynamic>? item) {
    if (item != null) {
      if (item['id'] != null) {
        item['_id'] = item['_id'] ?? item['id'];
        item.remove('id');
      }
    }
    return item;
  }

  /// Gets a page of data items retrieved by a given filter and sorted according to sort parameters.
  ///
  /// This method shall be called by a public getPageByFilter method from child class that
  /// receives FilterParams and converts them into a filter function.
  ///
  /// - [correlationId]     (optional) transaction id to trace execution through call chain.
  /// - [filter]            (optional) a filter JSON object
  /// - [paging]            (optional) paging parameters
  /// - [sort]              (optional) sorting JSON object
  /// Return                Future that receives a data page.
  /// Throws error
  Future<DataPage<T>> getPageByFilterEx(
      String? correlationId,
      Map<String, dynamic>? filter,
      PagingParams? paging,
      Map<String, dynamic>? sort) async {
    // Adjust max item count based on configuration
    paging = paging ?? PagingParams();
    var skip = paging.getSkip(-1);
    var take = paging.getTake(maxPageSize);
    var pagingEnabled = paging.total;

    // Configure options
    var query = mngquery.SelectorBuilder();
    if (skip >= 0) query.skip(skip);
    query.limit(take);
    var selector = <String, dynamic>{};
    if (filter != null && filter.isNotEmpty) {
      selector[r'$query'] = filter;
    }
    if (sort != null) {
      selector['orderby'] = sort;
    }
    query.raw(selector);

    var items = <T>[];
    var result = await collection?.find(query).toList();
    for (var item in result ?? []) {
      items.add(convertToPublic(item));
    }
    logger.trace(
        correlationId, 'Retrieved %d from %s', [items.length, collectionName]);
    if (pagingEnabled) {
      var count = await collection?.count(selector) ?? 0;
      return DataPage<T>(items, count);
    } else {
      return DataPage<T>(items, 0);
    }
  }

  /// Gets a list of data items retrieved by a given filter and sorted according to sort parameters.
  ///
  /// This method shall be called by a public getListByFilter method from child class that
  /// receives FilterParams and converts them into a filter function.
  ///
  /// - [correlationId]    (optional) transaction id to trace execution through call chain.
  /// - [filter]           (optional) a filter JSON object
  /// - [sort]             (optional) sorting JSON object
  /// Return         Future that receives a data list.
  /// Throw error
  Future<List<T>> getListByFilterEx(String? correlationId,
      Map<String, dynamic>? filter, Map<String, dynamic>? sort) async {
    // Configure options
    var query = mngquery.SelectorBuilder();
    var selector = <String, dynamic>{};
    if (filter != null && filter.isNotEmpty) {
      selector[r'$query'] = filter;
    }
    if (sort != null) {
      selector['orderby'] = sort;
    }

    query.raw(selector);
    var items = <T>[];

    var results = await collection?.find(query).toList() ?? [];
    for (var item in results) {
      items.add(convertToPublic(item));
    }

    logger.trace(
        correlationId, 'Retrieved %d from %s', [items.length, collectionName]);
    return items;
  }

  /// Deletes data items that match to a given filter.
  ///
  /// This method shall be called by a public deleteByFilter method from child class that
  /// receives FilterParams and converts them into a filter function.
  ///
  /// - [correlationId]     (optional) transaction id to trace execution through call chain.
  /// - [filter]            (optional) a filter JSON object.
  /// Return          (optional) Future that receives null for success.
  /// Throws error
  Future deleteByFilterEx(
      String? correlationId, Map<String, dynamic> filter) async {
    var result = await collection?.remove(filter);
    if (result != null && result['ok'] == 1.0) {
      var count = result['n'] ?? 0;
      logger.trace(
          correlationId, 'Deleted %d items from %s', [count, collectionName]);
    }
  }

  /// Gets a random item from items that match to a given filter.
  ///
  /// This method shall be called by a public getOneRandom method from child class that
  /// receives FilterParams and converts them into a filter function.
  ///
  /// - [correlationId]     (optional) transaction id to trace execution through call chain.
  /// - [filter]            (optional) a filter JSON object
  /// Return                Future that receives a random item
  /// Throws error.
  Future<T?> getOneRandomEx(
      String? correlationId, Map<String, dynamic> filter) async {
    var query = mngquery.SelectorBuilder();
    var selector = <String, dynamic>{};
    selector[r'$query'] = filter;
    var count = await collection?.count(query);
    var pos = RandomInteger.nextInteger(0, count! - 1);
    query.skip(pos >= 0 ? pos : 0);
    query.limit(1);

    var items = collection?.find(query.raw(selector));
    try {
      var item = (items != null) ? await items.first : null;
      return convertToPublic(item);
    } catch (ex) {
      return null;
    }
  }

  /// Gets a count of data items retrieved by a given filter.
  ///
  /// This method shall be called by a public getCountByFilter method from child class that
  /// receives FilterParams and converts them into a filter function.
  ///
  /// - [correlationId]    (optional) transaction id to trace execution through call chain.
  /// - [filter]           (optional) a filter JSON object
  /// Return         Future that receives a data list.
  /// Throw error
  Future<int> getCountByFilterEx(
      String? correlationId, Map<String, dynamic>? filter) async {
    // Configure options
    var query = mngquery.SelectorBuilder();
    var selector = <String, dynamic>{};
    if (filter != null && filter.isNotEmpty) {
      selector[r'$query'] = filter;
    }
    var count = await collection?.count(query) ?? 0;
    logger.trace(correlationId, 'Find %d items in %s', [count, collectionName]);
    return count;
  }

  /// Creates a data item.
  ///
  /// - [correlation_id]    (optional) transaction id to trace execution through call chain.
  /// - [item]              an item to be created.
  /// Return                Future that receives created item
  /// Throws error.
  Future<T?> create(String? correlationId, T? item) async {
    if (item == null) {
      return null;
    }
    var jsonMap = convertFromPublic(item, createUid: false);
    var result = jsonMap != null ? await collection?.insert(jsonMap) : null;
    if (result != null && result['ok'] == 1.0) {
      logger.trace(correlationId, 'Created in %s with id = %s',
          [collectionName, jsonMap!['_id']]);

      return convertToPublic(jsonMap);
    }
    return null;
  }
}
