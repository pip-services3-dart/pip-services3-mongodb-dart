// var assert = require('chai').assert;
// var async = require('async');

// import { AnyValueMap } from 'pip-services3-commons-node';
// import { Dummy } from './Dummy';
// import { IDummyPersistence } from './IDummyPersistence';

// export class DummyPersistenceFixture {
//     private _dummy1: Dummy = { id: null, key: "Key 1", content: "Content 1"};
//     private _dummy2: Dummy = { id: null, key: "Key 2", content: "Content 2"};

//     private _persistence: IDummyPersistence;

//     public constructor(persistence: IDummyPersistence) {
//         this._persistence = persistence;
//     }

//     public testCrudOperations(callback: (err: any) => void): void {
//         let dummy1: Dummy;
//         let dummy2: Dummy;

//         async.series([
//             (callback) => {
//                 // Create one dummy
//                 this._persistence.create(null, this._dummy1, (err: any, result: Dummy) => {
//                     dummy1 = result;
//                     assert.isNotNull(dummy1);
//                     assert.isNotNull(dummy1.id);
//                     assert.equal(this._dummy1.key, dummy1.key);
//                     assert.equal(this._dummy1.content, dummy1.content);

//                     callback(err);
//                 });
//             },
//             (callback) => {
//                 // Create another dummy
//                 this._persistence.create(null, this._dummy2, (err: any, result: Dummy) => {
//                     dummy2 = result;
//                     assert.isNotNull(dummy2);
//                     assert.isNotNull(dummy2.id);
//                     assert.equal(this._dummy2.key, dummy2.key);
//                     assert.equal(this._dummy2.content, dummy2.content);

//                     callback(err);
//                 });
//             },
//             (callback) => {
//                 this._persistence.getPageByFilter(null, null, null, (err, page) => {
//                     assert.isNotNull(page);
//                     assert.lengthOf(page.data, 2);

//                     callback(err);
//                 });
//             },
//             (callback) => {
//                 // Update the dummy
//                 dummy1.content = "Updated Content 1";
//                 this._persistence.update(null, dummy1, (err: any, result: Dummy) => {
//                     assert.isNotNull(result);
//                     assert.equal(dummy1.id, result.id);
//                     assert.equal(dummy1.key, result.key);
//                     assert.equal(dummy1.content, result.content);

//                     callback(err);
//                 });
//             },
//             (callback) => {
//                 // Partially update the dummy
//                 this._persistence.updatePartially(
//                     null, dummy1.id,  
//                     AnyValueMap.fromTuples(
//                         'content', 'Partially Updated Content 1'
//                     ),
//                     (err: any, result: Dummy) => {
//                         assert.isNotNull(result);
//                         assert.equal(dummy1.id, result.id);
//                         assert.equal(dummy1.key, result.key);
//                         assert.equal('Partially Updated Content 1', result.content);

//                         callback(err);
//                     }
//                 );
//             },
//             (callback) => {
//                 // Get the dummy by Id
//                 this._persistence.getOneById(null, dummy1.id, (err: any, result: Dummy) => {
//                     // Try to get item
//                     assert.isNotNull(result);
//                     assert.equal(dummy1.id, result.id);
//                     assert.equal(dummy1.key, result.key);
//                     assert.equal('Partially Updated Content 1', result.content);

//                     callback(err);
//                 });
//             },
//             (callback) => {
//                 // Delete the dummy
//                 this._persistence.deleteById(null, dummy1.id, (err: any, result: Dummy) => {
//                     assert.isNotNull(result);
//                     assert.equal(dummy1.id, result.id);
//                     assert.equal(dummy1.key, result.key);
//                     assert.equal('Partially Updated Content 1', result.content);

//                     callback(err);
//                 });
//             },
//             (callback) => {
//                 // Get the deleted dummy
//                 this._persistence.getOneById(null, dummy1.id, (err: any, result: Dummy) => {
//                     // Try to get item
//                     assert.isNull(result);

//                     callback(err);
//                 });
//             }
//         ], callback);
//     }

//     public testBatchOperations(callback: (err: any) => void): void {
//         let dummy1: Dummy;
//         let dummy2: Dummy;

//         async.series([
//             (callback) => {
//                 // Create one dummy
//                 this._persistence.create(null, this._dummy1, (err: any, result: Dummy) => {
//                     dummy1 = result;
//                     assert.isNotNull(dummy1);
//                     assert.isNotNull(dummy1.id);
//                     assert.equal(this._dummy1.key, dummy1.key);
//                     assert.equal(this._dummy1.content, dummy1.content);

//                     callback(err);
//                 });
//             },
//             (callback) => {
//                 // Create another dummy
//                 this._persistence.create(null, this._dummy2, (err: any, result: Dummy) => {
//                     dummy2 = result;
//                     assert.isNotNull(dummy2);
//                     assert.isNotNull(dummy2.id);
//                     assert.equal(this._dummy2.key, dummy2.key);
//                     assert.equal(this._dummy2.content, dummy2.content);

//                     callback(err);
//                 });
//             },
//             (callback) => {
//                 // Read batch
//                 this._persistence.getListByIds(null, [dummy1.id, dummy2.id], (err, items) => {
//                     assert.isArray(items);
//                     assert.lengthOf(items, 2);

//                     callback(err);
//                 });
//             },
//             (callback) => {
//                 // Delete batch
//                 this._persistence.deleteByIds(null, [dummy1.id, dummy2.id], (err) => {
//                     assert.isNull(err);
//                     callback(err);
//                 });
//             },
//             (callback) => {
//                 // Read empty batch
//                 this._persistence.getListByIds(null, [dummy1.id, dummy2.id], (err, items) => {
//                     assert.isArray(items);
//                     assert.lengthOf(items, 0);

//                     callback(err);
//                 });
//             }
//         ], callback);
//     }

// }