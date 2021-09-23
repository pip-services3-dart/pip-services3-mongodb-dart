import 'package:pip_services3_commons/pip_services3_commons.dart';

class Dummy implements IStringIdentifiable, ICloneable {
  @override
  String id;
  String? key;
  String? content;

  Dummy() : id = IdGenerator.nextLong();

  Dummy.from(String? id, this.key, this.content) : id = IdGenerator.nextLong();

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'key': key, 'content': content};
  }

  void fromJson(Map<String, dynamic> json) {
    id = json['id'];
    key = json['key'];
    content = json['content'];
  }

  @override
  Dummy clone() {
    return Dummy.from(id, key, content);
  }
}
