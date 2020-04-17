import 'dart:async';

import 'package:mongo_dart/mongo_dart.dart' as mongo;

import 'package:pip_services3_commons/pip_services3_commons.dart';
import 'package:pip_services3_components/pip_services3_components.dart';
import '../connect/MongoDbConnectionResolver.dart';

/// MongoDB connection using plain driver.
///
/// By defining a connection and sharing it through multiple persistence components
/// you can reduce number of used database connections.
///
/// ### Configuration parameters ###
///
/// - [connection(s)]:
///   - [discovery_key]:             (optional) a key to retrieve the connection from [IDiscovery]
///   - [host]:                      host name or IP address
///   - [port]:                      port number (default: 27017)
///   - [uri]:                       resource URI or connection string with all parameters in it
/// - [credential(s)]:
///   - [store_key]:                 (optional) a key to retrieve the credentials from [ICredentialStore]
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
/// - \*:logger:\*:\*:1.0           (optional) [ILogger]] components to pass log messages
/// - \*:discovery:\*:\*:1.0        (optional) [IDiscovery]] services
/// - \*:credential-store:\*:\*:1.0 (optional) Credential stores to resolve credentials
///

class MongoDbConnection implements IReferenceable, IConfigurable, IOpenable {
  final _defaultConfig = ConfigParams.fromTuples([
    // connections.*
    // credential.*

    'options.max_pool_size', 2,
    'options.keep_alive', 1,
    'options.connect_timeout', 5000,
    'options.auto_reconnect', true,
    'options.max_page_size', 100,
    'options.debug', true
  ]);

  /// The logger.
  var logger = CompositeLogger();

  /// The connection resolver.
  var connectionResolver = MongoDbConnectionResolver();

  /// The configuration options.
  var options = ConfigParams();

  /// The MongoDB database name.
  String databaseName;

  /// The MongoDb database object.
  mongo.Db connection;

  /// Creates a new instance of the connection component.
  MongoDbConnection();

  /// Configures component by passing configuration parameters.
  ///
  /// - [config]    configuration parameters to be set.
  @override
  void configure(ConfigParams config) {
    config = config.setDefaults(_defaultConfig);
    connectionResolver.configure(config);
    options = options.override(config.getSection('options'));
  }

  /// Sets references to dependent components.
  ///
  /// - [references] 	references to locate the component dependencies.
  @override
  void setReferences(IReferences references) {
    logger.setReferences(references);
    connectionResolver.setReferences(references);
  }

  /// Checks if the component is opened.
  ///
  /// Returns true if the component has been opened and false otherwise.
  @override
  bool isOpen() {
    return connection != null;
  }

  Map<String, dynamic> _composeSettings() {
    var maxPoolSize = options.getAsNullableInteger('max_pool_size');
    var keepAlive = options.getAsNullableInteger('keep_alive');
    var connectTimeoutMS = options.getAsNullableInteger('connect_timeout');
    var socketTimeoutMS = options.getAsNullableInteger('socket_timeout');
    var autoReconnect = options.getAsNullableBoolean('auto_reconnect');
    var reconnectInterval = options.getAsNullableInteger('reconnect_interval');
    var debug = options.getAsNullableBoolean('debug');

    var ssl = options.getAsNullableBoolean('ssl');
    var replicaSet = options.getAsNullableString('replica_set');
    var authSource = options.getAsNullableString('auth_source');
    var authUser = options.getAsNullableString('auth_user');
    var authPassword = options.getAsNullableString('auth_password');

    var settings = <String, dynamic>{
      'poolSize': maxPoolSize,
      'keepAlive': keepAlive,
      //autoReconnect: autoReconnect,
      'reconnectInterval': reconnectInterval,
      'connectTimeoutMS': connectTimeoutMS,
      'socketTimeoutMS': socketTimeoutMS,
      // ssl: ssl,
      // replicaSet: replicaSet,
      // authSource: authSource,
      // 'auth.user': authUser,
      // 'auth.password': authPassword
    };

    if (ssl != null) {
      settings['ssl'] = ssl;
    }
    if (replicaSet != null) {
      settings['replicaSet'] = replicaSet;
    }
    if (authSource != null) {
      settings['authSource'] = authSource;
    }
    if (authUser != null) {
      settings['user'] = authUser;
    }
    if (authPassword != null) {
      settings['password'] = authPassword;
    }

    return settings;
  }

  /// Opens the component.
  ///
  /// - [correlationId] 	(optional) transaction id to trace execution through call chain.
  /// Returns 			      Future that receives null no errors occured.
  /// Throws error
  @override
  Future open(String correlationId) async {
    String uri;
    try {
      uri = await connectionResolver.resolve(correlationId);
    } catch (err) {
      logger.error(correlationId, ApplicationException().wrap(err),
          'Failed to resolve MongoDb connection');
    }

    logger.debug(correlationId, 'Connecting to mongodb');

    try {
      var settings = _composeSettings();

      settings['useNewUrlParser'] = true;
      settings['useUnifiedTopology'] = true;

      connection = mongo.Db(uri);
      await connection.open();
      if (settings['userName'] != null) {
        await connection.authenticate(
            settings['userName'], settings['password']);
      }

      databaseName = connection.databaseName;
    } catch (ex) {
      throw ConnectionException(
              correlationId, 'CONNECT_FAILED', 'Connection to mongodb failed')
          .withCause(ex);
    }
  }

  /// Closes component and frees used resources.
  ///
  /// - correlationId 	(optional) transaction id to trace execution through call chain.
  /// Return 			      Future that receives null no errors occured.
  /// Throws error
  @override
  Future close(String correlationId) async {
    if (connection == null) {
      return null;
    }
    try {
      await connection.close();
      connection = null;
      databaseName = null;
      logger.debug(correlationId, 'Disconnected from mongodb database %s',
          [databaseName]);
    } catch (err) {
      throw ConnectionException(correlationId, 'DISCONNECT_FAILED',
              'Disconnect from mongodb failed: ')
          .withCause(err);
    }
  }

  //Returns used DB connection object
  dynamic getConnection() {
    return connection;
  }

  // Return used database name
  String getDatabaseName() {
    return databaseName;
  }
}
