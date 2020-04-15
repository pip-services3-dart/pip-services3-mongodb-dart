// let process = require('process');

// import { ConfigParams } from 'pip-services3-commons-node';
// import { DummyPersistenceFixture } from '../fixtures/DummyPersistenceFixture';
// import { DummyMongoDbPersistence } from './DummyMongoDbPersistence';

// suite('DummyMongoDbPersistence', ()=> {
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

//         persistence = new DummyMongoDbPersistence();
//         persistence.configure(dbConfig);

//         fixture = new DummyPersistenceFixture(persistence);

//         persistence.open(null, (err: any) => {
//             if (err) {
//                 done(err);
//                 return;
//             }

//             persistence.clear(null, (err) => {
//                 done(err);
//             });
//         });
//     });

//     teardown((done) => {
//         persistence.close(null, done);
//     });

//     test('Crud Operations', (done) => {
//         fixture.testCrudOperations(done);
//     });

//     test('Batch Operations', (done) => {
//         fixture.testBatchOperations(done);
//     });
// });