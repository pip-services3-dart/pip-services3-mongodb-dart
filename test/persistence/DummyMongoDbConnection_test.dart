import 'dart:io';
import 'package:test/test.dart';
import 'package:pip_services3_commons/pip_services3_commons.dart';
import 'package:pip_services3_mongodb/pip_services3_mongodb.dart';
import '../fixtures/DummyPersistenceFixture.dart';
import './DummyMongoDbPersistence.dart';

void main() {
  group('DummyMongoDbConnection', () {
    MongoDbConnection connection;
    DummyMongoDbPersistence persistence;
    DummyPersistenceFixture fixture;

    var mongoUri = Platform.environment['MONGO_URI'];
    var mongoHost = Platform.environment['MONGO_HOST'] ?? 'localhost';
    var mongoPort = Platform.environment['MONGO_PORT'] ?? '27017';
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
