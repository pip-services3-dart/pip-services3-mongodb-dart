// let process = require('process');

// import { ConfigParams, ConnectionException } from 'pip-services3-commons-node';
// import { Descriptor } from 'pip-services3-commons-node';
// import { References } from 'pip-services3-commons-node';
// import { MongoDbConnection } from '../../src/persistence/MongoDbConnection';
// import { DummyPersistenceFixture } from '../fixtures/DummyPersistenceFixture';
// import { DummyMongoDbPersistence } from './DummyMongoDbPersistence';

// suite('DummyMongoDbConnection', ()=> {
//     let connection: MongoDbConnection;
//     let persistence: DummyMongoDbPersistence;
//     let fixture: DummyPersistenceFixture;

//     let mongoUri = process.env['MONGO_URI'];
//     let mongoHost = process.env['MONGO_HOST'] || 'localhost';
//     let mongoPort = process.env['MONGO_PORT'] || 27017;
//     let mongoDatabase = process.env['MONGO_DB'] || 'test';
//     if (mongoUri == null && mongoHost == null)
//         return;

//     setup((done) => {
//         let dbConfig = ConfigParams.fromTuples(
//             'connection.uri', mongoUri,
//             'connection.host', mongoHost,
//             'connection.port', mongoPort,
//             'connection.database', mongoDatabase
//         );

//         connection = new MongoDbConnection();
//         connection.configure(dbConfig);

//         persistence = new DummyMongoDbPersistence();
//         persistence.setReferences(References.fromTuples(
//             new Descriptor("pip-services", "connection", "mongodb", "default", "1.0"), connection
//         ));

//         fixture = new DummyPersistenceFixture(persistence);

//         connection.open(null, (err: any) => {
//             if (err) {
//                 done(err);
//                 return;
//             }

//             persistence.open(null, (err: any) => {
//                 if (err) {
//                     done(err);
//                     return;
//                 }
    
//                 persistence.clear(null, (err) => {
//                     done(err);
//                 });
//             });
//         });
//     });

//     teardown((done) => {
//         connection.close(null, (err) => {
//             persistence.close(null, done);
//         });
//     });

//     test('Crud Operations', (done) => {
//         fixture.testCrudOperations(done);
//     });

//     test('Batch Operations', (done) => {
//         fixture.testBatchOperations(done);
//     });
// });