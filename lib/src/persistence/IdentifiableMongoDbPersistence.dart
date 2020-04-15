// /** @module persistence */
// /** @hidden */
// let _ = require('lodash');
// /** @hidden */
// let async = require('async');

// import { ConfigParams } from 'pip-services3-commons-node';
// import { PagingParams } from 'pip-services3-commons-node';
// import { DataPage } from 'pip-services3-commons-node';
// import { AnyValueMap } from 'pip-services3-commons-node';
// import { IIdentifiable } from 'pip-services3-commons-node';
// import { IdGenerator } from 'pip-services3-commons-node';

// import { IWriter } from 'pip-services3-data-node';
// import { IGetter } from 'pip-services3-data-node';
// import { ISetter } from 'pip-services3-data-node';

// import { MongoDbPersistence } from './MongoDbPersistence';

// /**
//  * Abstract persistence component that stores data in MongoDB
//  * and implements a number of CRUD operations over data items with unique ids.
//  * The data items must implement IIdentifiable interface.
//  * 
//  * In basic scenarios child classes shall only override [[getPageByFilter]],
//  * [[getListByFilter]] or [[deleteByFilter]] operations with specific filter function.
//  * All other operations can be used out of the box. 
//  * 
//  * In complex scenarios child classes can implement additional operations by 
//  * accessing <code>this._collection</code> and <code>this._model</code> properties.

//  * ### Configuration parameters ###
//  * 
//  * - collection:                  (optional) MongoDB collection name
//  * - connection(s):    
//  *   - discovery_key:             (optional) a key to retrieve the connection from [[https://rawgit.com/pip-services-node/pip-services3-components-node/master/doc/api/interfaces/connect.idiscovery.html IDiscovery]]
//  *   - host:                      host name or IP address
//  *   - port:                      port number (default: 27017)
//  *   - uri:                       resource URI or connection string with all parameters in it
//  * - credential(s):    
//  *   - store_key:                 (optional) a key to retrieve the credentials from [[https://rawgit.com/pip-services-node/pip-services3-components-node/master/doc/api/interfaces/auth.icredentialstore.html ICredentialStore]]
//  *   - username:                  (optional) user name
//  *   - password:                  (optional) user password
//  * - options:
//  *   - max_pool_size:             (optional) maximum connection pool size (default: 2)
//  *   - keep_alive:                (optional) enable connection keep alive (default: true)
//  *   - connect_timeout:           (optional) connection timeout in milliseconds (default: 5000)
//  *   - socket_timeout:            (optional) socket timeout in milliseconds (default: 360000)
//  *   - auto_reconnect:            (optional) enable auto reconnection (default: true)
//  *   - reconnect_interval:        (optional) reconnection interval in milliseconds (default: 1000)
//  *   - max_page_size:             (optional) maximum page size (default: 100)
//  *   - replica_set:               (optional) name of replica set
//  *   - ssl:                       (optional) enable SSL connection (default: false)
//  *   - auth_source:               (optional) authentication source
//  *   - auth_user:                 (optional) authentication user name
//  *   - auth_password:             (optional) authentication user password
//  *   - debug:                     (optional) enable debug output (default: false).
//  * 
//  * ### References ###
//  * 
//  * - <code>\*:logger:\*:\*:1.0</code>           (optional) [[https://rawgit.com/pip-services-node/pip-services3-components-node/master/doc/api/interfaces/log.ilogger.html ILogger]] components to pass log messages components to pass log messages
//  * - <code>\*:discovery:\*:\*:1.0</code>        (optional) [[https://rawgit.com/pip-services-node/pip-services3-components-node/master/doc/api/interfaces/connect.idiscovery.html IDiscovery]] services
//  * - <code>\*:credential-store:\*:\*:1.0</code> (optional) Credential stores to resolve credentials
//  * 
//  * ### Example ###
//  * 
//  *     class MyMongoDbPersistence extends MongoDbPersistence<MyData, string> {
//  *    
//  *     public constructor() {
//  *         base("mydata", new MyDataMongoDbSchema());
//  *     }
//  * 
//  *     private composeFilter(filter: FilterParams): any {
//  *         filter = filter || new FilterParams();
//  *         let criteria = [];
//  *         let name = filter.getAsNullableString('name');
//  *         if (name != null)
//  *             criteria.push({ name: name });
//  *         return criteria.length > 0 ? { $and: criteria } : null;
//  *     }
//  * 
//  *     public getPageByFilter(correlationId: string, filter: FilterParams, paging: PagingParams,
//  *         callback: (err: any, page: DataPage<MyData>) => void): void {
//  *         base.getPageByFilter(correlationId, this.composeFilter(filter), paging, null, null, callback);
//  *     }
//  * 
//  *     }
//  * 
//  *     let persistence = new MyMongoDbPersistence();
//  *     persistence.configure(ConfigParams.fromTuples(
//  *         "host", "localhost",
//  *         "port", 27017
//  *     ));
//  * 
//  *     persitence.open("123", (err) => {
//  *         ...
//  *     });
//  * 
//  *     persistence.create("123", { id: "1", name: "ABC" }, (err, item) => {
//  *         persistence.getPageByFilter(
//  *             "123",
//  *             FilterParams.fromTuples("name", "ABC"),
//  *             null,
//  *             (err, page) => {
//  *                 console.log(page.data);          // Result: { id: "1", name: "ABC" }
//  * 
//  *                 persistence.deleteById("123", "1", (err, item) => {
//  *                    ...
//  *                 });
//  *             }
//  *         )
//  *     });
//  */
// export class IdentifiableMongoDbPersistence<T extends IIdentifiable<K>, K> extends MongoDbPersistence
//     implements IWriter<T, K>, IGetter<T, K>, ISetter<T> {
//     //TODO (note for SS): is this needed? It's in MongoDbPersistence as well...
//     protected _maxPageSize: number = 100;

//     /**
//      * Creates a new instance of the persistence component.
//      * 
//      * @param collection    (optional) a collection name.
//      */
//     public constructor(collection: string) {
//         super(collection);

//         if (collection == null)
//             throw new Error("Collection name could not be null");
//     }

//     /**
//      * Configures component by passing configuration parameters.
//      * 
//      * @param config    configuration parameters to be set.
//      */
//     public configure(config: ConfigParams): void {
//         super.configure(config);
        
//         this._maxPageSize = config.getAsIntegerWithDefault("options.max_page_size", this._maxPageSize);
//     }

//     /** 
//      * Converts the given object from the public partial format.
//      * 
//      * @param value     the object to convert from the public partial format.
//      * @returns the initial object.
//      */
//     protected convertFromPublicPartial(value: any): any {
//         return this.convertFromPublic(value);
//     }    
    
//     /**
//      * Gets a page of data items retrieved by a given filter and sorted according to sort parameters.
//      * 
//      * This method shall be called by a public getPageByFilter method from child class that
//      * receives FilterParams and converts them into a filter function.
//      * 
//      * @param correlationId     (optional) transaction id to trace execution through call chain.
//      * @param filter            (optional) a filter JSON object
//      * @param paging            (optional) paging parameters
//      * @param sort              (optional) sorting JSON object
//      * @param select            (optional) projection JSON object
//      * @param callback          callback function that receives a data page or error.
//      */
//     protected getPageByFilter(correlationId: string, filter: any, paging: PagingParams, 
//         sort: any, select: any, callback: (err: any, items: DataPage<T>) => void): void {
//         // Adjust max item count based on configuration
//         paging = paging || new PagingParams();
//         let skip = paging.getSkip(-1);
//         let take = paging.getTake(this._maxPageSize);
//         let pagingEnabled = paging.total;

//         // Configure options
//         let options: any = {};

//         if (skip >= 0) options.skip = skip;
//         options.limit = take;
//         if (sort && !_.isEmpty(sort)) options.sort = sort;
//         if (select && !_.isEmpty(select)) options.select = select;

//         this._collection.find(filter, options).toArray((err, items) => {
//             if (err) {
//                 callback(err, null);
//                 return;
//             }

//             if (items != null)
//                 this._logger.trace(correlationId, "Retrieved %d from %s", items.length, this._collectionName);

//             items = _.map(items, this.convertToPublic);

//             if (pagingEnabled) {
//                 this._collection.countDocuments(filter, (err, count) => {
//                     if (err) {
//                         callback(err, null);
//                         return;
//                     }
                        
//                     let page = new DataPage<T>(items, count);
//                     callback(null, page);
//                 });
//             } else {
//                 let page = new DataPage<T>(items);
//                 callback(null, page);
//             }
//         });
//     }

//     /**
//      * Gets a list of data items retrieved by a given filter and sorted according to sort parameters.
//      * 
//      * This method shall be called by a public getListByFilter method from child class that
//      * receives FilterParams and converts them into a filter function.
//      * 
//      * @param correlationId    (optional) transaction id to trace execution through call chain.
//      * @param filter           (optional) a filter JSON object
//      * @param paging           (optional) paging parameters
//      * @param sort             (optional) sorting JSON object
//      * @param select           (optional) projection JSON object
//      * @param callback         callback function that receives a data list or error.
//      */
//     protected getListByFilter(correlationId: string, filter: any, sort: any, select: any, 
//         callback: (err: any, items: T[]) => void): void {
        
//         // Configure options
//         let options: any = {};

//         if (sort && !_.isEmpty(sort)) options.sort = sort;
//         if (select && !_.isEmpty(select)) options.select = select;

//         this._collection.find(filter, options).toArray((err, items) => {
//             if (err) {
//                 callback(err, null);
//                 return;
//             }

//             if (items != null)
//                 this._logger.trace(correlationId, "Retrieved %d from %s", items.length, this._collectionName);
                
//             items = _.map(items, this.convertToPublic);
//             callback(null, items);
//         });
//     }

//     /**
//      * Gets a list of data items retrieved by given unique ids.
//      * 
//      * @param correlationId     (optional) transaction id to trace execution through call chain.
//      * @param ids               ids of data items to be retrieved
//      * @param callback         callback function that receives a data list or error.
//      */
//     public getListByIds(correlationId: string, ids: K[],
//         callback: (err: any, items: T[]) => void): void {
//         let filter = {
//             _id: { $in: ids }
//         }
//         this.getListByFilter(correlationId, filter, null, null, callback);
//     }

//     /**
//      * Gets a data item by its unique id.
//      * 
//      * @param correlationId     (optional) transaction id to trace execution through call chain.
//      * @param id                an id of data item to be retrieved.
//      * @param callback          callback function that receives data item or error.
//      */
//     public getOneById(correlationId: string, id: K, callback: (err: any, item: T) => void): void {
//         let filter = { _id: id };

//         this._collection.findOne(filter, (err, item) => {
//             if (item == null)
//                 this._logger.trace(correlationId, "Nothing found from %s with id = %s", this._collectionName, id);
//             else
//                 this._logger.trace(correlationId, "Retrieved from %s with id = %s", this._collectionName, id);

//             item = this.convertToPublic(item);
//             callback(err, item);
//         });
//     }

//     /**
//      * Gets a random item from items that match to a given filter.
//      * 
//      * This method shall be called by a public getOneRandom method from child class that
//      * receives FilterParams and converts them into a filter function.
//      * 
//      * @param correlationId     (optional) transaction id to trace execution through call chain.
//      * @param filter            (optional) a filter JSON object
//      * @param callback          callback function that receives a random item or error.
//      */
//     protected getOneRandom(correlationId: string, filter: any, callback: (err: any, item: T) => void): void {
//         this._collection.countDocuments(filter, (err, count) => {
//             if (err) {
//                 callback(err, null);
//                 return;
//             }

//             let pos = _.random(0, count - 1);
//             let options = {
//                 skip: pos >= 0 ? pos : 0,
//                 limit: 1,
//             }

//             this._collection.find(filter, options).toArray((err, items) => {
//                 let item = (items != null && items.length > 0) ? items[0] : null;
                
//                 item = this.convertToPublic(item);
//                 callback(err, item);
//             });
//         });
//     }

//     /**
//      * Creates a data item.
//      * 
//      * @param correlation_id    (optional) transaction id to trace execution through call chain.
//      * @param item              an item to be created.
//      * @param callback          (optional) callback function that receives created item or error.
//      */
//     public create(correlationId: string, item: T, callback?: (err: any, item: T) => void): void {
//         if (item == null) {
//             callback(null, null);
//             return;
//         }

//         // Assign unique id
//         let newItem: any = _.omit(item, 'id');
//         newItem._id = item.id || IdGenerator.nextLong();
//         newItem = this.convertFromPublic(newItem);

//         this._collection.insertOne(newItem, (err, result) => {
//             if (!err)
//                 this._logger.trace(correlationId, "Created in %s with id = %s", this._collectionName, newItem._id);

//             newItem = result && result.ops ? this.convertToPublic(result.ops[0]) : null;
//             callback(err, newItem);
//         });
//     }

//     /**
//      * Sets a data item. If the data item exists it updates it,
//      * otherwise it create a new data item.
//      * 
//      * @param correlation_id    (optional) transaction id to trace execution through call chain.
//      * @param item              a item to be set.
//      * @param callback          (optional) callback function that receives updated item or error.
//      */
//     public set(correlationId: string, item: T, callback?: (err: any, item: T) => void): void {
//         if (item == null) {
//             if (callback) callback(null, null);
//             return;
//         }

//         // Assign unique id
//         let newItem: any = _.omit(item, 'id');
//         newItem._id = item.id || IdGenerator.nextLong();
//         newItem = this.convertFromPublic(newItem);

//         let filter = {
//             _id: newItem._id
//         };

//         let options = {
//             returnOriginal: false,
//             upsert: true
//         };
        
//         this._collection.findOneAndReplace(filter, newItem, options, (err, result) => {
//             if (!err)
//                 this._logger.trace(correlationId, "Set in %s with id = %s", this._collectionName, item.id);
           
//             if (callback) {
//                 newItem = result ? this.convertToPublic(result.value) : null;
//                 callback(err, newItem);
//             }
//         });
//     }

//     /**
//      * Updates a data item.
//      * 
//      * @param correlation_id    (optional) transaction id to trace execution through call chain.
//      * @param item              an item to be updated.
//      * @param callback          (optional) callback function that receives updated item or error.
//      */
//     public update(correlationId: string, item: T, callback?: (err: any, item: T) => void): void {
//         if (item == null || item.id == null) {
//             if (callback) callback(null, null);
//             return;
//         }

//         let newItem = _.omit(item, 'id');
//         newItem = this.convertFromPublic(newItem);

//         let filter = { _id: item.id };
//         let update = { $set: newItem };
//         let options = {
//             returnOriginal: false
//         };

//         this._collection.findOneAndUpdate(filter, update, options, (err, result) => {
//             if (!err)
//                 this._logger.trace(correlationId, "Updated in %s with id = %s", this._collectionName, item.id);

//             if (callback) {
//                 newItem = result ? this.convertToPublic(result.value) : null;
//                 callback(err, newItem);
//             }
//         });
//     }

//     /**
//      * Updates only few selected fields in a data item.
//      * 
//      * @param correlation_id    (optional) transaction id to trace execution through call chain.
//      * @param id                an id of data item to be updated.
//      * @param data              a map with fields to be updated.
//      * @param callback          callback function that receives updated item or error.
//      */
//     public updatePartially(correlationId: string, id: K, data: AnyValueMap,
//         callback?: (err: any, item: T) => void): void {
            
//         if (data == null || id == null) {
//             if (callback) callback(null, null);
//             return;
//         }

//         let newItem = data.getAsObject();
//         newItem = this.convertFromPublicPartial(newItem);

//         let filter = { _id: id };
//         let update = { $set: newItem };
//         let options = {
//             returnOriginal: false
//         };

//         this._collection.findOneAndUpdate(filter, update, options, (err, result) => {
//             if (!err)
//                 this._logger.trace(correlationId, "Updated partially in %s with id = %s", this._collectionName, id);

//             if (callback) {
//                 newItem = result ? this.convertToPublic(result.value) : null;
//                 callback(err, newItem);
//             }
//         });
//     }

//     /**
//      * Deleted a data item by it's unique id.
//      * 
//      * @param correlation_id    (optional) transaction id to trace execution through call chain.
//      * @param id                an id of the item to be deleted
//      * @param callback          (optional) callback function that receives deleted item or error.
//      */
//     public deleteById(correlationId: string, id: K, callback?: (err: any, item: T) => void): void {
//         let filter = { _id: id };
//         this._collection.findOneAndDelete(filter, (err, result) => {
//             if (!err)
//                 this._logger.trace(correlationId, "Deleted from %s with id = %s", this._collectionName, id);

//             if (callback) {
//                 let oldItem = result ? this.convertToPublic(result.value) : null;
//                 callback(err, oldItem);
//             }
//         });
//     }

//     /**
//      * Deletes data items that match to a given filter.
//      * 
//      * This method shall be called by a public deleteByFilter method from child class that
//      * receives FilterParams and converts them into a filter function.
//      * 
//      * @param correlationId     (optional) transaction id to trace execution through call chain.
//      * @param filter            (optional) a filter JSON object.
//      * @param callback          (optional) callback function that receives error or null for success.
//      */
//     public deleteByFilter(correlationId: string, filter: any, callback?: (err: any) => void): void {
//         this._collection.deleteMany(filter, (err, result) => {
//             let count = result ? result.deletedCount : 0;
//             if (!err)
//                 this._logger.trace(correlationId, "Deleted %d items from %s", count, this._collectionName);

//             if (callback) callback(err);
//         });
//     }

//     /**
//      * Deletes multiple data items by their unique ids.
//      * 
//      * @param correlationId     (optional) transaction id to trace execution through call chain.
//      * @param ids               ids of data items to be deleted.
//      * @param callback          (optional) callback function that receives error or null for success.
//      */
//     public deleteByIds(correlationId: string, ids: K[], callback?: (err: any) => void): void {
//         let filter = {
//             _id: { $in: ids }
//         }
//         this.deleteByFilter(correlationId, filter, callback);
//     }
// }
