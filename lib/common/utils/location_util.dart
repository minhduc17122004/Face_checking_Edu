import 'dart:developer';

import 'package:geolocator/geolocator.dart';

enum LocationPermissionStatus {
  granted,
  serviceDisabled,
  denied,
  deniedForever,
  reducedAccuracy,
}

class LocationUtil {
  static final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      intervalDuration: const Duration(seconds: 45),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText:
            "Example app will continue to receive your location even when you aren't using it",
        notificationTitle: "Running in Background",
        enableWakeLock: true,
      ));

  static Future<LocationPermissionStatus> checkLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return LocationPermissionStatus.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      // await Geolocator.openAppSettings();
      return LocationPermissionStatus.deniedForever;
    }
    final accuracyStatus = await Geolocator.getLocationAccuracy();
    if (accuracyStatus == LocationAccuracyStatus.reduced) {
      return LocationPermissionStatus.reducedAccuracy;
    }

    return LocationPermissionStatus.granted;
  }

  static Future<Position> getCurrentPosition({
    Duration maxAge = const Duration(minutes: 5),
    double maxAccuracy = 100.0,
  }) async {
    try {
      final permissionStatus = await checkLocationPermission();
      if (permissionStatus == LocationPermissionStatus.reducedAccuracy) {
        throw Exception(
            'Độ chính xác vị trí đang bị giảm. Vui lòng bật vị trí chính xác trong Cài đặt.');
      }
      if (permissionStatus != LocationPermissionStatus.granted) {
        throw Exception(
            'Bạn chưa cấp quyền truy cập vị trí. Vui lòng cấp quyền vị trí trong Cài đặt để tiếp tục sử dụng ứng dụng.');
      }
      log('Đang lấy vị trí hiện tại...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      log(
        'Vị trí hiện tại: ${position.latitude}, ${position.longitude}, '
        'accuracy: ${position.accuracy}m',
      );
      return position;
    } catch (e) {
      log('Không lấy được vị trí hiện tại: $e');
      try {
        final lastKnown = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: true,
        );
        if (lastKnown != null) {
          final age = DateTime.now().difference(lastKnown.timestamp);
          if (age <= maxAge && lastKnown.accuracy <= maxAccuracy) {
            log(
              'Sử dụng vị trí gần nhất (${age.inMinutes} phút trước): '
              '${lastKnown.latitude}, ${lastKnown.longitude}, '
              'accuracy: ${lastKnown.accuracy}m',
            );
            return lastKnown;
          } else {
            log(
              'Vị trí gần nhất quá cũ hoặc không chính xác: '
              'age=${age.inMinutes}min, accuracy=${lastKnown.accuracy}m',
            );
          }
        }
      } catch (lastKnownError) {
        log('Không lấy được vị trí gần nhất: $lastKnownError');
      }
      rethrow;
    }
  }
}
