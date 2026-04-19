import 'package:face_time_keeping/entities/sync_face_schedule.dart';
import 'package:face_time_keeping/common/enums/server_type.dart';

class SettingState {
  final bool isLoading;
  final SyncFaceSchedule? syncFaceSchedule;
  final ServerType? serverType;
  final String? userRole;

  SettingState({
    this.isLoading = false,
    this.syncFaceSchedule,
    this.serverType,
    this.userRole,
  });

  SettingState copyWith({
    bool? isLoading,
    SyncFaceSchedule? syncFaceSchedule,
    ServerType? serverType,
    String? userRole,
  }) {
    return SettingState(
      isLoading: isLoading ?? this.isLoading,
      syncFaceSchedule: syncFaceSchedule ?? this.syncFaceSchedule,
      serverType: serverType ?? this.serverType,
      userRole: userRole ?? this.userRole,
    );
  }

  bool get isAdmin => userRole?.toLowerCase() == 'admin';
}
