# Generate Hive object adapter
- Using hive_generator, check file pubspec.yaml
1️⃣ Add dependencies
```
dependencies:
  hive: ^2.2.3
  hive_flutter: ^1.1.0

dev_dependencies:
  hive_generator: ^2.0.1
  build_runner: ^2.4.9

```
2️⃣ Create a Hive model
Example: user.dart
```
import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 1)
class User extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int age;

  User({
    required this.id,
    required this.name,
    required this.age,
  });
}
```

⚠️ Important rules

Each model must have a unique typeId

Each field must have a unique index

part 'xxx.g.dart'; is mandatory

3️⃣ Generate the adapter
- Run this command in terminal:
flutter pub run build_runner build
- Or if you want auto-overwrite:
flutter pub run build_runner build --delete-conflicting-outputs
- This generates: user.g.dart
- Which contains:
```
class UserAdapter extends TypeAdapter<User> {
  ...
}
```

4️⃣ Register adapter
Usually in main():
```
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.init();

  Hive.registerAdapter(UserAdapter());

  runApp(const MyApp());
}
```

5️⃣ Open box
final box = await Hive.openBox<User>('users');