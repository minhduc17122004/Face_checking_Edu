import 'package:bloc/bloc.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/event/event_bus_event.dart';
import 'package:face_time_keeping/common/event/event_bus_mixin.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';

import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/remote/edu_sync_service.dart';
import 'package:face_time_keeping/entities/check_in_out.dart';
import 'package:face_time_keeping/entities/pending_edu_check_in.dart';
import 'package:injectable/injectable.dart';

part 'attendance_report_state.dart';

@singleton
class AttendanceReportCubit extends Cubit<AttendanceReportState>
    with EventBusMixin {
  AttendanceReportCubit(this._localService, this._eduSyncService)
      : super(const AttendanceReportState()) {
    listenEvent<SyncDataEvent>((e) => _refreshData());
    listenEvent<AttendanceChangeEvent>((e) => _refreshData());
  }

  final LocalService _localService;
  final EduSyncService _eduSyncService;

  Future<void> _refreshData() async {
    try {
      if (!isClosed) {
        emit(state.copyWith(status: RequestStatus.requesting));
      }

      await _localService.refreshCheckInOutBox();
      if (!isClosed) {
        await loadAttendanceReport();
      }
    } catch (e) {
      await pushLog('Error in _refreshData: $e');
      if (!isClosed) {
        emit(state.copyWith(
            status: RequestStatus.failed, message: e.toString()));
      }
    }
  }

  Future<void> loadAttendanceReport() async {
    try {
      final filterDate = DateTime.now();

      emit(state.copyWith(
          status: RequestStatus.requesting, filterDate: filterDate));
      final checkInOuts = await _localService.getCheckInOutByDate(filterDate);
      final roomNameById = await _buildRoomNameByIdMap();
      final unsyncedCount = await _countUnsyncedEdu();
      emit(state.copyWith(
          checkInOuts: checkInOuts,
          roomNameById: roomNameById,
          unsyncedCount: unsyncedCount,
          status: RequestStatus.success));
    } catch (e) {
      await pushLog('Error in loadAttendanceReport: $e');
      emit(state.copyWith(status: RequestStatus.failed, message: e.toString()));
    }
  }

  Future<void> filterCheckInOuts(DateTime date) async {
    try {
      emit(state.copyWith(status: RequestStatus.requesting));
      final checkInOuts = await _localService.getCheckInOutByDate(date);
      final roomNameById = await _buildRoomNameByIdMap();
      final unsyncedCount = await _countUnsyncedEdu();
      emit(state.copyWith(
          checkInOuts: checkInOuts,
          roomNameById: roomNameById,
          unsyncedCount: unsyncedCount,
          status: RequestStatus.success,
          filterDate: date));
    } catch (e) {
      await pushLog('Error in filterCheckInOuts: $e');
      emit(state.copyWith(status: RequestStatus.failed, message: e.toString()));
    }
  }

  /// Push all unsynced [PendingEduCheckIn] records to the backend via bulk endpoint.
  /// Fires [EduSyncCompleteEvent] on success so AttendanceHistoryBloc auto-refreshes.
  Future<void> syncToBackend() async {
    if (state.isSyncing) return; // prevent concurrent syncs
    try {
      emit(state.copyWith(isSyncing: true, syncMessage: 'Đang đồng bộ...'));

      final pending = await _localService.getPendingEduCheckIns();
      final unsyncedItems = pending.where((p) => !p.isSynced).toList();

      if (unsyncedItems.isEmpty) {
        emit(state.copyWith(
          isSyncing: false,
          syncMessage: 'Không có dữ liệu cần đồng bộ.',
          unsyncedCount: 0,
        ));
        return;
      }

      // Batch: max 50 per request (backend enforces this limit)
      const batchSize = 50;
      int totalSucceeded = 0;
      int totalFailed = 0;
      int totalSkipped = 0;

      for (var i = 0; i < unsyncedItems.length; i += batchSize) {
        final batch = unsyncedItems.skip(i).take(batchSize).toList();
        final result = await _eduSyncService.syncPendingCheckIns(batch);

        if (result.isSuccess && result.data != null) {
          final syncResult = result.data!;
          totalSucceeded += syncResult.succeeded;
          totalFailed += syncResult.failed;
          totalSkipped += syncResult.skipped;

          // Mark synced items in local store
          for (final localId in syncResult.syncedLocalIds) {
            await _localService.markEduCheckInSynced(localId);
          }
        } else {
          totalFailed += batch.length;
        }
      }

      // Clean up successfully synced records
      await _localService.clearSyncedEduCheckIns();
      final remainingUnsync = await _countUnsyncedEdu();

      final syncMsg = totalFailed == 0
          ? 'Đồng bộ thành công $totalSucceeded bản ghi'
          : 'Đồng bộ xong: $totalSucceeded thành công, $totalFailed thất bại';

      emit(state.copyWith(
        isSyncing: false,
        syncMessage: syncMsg,
        unsyncedCount: remainingUnsync,
      ));

      shareEvent(EduSyncCompleteEvent(
        succeeded: totalSucceeded,
        failed: totalFailed,
        skipped: totalSkipped,
      ));
    } catch (e) {
      await pushLog('Error in syncToBackend: $e');
      emit(state.copyWith(
        isSyncing: false,
        syncMessage: 'Lỗi đồng bộ: ${e.toString()}',
      ));
    }
  }

  Future<Map<String, String>> _buildRoomNameByIdMap() async {
    final merged = Map<String, String>.from(state.roomNameById);

    try {
      final activeRoomId = await _localService.getActiveRoomId();
      final activeRoomName = await _localService.getActiveRoomName();

      final normalizedId = activeRoomId?.trim() ?? '';
      final normalizedName = activeRoomName?.trim() ?? '';

      if (normalizedId.isNotEmpty && normalizedName.isNotEmpty) {
        merged[normalizedId] = normalizedName;
      }
    } catch (e) {
      await pushLog('Error in _buildRoomNameByIdMap: $e');
    }

    return merged;
  }

  Future<int> _countUnsyncedEdu() async {
    try {
      final pending = await _localService.getPendingEduCheckIns();
      return pending.where((p) => !p.isSynced).length;
    } catch (_) {
      return 0;
    }
  }
}
