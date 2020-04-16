// import { FilterParams } from 'pip-services3-commons-node';
// import { PagingParams } from 'pip-services3-commons-node';
// import { DataPage } from 'pip-services3-commons-node';
// import { AnyValueMap } from 'pip-services3-commons-node';

// import { IGetter } from 'pip-services3-data-node';
// import { IWriter } from 'pip-services3-data-node';
// import { IPartialUpdater } from 'pip-services3-data-node';
// import { Dummy } from './Dummy';

// export interface IDummyPersistence extends IGetter<Dummy, String>, IWriter<Dummy, String>, IPartialUpdater<Dummy, String> {
//     getPageByFilter(String correlationId, filter: FilterParams, paging: PagingParams, callback: (err: any, page: DataPage<Dummy>) => void): void;
//     getListByIds(String correlationId, ids: string[], callback: (err: any, items: Dummy[]) => void): void;
//     getOneById(String correlationId, id: string, callback: (err: any, item: Dummy) => void): void;
//     create(String correlationId, item: Dummy, callback: (err: any, item: Dummy) => void): void;
//     update(String correlationId, item: Dummy, callback: (err: any, item: Dummy) => void): void;
//     updatePartially(String correlationId, id: string, data: AnyValueMap, callback: (err: any, item: Dummy) => void): void;
//     deleteById(String correlationId, id: string, callback: (err: any, item: Dummy) => void): void;
//     deleteByIds(String correlationId, id: string[], callback: (err: any) => void): void;
// }
