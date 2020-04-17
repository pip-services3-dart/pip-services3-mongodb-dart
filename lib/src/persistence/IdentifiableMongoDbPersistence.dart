import 'dart:async';
import 'dart:convert';

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
///   - [discovery_key]:             (optional) a key to retrieve the connection from [IDiscovery]]
///   - [host]:                      host name or IP address
///   - [port]:                      port number (default: 27017)
///   - [uri]:                       resource URI or connection string with all parameters in it
/// - [credential(s)]:
///   - [store_key]:                 (optional) a key to retrieve the credentials from [ICredentialStore]]
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
/// - \*:logger:\*:\*:1.0           (optional) [ILogger]] components to pass log messages components to pass log messages
/// - \*:discovery:\*:\*:1.0        (optional) [IDiscovery]] services
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
///     Future<DataPage<MyData>> getPageByFilter(String correlationId, FilterParams filter, PagingParams paging) async {
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
    extends MongoDbPersistence
    implements IWriter<T, K>, IGetter<T, K>, ISetter<T> {
  var maxPageSize = 100;

  /// Creates a new instance of the persistence component.
  ///
  /// - [collection]    (optional) a collection name.
  IdentifiableMongoDbPersistence(String collection) : super(collection) {
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

  /// Converts the given object from the public partial format.
  ///
  /// - [value]     the object to convert from the public partial format.
  /// Returns the initial object.
  dynamic convertFromPublicPartial(value) {
    return convertFromPublic(value);
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
      String correlationId, filter, PagingParams paging, sort) async {
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
    selector[r'$query'] = filter;
    selector['orderby'] = sort;
    query.raw(selector);
    var items = <T>[];
    await collection.find(query).forEach((item) {
      item = convertToPublic(item);
      var instance = TypeReflector.createInstanceByType(T, []);
      instance.fromJson(item);
      items.add(instance);
    });
    logger.trace(
        correlationId, 'Retrieved %d from %s', [items.length, collectionName]);
    if (pagingEnabled) {
      var count = await collection.count(selector);
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
  Future<List<T>> getListByFilterEx(String correlationId, filter, sort) async {
    // Configure options
    var query = mngquery.SelectorBuilder();
    var selector = <String, dynamic>{};
    selector[r'$query'] = filter;
    selector['orderby'] = sort;
    query.raw(selector);
    var items = <T>[];

    await collection.find(query).forEach((item) {
      item = convertToPublic(item);
      var instance = TypeReflector.createInstanceByType(T, []);
      instance.fromJson(item);
      items.add(instance);
    });
    logger.trace(
        correlationId, 'Retrieved %d from %s', [items.length, collectionName]);
    return items;
  }

  /// Gets a list of data items retrieved by given unique ids.
  ///
  /// - [correlationId]     (optional) transaction id to trace execution through call chain.
  /// - [ids]               ids of data items to be retrieved
  /// Return         Future that receives a data list
  /// Throws error.
  Future<List<T>> getListByIds(String correlationId, List<K> ids) async {
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
  Future<T> getOneById(String correlationId, K id) async {
    var filter = {'_id': id};
    var query = mngquery.SelectorBuilder();
    var selector = <String, dynamic>{};
    selector[r'$query'] = filter;
    query.raw(selector);

    var item = await collection.findOne(filter);

    if (item == null) {
      logger.trace(correlationId, 'Nothing found from %s with id = %s',
          [collectionName, id]);
      return null;
    }
    logger.trace(
        correlationId, 'Retrieved from %s with id = %s', [collectionName, id]);
    item = convertToPublic(item);
    var instance = TypeReflector.createInstanceByType(T, []);
    instance.fromJson(item);
    return instance;
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
  Future<T> getOneRandom(String correlationId, filter) async {
    var query = mngquery.SelectorBuilder();
    var selector = <String, dynamic>{};
    selector[r'$query'] = filter;
    var count = await collection.count(query);
    var pos = RandomInteger.nextInteger(0, count - 1);
    query.skip(pos >= 0 ? pos : 0);
    query.limit(1);
    query.raw(selector);
    var items = await collection.find(query);
    try {
      var item = (items != null) ? await items.single : null;
      item = convertToPublic(item);
      var instance = TypeReflector.createInstanceByType(T, []);
      instance.fromJson(item);
      return instance;
    } catch (ex) {
      return null;
    }
  }

  /// Creates a data item.
  ///
  /// - [correlation_id]    (optional) transaction id to trace execution through call chain.
  /// - [item]              an item to be created.
  /// Return                Future that receives created item
  /// Throws error.
  @override
  Future<T> create(String correlationId, T item) async {
    if (item == null) {
      return null;
    }

    var jsonMap = json.decode(json.encode(item));
    // Assign unique id
    if (jsonMap['id'] == null) {
      jsonMap['id'] = IdGenerator.nextLong();
    }
    convertFromPublic(jsonMap);

    var result = await collection.insert(jsonMap);
    if (result != null) {
      logger.trace(correlationId, 'Created in %s with id = %s',
          [collectionName, result['_id']]);

      convertToPublic(result);
      var newItem = TypeReflector.createInstanceByType(T, []);
      newItem.fromJson(result);
      return newItem;
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
  Future<T> set(String correlationId, T item) async {
    if (item == null) {
      return null;
    }

    var jsonMap = json.decode(json.encode(item));
    // Assign unique id
    if (jsonMap['id'] == null) {
      jsonMap['id'] = IdGenerator.nextLong();
    }
    convertFromPublic(jsonMap);

    var filter = {
      r'$query': {'_id': jsonMap['_id']}
    };

    var result = await collection.findAndModify(
        query: filter, update: jsonMap, returnNew: true, upsert: true);
    if (result != null) {
      logger.trace(
          correlationId, 'Set in %s with id = %s', [collectionName, item.id]);

      convertToPublic(result);
      var newItem = TypeReflector.createInstanceByType(T, []);
      newItem.fromJson(result);
      return newItem;
    }
    return null;
  }

  /// Updates a data item.
  ///
  /// - [correlation_id]    (optional) transaction id to trace execution through call chain.
  /// - [item]              an item to be updated.
  /// Return                Future that receives updated item
  /// Throws error.
  @override
  Future<T> update(String correlationId, T item) async {
    if (item == null || item.id == null) {
      return null;
    }

    var jsonMap = json.decode(json.encode(item));
    jsonMap.remove('id');
    convertFromPublic(jsonMap);

    var filter = {
      r'$query': {'_id': item.id}
    };
    var update = {r'$set': jsonMap};

    var result = await collection.findAndModify(
        query: filter, update: update, returnNew: true, upsert: false);

    if (result != null) {
      logger.trace(correlationId, 'Updated in %s with id = %s',
          [collectionName, item.id]);

      convertToPublic(result);
      var newItem = TypeReflector.createInstanceByType(T, []);
      newItem.fromJson(result);
      return newItem;
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
  Future<T> updatePartially(
      String correlationId, K id, AnyValueMap data) async {
    if (data == null || id == null) {
      return null;
    }

    var newItem = data.innerValue();
    newItem = convertFromPublicPartial(newItem);
    var filter = {
      r'$query': {'_id': id}
    };
    var update = {r'$set': newItem};
    var result = await collection.update(filter, update);
    if (result != null) {
      logger.trace(correlationId, 'Updated partially in %s with id = %s',
          [collectionName, id]);

      convertToPublic(result);
      var newItem = TypeReflector.createInstanceByType(T, []);
      newItem.fromJson(result);
      return newItem;
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
  Future<T> deleteById(String correlationId, K id) async {
    var filter = {
      r'$query': {'_id': id}
    };

    var result = await collection.remove(filter);
    if (result != null) {
      logger.trace(
          correlationId, 'Deleted from %s with id = %s', [collectionName, id]);

      convertToPublic(result);
      var newItem = TypeReflector.createInstanceByType(T, []);
      newItem.fromJson(result);
      return newItem;
    }
    return null;
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
  Future deleteByFilter(String correlationId, filter) async {
    var removeFilter = {r'$query': filter};
    var result = await collection.remove(removeFilter);
    var count = result != null ? result.length : 0;
    logger.trace(
        correlationId, 'Deleted %d items from %s', [count, collectionName]);
  }

  /// Deletes multiple data items by their unique ids.
  ///
  /// - [correlationId]     (optional) transaction id to trace execution through call chain.
  /// - [ids]               ids of data items to be deleted.
  /// Return                Future that receives null for success.
  /// Throws error
  Future deleteByIds(String correlationId, List<K> ids) async {
    var filter = {
      r'$query': {
        '_id': {r'$in': ids}
      }
    };
    return deleteByFilter(correlationId, filter);
  }
}
