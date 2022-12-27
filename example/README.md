# Examples for MongoDB persistence

This component library is a part of the [Pip.Services](https://github.com/pip-services/pip-services) project.
It contains the following MongoDB components: 
 
 - **MongoDbConnectionResolver**
  * Example:
 ```dart 
  class Test {
  var connectionResolver = MongoDbConnectionResolver();

  @override
  void configure(ConfigParams config) {
    connectionResolver.configure(config);
    ...
  }

   @override
  void setReferences(IReferences references) {
    connectionResolver.setReferences(references);
    ...
  }

   @override
  Future open(String correlationId) async {
    String uri;
    try {
      uri = await connectionResolver.resolve(correlationId);
    } catch (err) {
      logger.error(correlationId, ApplicationException().wrap(err),
          'Failed to resolve MongoDb connection');
    }
    ...
  }
}
```

 - **MongoDbConnection**

 * Example:
 ```dart
    MongoDbConnection connection;

    var mongoUri = Platform.environment['MONGO_URI'];
    var mongoHost = Platform.environment['MONGO_HOST'] ?? 'localhost';
    var mongoPort = Platform.environment['MONGO_PORT'] ?? '27017';
    var mongoDatabase = Platform.environment['MONGO_DB'] ?? 'test';
   
      var dbConfig = ConfigParams.fromTuples([
        'connection.uri',  mongoUri,
        'connection.host', mongoHost,
        'connection.port', mongoPort,
        'connection.database', mongoDatabase
      ]);

      connection = MongoDbConnection();
      connection.configure(dbConfig);

      await connection.open(null);
 ```

 - **MongoDbPersistence**
 * Example:

```dart
     class MyMongoDbPersistence extends MongoDbPersistence<MyData> {

       MyMongoDbPersistence():base('mydata');

       Future<MyData> getByName(String correlationId, String name) {
           var filter = {'name': name};
           var query = mngquery.SelectorBuilder();
           var selector = <String, dynamic>{};
           selector[r'$query'] = filter;
           query.raw(selector);
           var item = await collection.findOne(filter);
           if (item == null) {
             return null;
           }
           item = convertToPublic(item);
           var instance = MyData.fromJson(item);
           return instance;
       });

       Future<MyData> set(String correlatonId, MyData item) {
         if (item == null) {
           return null;
         }
         var jsonMap = json.decode(json.encode(item));
         // Assign unique id
         if (jsonMap['id'] == null) {
           jsonMap['id'] = IdGenerator.nextLong();
         }
         convertFromPublic(jsonMap);
         var filter = {r'$query': {'name': jsonMap['name']}};
         var result = await collection.findAndModify(
             query: filter, update: jsonMap, returnNew: true, upsert: true);
         if (result != null) {
             convertToPublic(result);
             var newItem = MyData.fromJson(result);;  
             return newItem;
         }
         return null;
       }

     }

     var persistence = MyMongoDbPersistence();
     persistence.configure(ConfigParams.fromTuples([
         'host', 'localhost',
         'port', 27017
     ]));

     await persitence.open('123');

     await persistence.set('123', { name: 'ABC' });
     var item = await persistence.getByName('123', 'ABC'); 
     print(item);         // Result: { name: 'ABC' }
```

 - **IdentifiableMongoDbPersistence**

* Example:
```dart
     class MyMongoDbPersistence extends MongoDbPersistence<MyData, String> {

     MyMongoDbPersistence(): base('mydata', new MyDataMongoDbSchema());

     dynamic _composeFilter(FilterParams) {
         filter = filter ?? new FilterParams();
         var criteria = [];
         var name = filter.getAsNullableString('name');
         if (name != null)
             criteria.add({'name': name });
         return criteria.isNotNul ? {r'$and': criteria } : null;
     }

     Future<DataPage<MyData>> getPageByFilter(String correlationId, FilterParams filter, PagingParams paging) async {
         return base.getPageByFilter(correlationId, _composeFilter(filter), paging, null);
     }

     }

     var persistence = MyMongoDbPersistence();
     persistence.configure(ConfigParams.fromTuples([
         'host', 'localhost',
         'port', 27017
     ]));

     await persitence.open('123');

     var item = await persistence.create('123', { 'id': '1', 'name': 'ABC' });
     var page = await persistence.getPageByFilter('123', FilterParams.fromTuples(['name', 'ABC']), null);
             
     print(page.data);          // Result: { id: '1', name: 'ABC' }

     item = await persistence.deleteById('123', '1'); 
```

In the help for each class there is a general example of its use. Also one of the quality sources
are the source code for the [**tests**](https://github.com/pip-services3-dart/pip-services3-mongodb-dart/tree/master/test).

