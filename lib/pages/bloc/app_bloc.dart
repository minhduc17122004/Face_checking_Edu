import 'dart:async';
import 'dart:developer';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:face_time_keeping/common/event/event_bus_event.dart';
import 'package:face_time_keeping/common/utils/location_util.dart';
import 'package:face_time_keeping/data/local/hive_service.dart';

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

    // Listen to sync student events
    listenEvent<SyncStudentEvent>((e) => _onSyncStudentEvent(e));
  }

  void _onSyncStudentEvent(SyncStudentEvent event) async {
    if (event.status == 'in_progress') {
      emit(state.copyWith(
        syncStatus: SyncProgressStatus.syncing,
        syncMessage: event.message ?? 'Đang đồng bộ...',
      ));
    } else if (event.status == 'silent') {
      return;
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

  void _getCurrentPosition() async {
    try {
      final position = await LocationUtil.getCurrentPosition();
      emit(state.copyWith(position: position));
    } catch (e) {
      log('Lỗi khi lấy vị trí: $e');
    }
  }
}
