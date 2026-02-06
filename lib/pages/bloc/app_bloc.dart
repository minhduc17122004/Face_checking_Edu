import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:face_time_keeping/common/event/event_bus_event.dart';
import 'package:face_time_keeping/common/utils/location_util.dart';

import 'package:face_time_keeping/common/utils/rsa_util.dart';
import 'package:face_time_keeping/data/local/hive_service.dart';
import 'package:face_time_keeping/data/local/local_service.dart';

import 'package:face_time_keeping/di/injection.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:injectable/injectable.dart';

import '../../common/event/event_bus_mixin.dart';

import 'app_state.dart';

@Singleton()
class AppBloc extends Cubit<AppState> with EventBusMixin {
  late final Timer? _timer;
  final HiveService _hiveService;
  AppBloc(this._hiveService) : super(const AppState()) {
    _getCurrentPosition();
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _getCurrentPosition();
    });

    // Listen to sync employee events
    listenEvent<SyncEmployeeEvent>((e) => _onSyncEmployeeEvent(e));
  }

  void _onSyncEmployeeEvent(SyncEmployeeEvent event) async {
    if (event.status == 'in_progress') {
      emit(state.copyWith(
        syncStatus: SyncProgressStatus.syncing,
        syncMessage: event.message ?? 'Đang đồng bộ...',
      ));
    } else if (event.status == 'success' || event.success == true) {
      await _hiveService.refreshPersonBox();
      emit(state.copyWith(
        syncStatus: SyncProgressStatus.success,
        syncMessage: event.message ?? 'Đồng bộ thành công',
      ));
      // Auto-hide after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (state.syncStatus == SyncProgressStatus.success) {
          emit(state.copyWith(syncStatus: SyncProgressStatus.idle));
        }
      });
    } else {
      emit(state.copyWith(
        syncStatus: SyncProgressStatus.failed,
        syncMessage: event.message ?? 'Đồng bộ thất bại',
      ));
      // Auto-hide after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (state.syncStatus == SyncProgressStatus.failed) {
          emit(state.copyWith(syncStatus: SyncProgressStatus.idle));
        }
      });
    }
  }

  Future<bool> isExpiredLicenseKey({String? li_Key}) async {
    try {
      final licenseKey = li_Key ?? await getIt<LocalService>().getLicenseKey();
      final rsaUtil = await RSAUtil.fromAsset("assets/private.pem");
      final encryptedLicenseKey = rsaUtil.decryptFromBase64(licenseKey);
      final decode = (encryptedLicenseKey is Map<String, dynamic>)
          ? encryptedLicenseKey
          : json.decode(encryptedLicenseKey);
      final licenseExpiredDate = DateTime.parse(decode['licenseExpiredDate']);
      return licenseExpiredDate.isBefore(DateTime.now());
    } catch (e) {
      emit(state.copyWith(appStatus: AppStatus.license_not_registered));
      return true;
    }
  }

  void _getCurrentPosition() async {
    try {
      final position = await LocationUtil.getCurrentPosition();
      emit(state.copyWith(position: position));
    } catch (e) {
      log('Lỗi khi lấy vị trí: $e');
    }
  }

  void loadLicenseExpiredDate() async {
    final isExpired = await isExpiredLicenseKey();
    if (isExpired) {
      emit(state.copyWith(appStatus: AppStatus.license_expired));
    } else {
      emit(state.copyWith(appStatus: AppStatus.license_valid));
    }
  }

  void checkLicenseExpired() async {
    EasyDebounce.debounce('my-debouncer', const Duration(seconds: 3), () async {
      //        final currentTime = await getIt<UserService>().fetchWorldTime();
      // final localTime = DateTime.now();
      // final difference = currentTime.difference(localTime).inMinutes.abs();
      // if (difference > 5) {
      //   emit(state.copyWith(appStatus: AppStatus.wrong_time_local));
      //   return;
      // }
      final isExpired = await isExpiredLicenseKey();
      if (isExpired) {
        emit(state.copyWith(appStatus: AppStatus.license_expired));
      } else {
        emit(state.copyWith(appStatus: AppStatus.license_valid));
      }
    });
  }
}
