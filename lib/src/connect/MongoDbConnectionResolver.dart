import 'dart:async';

import 'package:pip_services3_commons/pip_services3_commons.dart';
import 'package:pip_services3_components/pip_services3_components.dart';

/// Helper class that resolves MongoDB connection and credential parameters,
/// validates them and generates a connection URI.
///
/// It is able to process multiple connections to MongoDB cluster nodes.
///
///  ### Configuration parameters ###
///
/// - [connection(s)]:
///   - [discovery_key]:               (optional) a key to retrieve the connection from [IDiscovery](https://pub.dev/documentation/pip_services3_components/latest/pip_services3_components/IDiscovery-class.html)
///   - [host]:                        host name or IP address
///   - [port]:                        port number (default: 27017)
///   - [database]:                    database name
///   - [uri]:                         resource URI or connection string with all parameters in it
/// - [credential(s)]:
///   - [store_key]:                   (optional) a key to retrieve the credentials from [ICredentialStore](https://pub.dev/documentation/pip_services3_components/latest/pip_services3_components/ICredentialStore-class.html)
///   - [username]:                    user name
///   - [password]:                    user password
///
/// ### References ###
///
/// - \*:discovery:\*:\*:1.0             (optional) [IDiscovery](https://pub.dev/documentation/pip_services3_components/latest/pip_services3_components/IDiscovery-class.html) services
/// - \*:credential-store:\*:\*:1.0      (optional) Credential stores to resolve credentials

class MongoDbConnectionResolver implements IReferenceable, IConfigurable {
  /// The connections resolver.
  ConnectionResolver connectionResolver = ConnectionResolver();

  /// The credentials resolver.
  CredentialResolver credentialResolver = CredentialResolver();

  /// Configures component by passing configuration parameters.
  ///
  /// - [config]    configuration parameters to be set.
  @override
  void configure(ConfigParams config) {
    connectionResolver.configure(config);
    credentialResolver.configure(config);
  }

  /// Sets references to dependent components.
  ///
  /// - [references] 	references to locate the component dependencies.
  @override
  void setReferences(IReferences references) {
    connectionResolver.setReferences(references);
    credentialResolver.setReferences(references);
  }

  dynamic _validateConnection(
      String? correlationId, ConnectionParams connection) {
    var uri = connection.getUri();
    if (uri != null) return null;

    var host = connection.getHost();
    if (host == null) {
      return ConfigException(
          correlationId, 'NO_HOST', 'Connection host is not set');
    }

    var port = connection.getPort();
    if (port == 0) {
      return ConfigException(
          correlationId, 'NO_PORT', 'Connection port is not set');
    }

    var database = connection.getAsNullableString('database');
    if (database == null) {
      return ConfigException(
          correlationId, 'NO_DATABASE', 'Connection database is not set');
    }

    return null;
  }

  dynamic _validateConnections(
      String? correlationId, List<ConnectionParams>? connections) {
    if (connections == null || connections.isEmpty) {
      return ConfigException(
          correlationId, 'NO_CONNECTION', 'Database connection is not set');
    }

    for (var connection in connections) {
      var error = _validateConnection(correlationId, connection);
      if (error != null) return error;
    }

    return null;
  }

  String _composeUri(
      List<ConnectionParams> connections, CredentialParams? credential) {
    // If there is a uri then return it immediately
    for (var connection in connections) {
      var uri = connection.getUri();
      if (uri != null) return uri;
    }

    // Define hosts
    var hosts = '';
    for (var connection in connections) {
      var host = connection.getHost();
      var port = connection.getPort();

      if (hosts.isNotEmpty) {
        hosts += ',';
      }
      hosts += (host ?? '') + (port == null ? '' : ':' + port.toString());
    }

    // Define database
    var database;
    for (var connection in connections) {
      database = database ?? connection.getAsNullableString('database');
    }
    if (database.isNotEmpty) {
      database = '/' + database;
    }

    // Define authentication part
    var auth = '';
    if (credential != null) {
      var username = credential.getUsername();
      if (username != null) {
        var password = credential.getPassword();
        if (password != null) {
          auth = username + ':' + password + '@';
        } else {
          auth = username + '@';
        }
      }
    }

    // Define additional parameters parameters
    var options = ConfigParams.mergeConfigs(connections)
        .override(credential ?? CredentialParams());
    options.remove('uri');
    options.remove('host');
    options.remove('port');
    options.remove('database');
    options.remove('username');
    options.remove('password');
    var params = '';
    var keys = options.getKeys();
    for (var key in keys) {
      if (params.isNotEmpty) {
        params += '&';
      }

      params += key;

      var value = options.getAsNullableString(key);
      if (value != null) {
        params += '=' + value;
      }
    }
    if (params.isNotEmpty) {
      params = '?' + params;
    }

    // Compose uri
    var uri = 'mongodb://' + auth + hosts + database + params;

    return uri;
  }

  /// Resolves MongoDB connection URI from connection and credential parameters.
  ///
  /// - [correlationId]     (optional) transaction id to trace execution through call chain.
  /// Return 			Future that receives resolved URI
  /// Throw error.
  Future<String> resolve(String? correlationId) async {
    var connections = <ConnectionParams>[];
    CredentialParams? credential;

    Future<dynamic> Function() resolv = () async {
      connections = await connectionResolver.resolveAll(correlationId);
      // Validate connections
      var err = _validateConnections(correlationId, connections);
      if (err != null) {
        throw err;
      }
    };

    Future<dynamic> Function() lookup = () async {
      credential = await credentialResolver.lookup(correlationId);
      // Credentials are not validated right now
    };

    return await Future.wait([resolv(), lookup()]).then((list) {
      return _composeUri(connections, credential);
    });
  }
}
