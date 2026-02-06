import 'package:hive/hive.dart';

part 'tenant.g.dart';

@HiveType(typeId: 6)
class Tenant extends HiveObject {
  @HiveField(0)
  final int? id;

  @HiveField(1)
  final String url;

  @HiveField(2)
  final String databaseName;

  Tenant({
    this.id,
    required this.url,
    required this.databaseName,
  });
}
