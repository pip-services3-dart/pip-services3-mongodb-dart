import 'dart:async';

import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:pip_services3_commons/pip_services3_commons.dart';
import 'package:pip_services3_components/pip_services3_components.dart';

import '../connect/MongoDbConnectionResolver.dart';
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
/// - \*:logger:\*:\*:1.0           (optional) [ILogger] components to pass log messages
/// - \*:discovery:\*:\*:1.0        (optional) [IDiscovery] services
/// - \*:credential-store:\*:\*:1.0 (optional) Credential stores to resolve credentials
///
/// ### Example ###
///
///     class MyMongoDbPersistence extends MongoDbPersistence<MyData> {
///
///       public constructor() {
///           base('mydata');
///       }
///
///       public getByName(String correlationId, name: string, callback: (err, item) => void): void {
///         var criteria = { name: name };
///         this._model.findOne(criteria, callback);
///       });
///
///       public set(correlatonId: string, item: MyData, callback: (err) => void): void {
///         var criteria = { name: item.name };
///         var options = { upsert: true, new: true };
///         this._model.findOneAndUpdate(criteria, item, options, callback);
///       }
///
///     }
///
///     var persistence = new MyMongoDbPersistence();
///     persistence.configure(ConfigParams.fromTuples(
///         'host', 'localhost',
///         'port', 27017
///     ));
///
///     persitence.open('123', (err) => {
///          ...
///     });
///
///     persistence.set('123', { name: 'ABC' }, (err) => {
///         persistence.getByName('123', 'ABC', (err, item) => {
///             console.log(item);                   // Result: { name: 'ABC' }
///         });
///     });

class MongoDbPersistence
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

  ConfigParams _config;
  IReferences _references;
  bool _opened;
  bool _localConnection;
  final _indexes = <MongoDbIndex>[];

  /// The dependency resolver.
  var dependencyResolver =
      DependencyResolver(MongoDbPersistence._defaultConfig);

  /// The logger.
  var logger = CompositeLogger();

  /// The MongoDB connection component.
  MongoDbConnection connection;

  /// The MongoDB connection object.
  mongo.Db client;

  /// The MongoDB database name.
  String databaseName;

  /// The MongoDB colleciton object.
  String collectionName;

  /// The MongoDb database object.
  //protected _db: any;

  /// The MongoDb collection object.
  mongo.DbCollection collection;

  /// Creates a new instance of the persistence component.
  ///
  /// - [collection]    (optional) a collection name.
  MongoDbPersistence([String collection]) {
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
        config.getAsStringWithDefault('collection', collectionName);
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
      connection.configure(_config);
    }

    if (_references != null) {
      connection.setReferences(_references);
    }

    return connection;
  }

  /// Adds index definition to create it on opening
  /// - [keys] index keys (fields)
  /// - [options] index options
  void ensureIndex(keys, [options]) {
    if (keys == null) return;
    _indexes.add(MongoDbIndex(keys, options));
  }

  /// Converts object value from internal to public format.
  ///
  /// - value     an object in internal format to convert.
  /// Returns converted object in public format.
  dynamic convertToPublic(value) {
    if (value != null) {
      if (value._id != null) {
        value.id = value._id;
        value.remove('_id');
      }
    }
    return value;
  }

  /// Convert object value from public to internal format.
  ///
  /// - [value]     an object in public format to convert.
  /// Returns converted object in internal format.
  dynamic convertFromPublic(value) {
    if (value != null) {
      if (value.id != null) {
        value._id = value._id ?? value.id;
        value.remove['id'];
      }
    }
    return value;
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
  Future open(String correlationId) async {
    if (_opened) {
      return null;
    }

    if (connection == null) {
      connection = _createConnection();
      _localConnection = true;
    }

    if (_localConnection) {
      try {
        await connection.open(correlationId);
      } catch (err) {
        if (err == null && connection == null) {
          throw InvalidStateException(correlationId, 'NOconnection',
                  'MongoDB connection is missing')
              .withCause(err);
        }
      }
    }

    if (!connection.isOpen()) {
      throw ConnectionException(
          correlationId, 'CONNECT_FAILED', 'MongoDB connection is not opened');
    }

    _opened = false;

    client = connection.getConnection();
    databaseName = connection.getDatabaseName();
    mongo.DbCollection coll;
    try {
      coll = await client.collection(collectionName);
    } catch (err) {
      client = null;

      throw ConnectionException(
              correlationId, 'CONNECT_FAILED', 'Connection to mongodb failed')
          .withCause(err);
    }
    try {
      // Recreate indexes
      for (var index in _indexes) {
        var keys = await client.createIndex(collectionName,
            keys: index.keys,
            unique: index.unique,
            sparse: index.sparse,
            background: index.background,
            dropDups: index.dropDups,
            partialFilterExpression: index.partialFilterExpression,
            name: index.name);

        var indexName = keys['name'] ?? index.keys.keys.join(',');
        logger.debug(correlationId, 'Created index %s for collection %s',
            [indexName, collectionName]);
      }
    } catch (err) {
      if (err != null) {
        client = null;
        throw ConnectionException(
                correlationId, 'CONNECT_FAILED', 'Connection to mongodb failed')
            .withCause(err);
      } else {
        _opened = true;
        collection = coll;
        logger.debug(
            correlationId,
            'Connected to mongodb database %s, collection %s',
            [databaseName, collectionName]);
      }
    }
  }

  /// Closes component and frees used resources.
  ///
  /// - [correlationId] 	(optional) transaction id to trace execution through call chain.
  /// Return 			Future that receives error or null no errors occured.
  @override
  Future close(String correlationId) async {
    if (!_opened) {
      return null;
    }

    if (connection == null) {
      throw InvalidStateException(
          correlationId, 'NOconnection', 'MongoDb connection is missing');
    }

    if (_localConnection) {
      await connection.close(correlationId);
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
  Future clear(String correlationId) async {
    // Return error if collection is not set
    if (collectionName == null) {
      throw Exception('Collection name is not defined');
    }

    // this.client.dropCollection(this.collectionName, (err) => {
    //     if (err && (err.message != 'ns not found' || err.message != 'topology was destroyed'))
    //         err = null;

    //     if (err) {
    //         err = new ConnectionException(correlationId, 'CONNECT_FAILED', 'Connection to mongodb failed')
    //             .withCause(err);
    //     }

    //     if (callback) callback(err);
    // });
    try {
      await collection.remove({});
    } catch (err) {
      throw ConnectionException(
              correlationId, 'CONNECT_FAILED', 'Connection to mongodb failed')
          .withCause(err);
    }
  }
}
