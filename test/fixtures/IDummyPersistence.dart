// import { FilterParams } from 'pip-services3-commons-node';
// import { PagingParams } from 'pip-services3-commons-node';
// import { DataPage } from 'pip-services3-commons-node';
// import { AnyValueMap } from 'pip-services3-commons-node';

// import { IGetter } from 'pip-services3-data-node';
// import { IWriter } from 'pip-services3-data-node';
// import { IPartialUpdater } from 'pip-services3-data-node';
// import { Dummy } from './Dummy';

// export interface IDummyPersistence extends IGetter<Dummy, String>, IWriter<Dummy, String>, IPartialUpdater<Dummy, String> {
//     getPageByFilter(correlationId: string, filter: FilterParams, paging: PagingParams, callback: (err: any, page: DataPage<Dummy>) => void): void;
//     getListByIds(correlationId: string, ids: string[], callback: (err: any, items: Dummy[]) => void): void;
//     getOneById(correlationId: string, id: string, callback: (err: any, item: Dummy) => void): void;
//     create(correlationId: string, item: Dummy, callback: (err: any, item: Dummy) => void): void;
//     update(correlationId: string, item: Dummy, callback: (err: any, item: Dummy) => void): void;
//     updatePartially(correlationId: string, id: string, data: AnyValueMap, callback: (err: any, item: Dummy) => void): void;
//     deleteById(correlationId: string, id: string, callback: (err: any, item: Dummy) => void): void;
//     deleteByIds(correlationId: string, id: string[], callback: (err: any) => void): void;
// }
