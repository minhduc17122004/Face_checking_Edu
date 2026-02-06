import 'package:face_time_keeping/common/utils/location_util.dart';
import 'package:geolocator/geolocator.dart';

enum AppStatus {
  license_valid,
  license_expired,
  license_not_registered,
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
  final DateTime? licenseExpiredDate;
  final Position? position;
  final SyncProgressStatus syncStatus;
  final String? syncMessage;
  
  const AppState({
    this.appStatus = AppStatus.license_not_registered,
    this.licenseExpiredDate,
    this.position,
    this.syncStatus = SyncProgressStatus.idle,
    this.syncMessage,
  });
  
  AppState copyWith({
    AppStatus? appStatus,
    DateTime? licenseExpiredDate,
    Position? position,
    LocationPermissionStatus? locationPermissionStatus,
    SyncProgressStatus? syncStatus,
    String? syncMessage,
  }) {
    return AppState(
      appStatus: appStatus ?? this.appStatus,
      licenseExpiredDate: licenseExpiredDate ?? this.licenseExpiredDate,
      position: position ?? this.position,
      syncStatus: syncStatus ?? this.syncStatus,
      syncMessage: syncMessage,
    );
  }
}
