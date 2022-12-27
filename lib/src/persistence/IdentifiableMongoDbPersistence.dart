import 'dart:async';

import 'package:pip_services3_commons/pip_services3_commons.dart';
import 'package:pip_services3_data/pip_services3_data.dart';
import './MongoDbPersistence.dart';
import 'package:mongo_dart_query/mongo_dart_query.dart' as mngquery;

/// Abstract persistence component that stores data in MongoDB
/// and implements a number of CRUD operations over data items with unique ids.
/// The data items must implement IIdentifiable interface.
///
/// In basic scenarios child classes shall only override [getPageByFilter],
/// [getListByFilter] or [deleteByFilter] operations with specific filter function.
/// All other operations can be used out of the box.
///
/// In complex scenarios child classes can implement additional operations by
/// accessing this._collection and this._model properties.

/// ### Configuration parameters ###
///
/// - [collection]:                  (optional) MongoDB collection name
/// - [connection(s)]:
///   - [discovery_key]:             (optional) a key to retrieve the connection from [IDiscovery](https://pub.dev/documentation/pip_services3_components/latest/pip_services3_components/IDiscovery-class.html)
///   - [host]:                      host name or IP address
///   - [port]:                      port number (default: 27017)
///   - [uri]:                       resource URI or connection string with all parameters in it
/// - [credential(s)]:
///   - [store_key]:                 (optional) a key to retrieve the credentials from [ICredentialStore](https://pub.dev/documentation/pip_services3_components/latest/pip_services3_components/ICredentialStore-class.html)
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
///   - [auth_user]:                 (optional) authentication user name
///   - [auth_password]:             (optional) authentication user password
///   - [debug]:                     (optional) enable debug output (default: false).
///
/// ### References ###
///
/// - \*:logger:\*:\*:1.0           (optional) [ILogger](https://pub.dev/documentation/pip_services3_components/latest/pip_services3_components/ILogger-class.html) components to pass log messages components to pass log messages
/// - \*:discovery:\*:\*:1.0        (optional) [IDiscovery](https://pub.dev/documentation/pip_services3_components/latest/pip_services3_components/IDiscovery-class.html) services
/// - \*:credential-store:\*:\*:1.0 (optional) Credential stores to resolve credentials
///
/// ### Example ###
///
///     class MyMongoDbPersistence extends MongoDbPersistence<MyData, String> {
///
///     MyMongoDbPersistence(): base('mydata', new MyDataMongoDbSchema());
///
///     dynamic _composeFilter(FilterParams) {
///         filter = filter ?? new FilterParams();
///         var criteria = [];
///         var name = filter.getAsNullableString('name');
///         if (name != null)
///             criteria.add({'name': name });
///         return criteria.isNotNul ? {r'$and': criteria } : null;
///     }
///
///     Future<DataPage<MyData>> getPageByFilter(String? correlationId, FilterParams filter, PagingParams paging) async {
///         return base.getPageByFilter(correlationId, _composeFilter(filter), paging, null);
///     }
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
///     var item = await persistence.create('123', { 'id': '1', 'name': 'ABC' });
///     var page = await persistence.getPageByFilter('123', FilterParams.fromTuples(['name', 'ABC']), null);
///
///     print(page.data);          // Result: { id: '1', name: 'ABC' }
///
///     item = await persistence.deleteById('123', '1');

class IdentifiableMongoDbPersistence<T extends IIdentifiable<K>, K>
    extends MongoDbPersistence<T>
    implements IWriter<T, K>, IGetter<T, K>, ISetter<T> {
  /// Creates a new instance of the persistence component.
  ///
  /// - [collection]    (optional) a collection name.
  IdentifiableMongoDbPersistence(String? collection) : super(collection) {
    if (collection == null) {
      throw Exception('Collection name could not be null');
    }
  }

  /// Configures component by passing configuration parameters.
  ///
  /// - [config]    configuration parameters to be set.
  @override
  void configure(ConfigParams config) {
    super.configure(config);
    maxPageSize =
        config.getAsIntegerWithDefault('options.max_page_size', maxPageSize);
  }

  /// Gets a list of data items retrieved by given unique ids.
  ///
  /// - [correlationId]     (optional) transaction id to trace execution through call chain.
  /// - [ids]               ids of data items to be retrieved
  /// Return         Future that receives a data list
  /// Throws error.
  Future<List<T>> getListByIds(String? correlationId, List<K> ids) async {
    var filter = {
      '_id': {r'$in': ids}
    };
    return getListByFilterEx(correlationId, filter, null);
  }

  /// Gets a data item by its unique id.
  ///
  /// - [correlationId]     (optional) transaction id to trace execution through call chain.
  /// - [id]                an id of data item to be retrieved.
  /// Return          Future that receives data item
  /// Throws error.
  @override
  Future<T?> getOneById(String? correlationId, K? id) async {
    var filter = {'_id': id};
    var query = mngquery.SelectorBuilder();
    var selector = <String, dynamic>{};
    selector[r'$query'] = filter;

    var item = await collection?.findOne(query.raw(selector));
    if (item == null) {
      logger.trace(correlationId, 'Nothing found from %s with id = %s',
          [collectionName, id]);
      return null;
    }
    logger.trace(
        correlationId, 'Retrieved from %s with id = %s', [collectionName, id]);

    return convertToPublic(item);
  }

  /// Creates a data item.
  ///
  /// - [correlation_id]    (optional) transaction id to trace execution through call chain.
  /// - [item]              an item to be created.
  /// Return                Future that receives created item
  /// Throws error.
  @override
  Future<T?> create(String? correlationId, T? item) async {
    if (item == null) {
      return null;
    }
    var jsonMap = convertFromPublic(item, createUid: true);
    var result = jsonMap != null ? await collection?.insert(jsonMap) : null;
    if (result != null && result['ok'] == 1.0) {
      logger.trace(correlationId, 'Created in %s with id = %s',
          [collectionName, jsonMap!['_id']]);

      return convertToPublic(jsonMap);
    }
    return null;
  }

  /// Sets a data item. If the data item exists it updates it,
  /// otherwise it create a new data item.
  ///
  /// - [correlation_id]    (optional) transaction id to trace execution through call chain.
  /// - [item]              a item to be set.
  /// Return                Future that receives updated item
  /// Throws error.
  @override
  Future<T?> set(String? correlationId, T? item) async {
    if (item == null) {
      return null;
    }
    var jsonMap = convertFromPublic(item, createUid: true);
    var query = {'_id': item.id};
    var update = {r'$set': jsonMap};

    // Bug with ObjectId when returnNew true
    // var result = await collection?.findAndModify(
    //     query: query, update: update, returnNew: true, upsert: true);

    var result = await collection?.updateOne(query, update, upsert: true);

    if (result != null && result.ok == 1.0) {
      logger.trace(
          correlationId, 'Set in %s with id = %s', [collectionName, item.id]);
      return item; // convertToPublic(result);
    }
    // if (result != null) {

    // }
    return null;
  }

  /// Updates a data item.
  ///
  /// - [correlation_id]    (optional) transaction id to trace execution through call chain.
  /// - [item]              an item to be updated.
  /// Return                Future that receives updated item
  /// Throws error.
  @override
  Future<T?> update(String? correlationId, T? item) async {
    if (item == null || item.id == null) {
      return null;
    }

    var jsonMap = convertFromPublic(item, createUid: false);
    jsonMap?.remove('_id');
    var filter = {'_id': item.id};
    var update = {r'$set': jsonMap};
    var result = await collection?.findAndModify(
        query: filter, update: update, returnNew: true, upsert: false);

    if (result != null) {
      logger.trace(correlationId, 'Updated in %s with id = %s',
          [collectionName, item.id]);

      return convertToPublic(result);
    }
    return null;
  }

  /// Updates only few selected fields in a data item.
  ///
  /// - [correlation_id]    (optional) transaction id to trace execution through call chain.
  /// - [id]                an id of data item to be updated.
  /// - [data]              a map with fields to be updated.
  /// Return                Future that receives updated item
  /// Throws error.
  Future<T?> updatePartially(
      String? correlationId, K? id, AnyValueMap? data) async {
    if (data == null || id == null) {
      return null;
    }

    var newItem = data.innerValue();
    newItem = convertFromPublicPartial(
        newItem != null ? Map<String, dynamic>.from(newItem) : null);
    var filter = {'_id': id};
    var update = {r'$set': newItem};
    var result = await collection?.update(filter, update);
    if (result != null && result['ok'] == 1.0) {
      logger.trace(correlationId, 'Updated partially in %s with id = %s',
          [collectionName, id]);

      return await getOneById(correlationId, id);
    }
    return null;
  }

  /// Deleted a data item by it's unique id.
  ///
  /// - [correlation_id]    (optional) transaction id to trace execution through call chain.
  /// - [id]                an id of the item to be deleted
  /// Return                Future that receives deleted item
  /// Thhrows error.
  @override
  Future<T?> deleteById(String? correlationId, K? id) async {
    var filter = {'_id': id};

    var oldItem = await getOneById(correlationId, id);
    var result = await collection?.remove(filter);
    if (result != null && result['ok'] == 1.0) {
      logger.trace(
          correlationId, 'Deleted from %s with id = %s', [collectionName, id]);

      return oldItem;
    }
    return null;
  }

  /// Deletes multiple data items by their unique ids.
  ///
  /// - [correlationId]     (optional) transaction id to trace execution through call chain.
  /// - [ids]               ids of data items to be deleted.
  /// Return                Future that receives null for success.
  /// Throws error
  Future deleteByIds(String? correlationId, List<K> ids) async {
    var filter = {
      '_id': {r'$in': ids}
    };
    return deleteByFilterEx(correlationId, filter);
  }
}
