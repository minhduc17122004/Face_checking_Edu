import 'package:face_time_keeping/common/utils/location_util.dart';
import 'package:geolocator/geolocator.dart';

enum AppStatus {
  active,
  wrong_time_local,
}

enum SyncProgressStatus {
  idle,
  syncing,
  success,
  failed,
}

class AppState {
  final AppStatus appStatus;
  final Position? position;
  final SyncProgressStatus syncStatus;
  final String? syncMessage;

  const AppState({
    this.appStatus = AppStatus.active,
    this.position,
    this.syncStatus = SyncProgressStatus.idle,
    this.syncMessage,
  });

  AppState copyWith({
    AppStatus? appStatus,
    Position? position,
    LocationPermissionStatus? locationPermissionStatus,
    SyncProgressStatus? syncStatus,
    String? syncMessage,
  }) {
    return AppState(
      appStatus: appStatus ?? this.appStatus,
      position: position ?? this.position,
      syncStatus: syncStatus ?? this.syncStatus,
      syncMessage: syncMessage,
    );
  }
}
