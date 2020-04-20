import 'dart:io';
import 'package:test/test.dart';
import 'package:pip_services3_commons/pip_services3_commons.dart';
import '../fixtures/DummyPersistenceFixture.dart';
import './DummyMongoDbPersistence.dart';

void main() {
  group('DummyMongoDbPersistence', () {
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

      persistence = DummyMongoDbPersistence();
      persistence.configure(dbConfig);
      fixture = DummyPersistenceFixture(persistence);
      await persistence.open(null);
      await persistence.clear(null);
    });

    tearDown(() async {
      await persistence.close(null);
    });

    test('Crud Operations', () async {
      await fixture.testCrudOperations();
    });

    test('Batch Operations', () async{
      await fixture.testBatchOperations();
    });
  });
}
