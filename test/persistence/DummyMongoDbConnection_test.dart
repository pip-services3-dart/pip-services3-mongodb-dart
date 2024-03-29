import 'dart:io';
import 'package:test/test.dart';
import 'package:pip_services3_commons/pip_services3_commons.dart';
import 'package:pip_services3_mongodb/pip_services3_mongodb.dart';
import '../fixtures/DummyPersistenceFixture.dart';
import 'DummyMongoDbPersistence.dart';

void main() {
  group('DummyMongoDbConnection', () {
    late MongoDbConnection connection;
    late DummyMongoDbPersistence persistence;
    late DummyPersistenceFixture fixture;

    var mongoUri = Platform.environment['MONGO_SERVICE_URI']; // ??
    // 'mongodb://localhost:27017/test'; //'mongodb://pip:nyjgJO4Gt4F5l2On@pip-vault-us1-1-shard-00-01-venqt.mongodb.net:27017/piplife';
    var mongoHost = Platform.environment['MONGO_SERVICE_HOST'] ?? 'localhost';

    /// ,pip-vault-us1-1-shard-00-01-venqt.mongodb.net:27017,pip-vault-us1-1-shard-00-02-venqt.mongodb.net:27017
    var mongoPort = Platform.environment['MONGO_SERVICE_PORT'] ?? '27017';
    var mongoDatabase = Platform.environment['MONGO_DB'] ?? 'test';
    if (mongoUri == null && mongoHost == null) {
      return;
    }

    setUp(() async {
      var dbConfig = ConfigParams.fromTuples([
        'connection.uri',
        mongoUri,
        'connection.host',
        mongoHost,
        'connection.port',
        mongoPort,
        'connection.database',
        mongoDatabase
      ]);

      connection = MongoDbConnection();
      connection.configure(dbConfig);

      persistence = DummyMongoDbPersistence();
      persistence.setReferences(References.fromTuples([
        Descriptor('pip-services', 'connection', 'mongodb', 'default', '1.0'),
        connection
      ]));

      fixture = DummyPersistenceFixture(persistence);

      await connection.open(null);
      await persistence.open(null);
      await persistence.clear(null);
    });

    tearDown(() async {
      await persistence.close(null);
      await connection.close(null);
    });

    test('Crud Operations', () async {
      await fixture.testCrudOperations();
    });

    test('Batch Operations', () async {
      await fixture.testBatchOperations();
    });
  });
}
