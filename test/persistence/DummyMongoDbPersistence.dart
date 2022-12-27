import 'dart:async';
import 'package:pip_services3_commons/pip_services3_commons.dart';

import 'package:pip_services3_mongodb/pip_services3_mongodb.dart';
import '../fixtures/Dummy.dart';
import '../fixtures/IDummyPersistence.dart';

class DummyMongoDbPersistence
    extends IdentifiableMongoDbPersistence<Dummy, String>
    implements IDummyPersistence {
  DummyMongoDbPersistence() : super('dummies') {
    ensureIndex({'key': 1}, unique: true);
  }

  @override
  Future<DataPage<Dummy>> getPageByFilter(
      String? correlationId, FilterParams? filter, PagingParams? paging) async {
    filter = filter ?? FilterParams();
    var key = filter.getAsNullableString('key');

    var filterCondition = <String, dynamic>{};
    if (key != null) {
      filterCondition['key'] = key;
    }

    return super
        .getPageByFilterEx(correlationId, filterCondition, paging, null);
  }

  @override
  Future<int> getCountByFilter(
      String? correlationId, FilterParams? filter) async {
    filter = filter ?? FilterParams();
    var key = filter.getAsNullableString('key');

    var filterCondition = <String, dynamic>{};
    if (key != null) {
      filterCondition['key'] = key;
    }

    return super.getCountByFilterEx(correlationId, filterCondition);
  }
}
