import 'package:collection/collection.dart';

enum UserStatus {
  active(1),
  inActive(2);

  const UserStatus(this.value);

  final int value;
}

extension UserStatusX on UserStatus {
  static UserStatus? initFrom(int? value) {
    return UserStatus.values.firstWhereOrNull((UserStatus e) => e.value == value);
  }
}