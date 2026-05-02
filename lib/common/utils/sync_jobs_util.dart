import 'dart:io';
import 'dart:ui';

import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/utils/isolate_listen_util.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/data/local/hive_service.dart';
import 'package:face_time_keeping/data/models/logging_model.dart';
import 'package:face_time_keeping/data/remote/attendance_checkin_service.dart';
import 'package:face_time_keeping/data/remote/edu_sync_service.dart';
import 'package:face_time_keeping/data/remote/logging_service.dart';
import 'package:face_time_keeping/data/remote/user_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/check_in_out.dart';
import 'package:face_time_keeping/entities/pending_edu_check_in.dart';
import 'package:face_time_keeping/entities/person.dart';
import 'package:face_time_keeping/entities/sync_face_schedule.dart';
import 'package:face_time_keeping/entities/sync_schedule.dart';
import 'package:face_time_keeping/localization/generated/intl/messages_all.dart';
import 'package:face_time_keeping/localization/generated/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:workmanager/workmanager.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/date_symbol_data_local.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
import '../../data/local/local_service.dart';

const _uniqueName = 'sync-data';
const _periodicUniqueName = 'sync-data-periodic';
const _faceDataPeriodicUniqueName = 'sync-face-data-periodic';
const _studentDataPeriodicUniqueName = 'sync-student-data-periodic';
const _eduCheckinPeriodicUniqueName = 'sync-edu-checkin-periodic';
const _iosFaceDataPeriodicUniqueName =
    'com.example.face_time_keeping.syncCheckInOut1';
const _iosCheckInOutUniqueName = 'com.example.face_time_keeping.syncCheckFace1';
const _iosStudentDataUniqueName = 'com.example.face_time_keeping.syncStudent1';
const sendPortSyncStudentType = 'sync_student';
const minPeriodicSyncInterval = Duration(minutes: 15);

Duration periodicSyncInterval({
  required int hours,
  required int minutes,
}) {
  return Duration(hours: hours, minutes: minutes);
}

void validatePeriodicSyncInterval(Duration interval) {
  if (interval < minPeriodicSyncInterval) {
    throw ArgumentError(
      'Khoảng thời gian đồng bộ định kỳ tối thiểu là '
      '${minPeriodicSyncInterval.inMinutes} phút',
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((taskName, inputData) async {
    try {
      tz.initializeTimeZones();
      final dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(CheckInOutAdapter().typeId)) {
        Hive
          ..registerAdapter(CheckInOutAdapter())
          ..registerAdapter(PersonAdapter());
      }
      if (!Hive.isAdapterRegistered(PendingEduCheckInAdapter().typeId)) {
        Hive.registerAdapter(PendingEduCheckInAdapter());
      }

      const String environment = String.fromEnvironment(
        'ENVIRONMENT',
        defaultValue: Environment.prod,
      );
      await configureDependencies(environment);

      final locale = PlatformDispatcher.instance.locale;
      final localeName = Intl.canonicalizedLocale(locale.toLanguageTag());
      await S.load(locale);
      await initializeMessages(locale.languageCode);
      await initializeDateFormatting(localeName, null);
      Intl.defaultLocale = localeName;

      await SyncJobsUtil._headlessInitLocalNotifications();
      final hiveService = getIt<HiveService>();
      final localService = getIt<LocalService>();
      await hiveService.init();
      // 6) Now it's safe to resolve from GetIt
      final userService = getIt<UserService>();

      final url = localService.getServerUrl();

      if (Platform.isAndroid) {
        if (taskName.contains(_periodicUniqueName)) {
          // 1. Đồng bộ luồng HRM cũ
          await userService.syncCheckInOutData(url: url);

          // 2. Đồng bộ luồng EDU mới (Batch Bulk API)
          final eduSyncService = getIt<EduSyncService>();
          final pending = await localService.getPendingEduCheckIns();
          final unsyncedItems = pending.where((p) => !p.isSynced).toList();

          if (unsyncedItems.isNotEmpty) {
            const batchSize = 50;
            for (var i = 0; i < unsyncedItems.length; i += batchSize) {
              final batch = unsyncedItems.skip(i).take(batchSize).toList();
              final result = await eduSyncService.syncPendingCheckIns(batch);
              if (result.isSuccess && result.data != null) {
                for (final localId in result.data!.syncedLocalIds) {
                  await localService.markEduCheckInSynced(localId);
                }
              }
            }
            await localService.clearSyncedEduCheckIns();
          }

          // Notify UI
          //  EventBusMixin.shareStaticEvent(SyncDataEvent());
          final sendPort = IsolateNameServer.lookupPortByName(
              IsolateListenUtil.bgToUiPortName);
          if (sendPort != null) {
            sendPort.send(null);
          }

          await SyncJobsUtil._safeShowNotification(
            title: 'Đồng bộ dữ liệu thành công',
            body:
                'Dữ liệu đã được cập nhật vào lúc ${SyncJobsUtil._formatNotificationTime()}',
          );
        } else if (taskName.contains(_faceDataPeriodicUniqueName)) {
          final push = await userService.pushFaceData(url: url);
          final pull = await userService.pullFaceData(url: url);

          if (!push.isSuccess || !pull.isSuccess) {
            final errors = <String>[
              if (!push.isSuccess)
                'Đẩy lên: ${push.error ?? 'Lỗi không xác định'}',
              if (!pull.isSuccess)
                'Tải về: ${pull.error ?? 'Lỗi không xác định'}',
            ].join('\n');

            await SyncJobsUtil._safeShowNotification(
              title: 'Đồng bộ dữ liệu khuôn mặt thất bại',
              body: errors,
            );
            return Future.value(false);
          }

          await SyncJobsUtil._safeShowNotification(
            title: 'Đồng bộ dữ liệu khuôn mặt thành công',
            body:
                'Dữ liệu khuôn mặt đã được cập nhật vào lúc ${SyncJobsUtil._formatNotificationTime()}',
          );
          debugPrint('sync face data done');
        } else if (taskName.contains(_studentDataPeriodicUniqueName)) {
          // --- Student data sync ---
          // Send sync started message
          var sendPort = IsolateNameServer.lookupPortByName(
              IsolateListenUtil.bgToUiPortName);
          if (sendPort != null) {
            sendPort.send({
              'type': sendPortSyncStudentType,
              'status': 'in_progress',
              'message': 'Đang đồng bộ học sinh...',
            });
          }

          final result = await userService.syncStudentData(url: url);

          // Send sync completed message
          sendPort = IsolateNameServer.lookupPortByName(
              IsolateListenUtil.bgToUiPortName);
          if (sendPort != null) {
            sendPort.send({
              'type': sendPortSyncStudentType,
              'status': result.isSuccess ? 'success' : 'failed',
              'success': result.isSuccess,
              'message': result.isSuccess ? result.data : result.error,
            });
          }
          debugPrint('sync student data done');
        } else if (taskName.contains(_eduCheckinPeriodicUniqueName)) {
          // --- EDU pending check-in sync ---
          final checkinService = getIt<AttendanceCheckinService>();
          final deviceCode = await localService.getDeviceCode();
          final pending = await localService.getPendingEduCheckIns();
          for (final item in pending) {
            if (item.retryCount >= 5) continue;
            if ((item.roomId == null || item.roomId!.isEmpty) &&
                item.sessionId == null) {
              await localService.incrementEduRetryCount(item.localId);
              continue;
            }
            try {
              final result = await checkinService.manualCheckin(
                sessionId: item.sessionId,
                studentId: item.studentId,
                roomId: item.roomId,
                timestamp: item.timestamp,
                deviceId: item.deviceId ?? deviceCode,
              );
              if (result.isSuccess) {
                await localService.markEduCheckInSynced(item.localId);
              } else {
                await localService.incrementEduRetryCount(item.localId);
              }
            } catch (_) {
              await localService.incrementEduRetryCount(item.localId);
            }
          }
          await localService.clearSyncedEduCheckIns();
          debugPrint('sync edu check-in done');
        }
      } else if (Platform.isIOS) {
        if (taskName == 'com.example.face_time_keeping.processing1') {
          final push = await userService.pushFaceData(url: url);
          final pull = await userService.pullFaceData(url: url);

          if (!push.isSuccess || !pull.isSuccess) {
            return Future.value(false);
          }
          debugPrint('sync face data done');
        } else if (taskName == 'com.example.face_time_keeping.processing2') {
          await userService.syncCheckInOutData(url: url);

          final eduSyncService = getIt<EduSyncService>();
          final pending = await localService.getPendingEduCheckIns();
          final unsyncedItems = pending.where((p) => !p.isSynced).toList();

          if (unsyncedItems.isNotEmpty) {
            const batchSize = 50;
            for (var i = 0; i < unsyncedItems.length; i += batchSize) {
              final batch = unsyncedItems.skip(i).take(batchSize).toList();
              final result = await eduSyncService.syncPendingCheckIns(batch);
              if (result.isSuccess && result.data != null) {
                for (final localId in result.data!.syncedLocalIds) {
                  await localService.markEduCheckInSynced(localId);
                }
              }
            }
            await localService.clearSyncedEduCheckIns();
          }

          //  EventBusMixin.shareStaticEvent(SyncDataEvent());
          final sendPort = IsolateNameServer.lookupPortByName(
              IsolateListenUtil.bgToUiPortName);
          if (sendPort != null) {
            sendPort.send(null);
          }
        } else if (taskName == _iosStudentDataUniqueName) {
          // Send sync started message
          var sendPort = IsolateNameServer.lookupPortByName(
              IsolateListenUtil.bgToUiPortName);
          if (sendPort != null) {
            sendPort.send({
              'type': sendPortSyncStudentType,
              'status': 'in_progress',
              'message': 'Đang đồng bộ học sinh...',
            });
          }

          final result = await userService.syncStudentData(url: url);

          // Send sync completed message
          sendPort = IsolateNameServer.lookupPortByName(
              IsolateListenUtil.bgToUiPortName);
          if (sendPort != null) {
            sendPort.send({
              'type': sendPortSyncStudentType,
              'status': result.isSuccess ? 'success' : 'failed',
              'success': result.isSuccess,
              'message': result.isSuccess ? result.data : result.error,
            });
          }
          debugPrint('sync student data done');
        }
      }

      return Future.value(true);
    } catch (e) {
      debugPrint('Error in sync jobs: $e');
      try {
        final loggingService = getIt<LoggingService>();
        final localService = getIt<LocalService>();
        final url = localService.getServerUrl();
        await loggingService.log(
            ApiInfo(
              response: LoggingApiResponse(
                message: e.toString(),
              ),
            ),
            url: url);
      } catch (logError) {
        debugPrint('Error logging sync job failure: $logError');
      }

      await SyncJobsUtil._safeShowNotification(
        title: 'Đồng bộ dữ liệu thất bại',
        body: 'Đã xảy ra lỗi khi đồng bộ dữ liệu tự động.',
      );

      return Future.value(false);
    }
  });
}

class SyncJobsUtil {
  SyncJobsUtil._();
  static const _channelId = 'sync-data-channel-id';
  static const _channelName = 'Sync Data';
  static const _channelDesc = 'Notifications for the sync data';

  static final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize({
    bool debug = false,
    required void Function() onNotificationTap,
  }) async {
    // Timezone database (safe to call multiple times)
    tz.initializeTimeZones();

    // Notification tap handler
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: DarwinInitializationSettings(),
    );

    await _fln.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onNotificationTap();
      },
    );

    // Create Android 8+ channel
    final androidFln = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidFln != null) {
      await androidFln.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ),
      );
    }

    // Android 13+ runtime notif permission
    if (Platform.isAndroid) {
      await _fln
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  static Future<void> cancelAllSyncData() async {
    await Workmanager().cancelAll();
  }

  static Future<void> cancelSyncData(SyncSchedule syncSchedule) async {
    await Workmanager().cancelByUniqueName('$_uniqueName-$syncSchedule');
    await Workmanager()
        .cancelByUniqueName('$_periodicUniqueName-$syncSchedule');
  }

  static Future<void> cancelSyncFaceData(
      SyncFaceSchedule syncFaceSchedule) async {
    await Workmanager()
        .cancelByUniqueName('$_faceDataPeriodicUniqueName-$syncFaceSchedule');
  }

  static Future<void> scheduleSyncFaceData(
      SyncFaceSchedule syncFaceSchedule) async {
    try {
      final interval = periodicSyncInterval(
        hours: syncFaceSchedule.repeatIntervalHours,
        minutes: syncFaceSchedule.repeatIntervalMinutes,
      );
      validatePeriodicSyncInterval(interval);
      if (Platform.isAndroid) {
        await Workmanager().registerPeriodicTask(
          '$_faceDataPeriodicUniqueName-$syncFaceSchedule',
          '$_faceDataPeriodicUniqueName-$syncFaceSchedule',
          frequency: interval,
          initialDelay: interval,
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
        );
      } else if (Platform.isIOS) {
        await Workmanager().registerPeriodicTask(
          _iosFaceDataPeriodicUniqueName,
          _iosFaceDataPeriodicUniqueName,
          frequency: interval,
          initialDelay: interval,
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
        );
      }
    } catch (e) {
      await pushLog('Error scheduling sync face data: $e');
      debugPrint('Error scheduling sync face data: $e');
      rethrow;
    }
  }

  static Future<void> scheduleSyncFaceDataNow(
      SyncFaceSchedule syncFaceSchedule) async {
    await Workmanager().registerOneOffTask(
      'com.example.face_time_keeping.processing1',
      'com.example.face_time_keeping.processing1',
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static Future<void> scheduleSyncDataNow(SyncSchedule syncSchedule) async {
    await Workmanager().registerOneOffTask(
      'com.example.face_time_keeping.processing2',
      'com.example.face_time_keeping.processing2',
    );
  }

  static Future<void> syncStudentDataNow() async {
    if (Platform.isIOS) {
      await Workmanager().registerOneOffTask(
        _iosStudentDataUniqueName,
        _iosStudentDataUniqueName,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    } else {
      await Workmanager().registerOneOffTask(
        _studentDataPeriodicUniqueName,
        _studentDataPeriodicUniqueName,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    }
  }

  static Duration _calculateInitialDelay(
      DateTime initialTime, int intervalHours, int intervalMinutes) {
    final interval = periodicSyncInterval(
      hours: intervalHours,
      minutes: intervalMinutes,
    );
    validatePeriodicSyncInterval(interval);
    final now = DateTime.now();
    while (initialTime.isBefore(now)) {
      initialTime = initialTime.add(interval);
    }
    final delay = initialTime.difference(now);
    return delay;
  }

  static Future<void> scheduleSyncData(SyncSchedule syncSchedule) async {
    try {
      final hour = int.parse(syncSchedule.time.split(':')[0]);
      final minute = int.parse(syncSchedule.time.split(':')[1]);
      final now = DateTime.now();
      final today = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      final delay = _calculateInitialDelay(today,
          syncSchedule.repeatIntervalHours, syncSchedule.repeatIntervalMinutes);
      debugPrint('Scheduling sync data with delay: ${delay.inSeconds} seconds');
      debugPrint('Next execution will be at: ${DateTime.now().add(delay)}');
      final interval = periodicSyncInterval(
        hours: syncSchedule.repeatIntervalHours,
        minutes: syncSchedule.repeatIntervalMinutes,
      );
      validatePeriodicSyncInterval(interval);
      if (Platform.isAndroid) {
        await Workmanager().registerPeriodicTask(
          '$_periodicUniqueName-$syncSchedule',
          '$_periodicUniqueName-$syncSchedule',
          frequency: interval,
          initialDelay: const Duration(seconds: 5),
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
        );
      } else if (Platform.isIOS) {
        await Workmanager().registerPeriodicTask(
          _iosCheckInOutUniqueName,
          _iosCheckInOutUniqueName,
          initialDelay: const Duration(seconds: 10),
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
        );
      }
    } catch (e, stackTrace) {
      await pushLog('Error scheduling sync data: $e\n$stackTrace');
      debugPrint(
        'Error scheduling sync data: $e\n$stackTrace',
      );
      rethrow;
    }
  }

  // static Duration _initialDelayToNext(TimeOfDay timeOfDay) {
  //   final now = DateTime.now();
  //   final today = DateTime(
  //       now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
  //   if (now.isBefore(today)) {
  //     return today.difference(now);
  //   } else {
  //     final tomorrow = today.add(const Duration(days: 1));
  //     return tomorrow.difference(now);
  //   }
  // }

// reInit local notifications
  static Future<void> _headlessInitLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings =
        InitializationSettings(android: androidInit, iOS: null);
    await _fln.initialize(initSettings);

    final androidFln = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidFln != null) {
      await androidFln
          .createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ));
    }
  }

  static Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: android);
    await _fln.show(1001, title, body, details);
  }

  static Future<void> _safeShowNotification({
    required String title,
    required String body,
  }) async {
    try {
      await _showNotification(title: title, body: body);
    } catch (e) {
      debugPrint('Error showing sync notification: $e');
      try {
        await pushLog('Error showing sync notification: $e');
      } catch (logError) {
        debugPrint('Error logging sync notification failure: $logError');
      }
    }
  }

  static String _formatNotificationTime() {
    try {
      return DateFormat('HH:mm dd/MM').format(DateTime.now());
    } catch (e) {
      debugPrint('Error formatting sync notification time: $e');
      return DateTime.now().toString().substring(0, 16);
    }
  }
}
