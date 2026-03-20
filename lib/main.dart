import 'dart:async';
import 'dart:developer';
import 'package:face_time_keeping/common/event/event_bus_event.dart';
import 'package:face_time_keeping/common/event/event_bus_mixin.dart';
import 'package:face_time_keeping/common/utils/isolate_listen_util.dart';
import 'package:face_time_keeping/common/utils/sync_jobs_util.dart';
import 'package:face_time_keeping/entities/check_in_out.dart';
import 'package:face_time_keeping/entities/person.dart';
import 'package:face_time_keeping/entities/tenant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:workmanager/workmanager.dart';
import 'app.dart';
import 'configs/build_config.dart';
import 'di/injection.dart';
import 'package:hive/hive.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      const String environment = String.fromEnvironment(
        'ENVIRONMENT',
        defaultValue: Environment.prod,
      );
      await WakelockPlus.enable();
      final directory = await getApplicationDocumentsDirectory();
      Hive.init(directory.path);
      Hive.registerAdapter(CheckInOutAdapter());
      Hive.registerAdapter(PersonAdapter());
      Hive.registerAdapter(TenantAdapter());

      await configureDependencies(environment);
      IsolateListenUtil.listen((msg) {
        if (msg is Map && msg['type'] == sendPortSyncStudentType) {
          EventBusMixin.shareStaticEvent(SyncStudentEvent(
            status: msg['status'] as String? ?? 
                   (msg['success'] == true ? 'success' : 'failed'),
            success: msg['success'] as bool?,
            message: msg['message'] as String?,
          ));
        } else {
          EventBusMixin.shareStaticEvent(SyncDataEvent());
        }
      });
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: true,
      );
      await SyncJobsUtil.initialize(
          debug: true,
          onNotificationTap: () {
            EventBusMixin.shareStaticEvent(SyncDataEvent());
          });
      final BuildConfig buildConfig = getIt<BuildConfig>();
      if (buildConfig.debugLog) {
        Bloc.observer = AppBlocObserver();
      }
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
      runApp(const MyApp());
    },
    (error, stackTrace) {
      log('error: $error');
    },
  );
}

class AppBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    log('${bloc.runtimeType} $change');
  }
}
