import 'package:face_time_keeping/entities/sync_face_schedule.dart';
import 'package:flutter/material.dart';
import 'package:face_time_keeping/common/enums/server_type.dart';

class SettingState {
  final bool isLoading;
  final SyncFaceSchedule? syncFaceSchedule;
  final Map<String, TimeOfDay>? shiftTimes;
  final ServerType? serverType;
  final String? userRole;

  SettingState({
    this.isLoading = false,
    this.syncFaceSchedule,
    this.shiftTimes,
    this.serverType,
    this.userRole,
  });

  SettingState copyWith({
    bool? isLoading,
    SyncFaceSchedule? syncFaceSchedule,
    Map<String, TimeOfDay>? shiftTimes,
    ServerType? serverType,
    String? userRole,
  }) {
    return SettingState(
      isLoading: isLoading ?? this.isLoading,
      syncFaceSchedule: syncFaceSchedule ?? this.syncFaceSchedule,
      shiftTimes: shiftTimes ?? this.shiftTimes,
      serverType: serverType ?? this.serverType,
      userRole: userRole ?? this.userRole,
    );
  }

  bool get isAdmin => userRole?.toLowerCase() == 'admin';
}
