# Config Ide
- flutter packages pub run build_runner build
- or: flutter packages pub run build_runner build --delete-conflicting-outputs
- Preference > Editor > Code Style > Dart > Line Length: 100


# Config project

- Add key.properties to folder android/ => "android/key.properties"


# Run project with env
- Run by command line:
  prod: flutter run --dart-define=ENVIRONMENT=prod
  dev: flutter run --dart-define=ENVIRONMENT=dev
  staging: flutter run --dart-define=ENVIRONMENT=test

- Or config on debug configuration of android studio by adding above command line on "Addition run args" for each env
  ![alt text](/img_guide.png)

# Build apk/api with env
- Run by command line:
  iOS:
  prod: flutter build ipa --release --obfuscate --split-debug-info=build/app/outputs/symbols --dart-define=ENVIRONMENT=prod
  dev: flutter build ipa --release --obfuscate --split-debug-info=build/app/outputs/symbols --dart-define=ENVIRONMENT=dev
  staging: flutter build ipa --release --obfuscate --split-debug-info=build/app/outputs/symbols --dart-define=ENVIRONMENT=test

  Android:
  prod: flutter build appbundle --dart-define=ENVIRONMENT=prod
  dev: flutter build apk --dart-define=ENVIRONMENT=dev
  staging: flutter build apk --dart-define=ENVIRONMENT=test 
