/// Index definition for mondodb
class MongoDbIndex {
  /// Index keys (fields)
  Map<String, dynamic> keys;

  /// Index options
  String key;
  bool unique;
  bool sparse;
  bool background;
  bool dropDups;
  Map<String, dynamic> partialFilterExpression;
  String name;

  MongoDbIndex(this.keys, this.key, this.unique, this.sparse, this.background,
      this.dropDups, this.partialFilterExpression, this.name);
}
