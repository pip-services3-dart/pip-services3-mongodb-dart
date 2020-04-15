// import { FilterParams } from 'pip-services3-commons-node';
// import { PagingParams } from 'pip-services3-commons-node';
// import { DataPage } from 'pip-services3-commons-node';

// import { IdentifiableMongoDbPersistence } from '../../src/persistence/IdentifiableMongoDbPersistence';
// import { Dummy } from '../fixtures/Dummy';
// import { IDummyPersistence } from '../fixtures/IDummyPersistence';

// export class DummyMongoDbPersistence 
//     extends IdentifiableMongoDbPersistence<Dummy, string> 
//     implements IDummyPersistence
// {
//     public constructor() {
//         super('dummies');
//         this.ensureIndex({ key: 1 });
//     }

//     public getPageByFilter(correlationId: string, filter: FilterParams, paging: PagingParams, 
//         callback: (err: any, page: DataPage<Dummy>) => void): void {
//         filter = filter || new FilterParams();
//         let key = filter.getAsNullableString('key');

//         let filterCondition: any = {};
//         if (key != null)
//             filterCondition['key'] = key;

//         super.getPageByFilter(correlationId, filterCondition, paging, null, null, callback);
//     }
// }