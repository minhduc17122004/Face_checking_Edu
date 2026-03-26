import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/data/remote/attendance_checkin_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/attendance_record_ui.dart';
import 'package:face_time_keeping/entities/room_session.dart';
import 'package:face_time_keeping/pages/attendance_checkin/bloc/attendance_checkin_bloc.dart';
import 'package:face_time_keeping/pages/attendance_checkin/bloc/attendance_checkin_state.dart';
import 'package:face_time_keeping/route/navigator.dart';

class AttendanceCheckinArgs {
  final RoomSession session;

  const AttendanceCheckinArgs({required this.session});
}

class AttendanceCheckinPage extends StatelessWidget {
  final AttendanceCheckinArgs args;

  const AttendanceCheckinPage({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final bloc = getIt<AttendanceCheckinBloc>()
      ..loadSessionCheckins(args.session.id)
      ..loadSessionSummary(args.session.id);
    return BlocProvider.value(
      value: bloc,
      child: _AttendanceCheckinView(bloc: bloc, session: args.session),
    );
  }
}

class _AttendanceCheckinView extends StatefulWidget {
  final AttendanceCheckinBloc bloc;
  final RoomSession session;

  const _AttendanceCheckinView({required this.bloc, required this.session});

  @override
  State<_AttendanceCheckinView> createState() => _AttendanceCheckinViewState();
}

class _AttendanceCheckinViewState extends State<_AttendanceCheckinView> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      widget.bloc.loadSessionCheckins(widget.session.id);
      widget.bloc.loadSessionSummary(widget.session.id);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            Text(
              widget.session.courseName,
              style: const TextStyle(
                color: AppColors.slate900,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '${widget.session.formattedDate} • ${widget.session.formattedStartTime}',
              style: const TextStyle(
                color: AppColors.slate500,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.slate900),
          onPressed: () => AppNavigator.pop(),
        ),
      ),
      body: BlocConsumer<AttendanceCheckinBloc, AttendanceCheckinState>(
        listener: (context, state) {
          if (state.requestStatus == RequestStatus.failed &&
              state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: SelectableText(state.message!),
                backgroundColor: AppColors.red600,
              ),
            );
          }
          if (state.lastCheckin != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.lastCheckin!.message),
                backgroundColor: AppColors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              if (state.summary != null) _buildSummaryCard(state.summary!),
              Expanded(
                child: _buildRecordsList(state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(AttendanceCheckinSummary summary) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Sớm',
                '${summary.early}',
                AppColors.teal600,
              ),
              _buildStatItem(
                'Đúng giờ',
                '${summary.onTime}',
                AppColors.green,
              ),
              _buildStatItem(
                'Trễ',
                '${summary.late}',
                AppColors.orange,
              ),
              _buildStatItem(
                'Vắng',
                '${summary.absent}',
                AppColors.red,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: summary.attendanceRate / 100,
              backgroundColor: AppColors.slate200,
              valueColor: AlwaysStoppedAnimation(
                summary.attendanceRate >= 80
                    ? AppColors.green
                    : summary.attendanceRate >= 50
                        ? AppColors.orange
                        : AppColors.red,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tỷ lệ điểm danh: ${summary.attendanceRate.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: AppColors.slate500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.slate500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordsList(AttendanceCheckinState state) {
    if (state.requestStatus == RequestStatus.requesting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.records.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.how_to_reg, size: 64, color: AppColors.slate500),
            SizedBox(height: 16),
            Text(
              'Chưa có sinh viên điểm danh',
              style: TextStyle(color: AppColors.slate500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        widget.bloc.loadSessionCheckins(widget.session.id);
        widget.bloc.loadSessionSummary(widget.session.id);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.records.length,
        itemBuilder: (context, index) {
          final record = state.records[index];
          return _buildRecordItem(record);
        },
      ),
    );
  }

  Widget _buildRecordItem(AttendanceRecordUI record) {
    Color color;
    IconData icon;
    String label;

    if (record.isEarly) {
      color = AppColors.teal600;
      icon = Icons.alarm;
      label = 'Sớm';
    } else if (record.isOnTime) {
      color = AppColors.green;
      icon = Icons.check;
      label = 'Đúng giờ';
    } else if (record.isLate) {
      color = AppColors.orange;
      icon = Icons.access_time;
      label = 'Trễ';
    } else if (record.isPresent) {
      color = AppColors.green;
      icon = Icons.check;
      label = 'Có mặt';
    } else {
      color = AppColors.slate500;
      icon = Icons.help_outline;
      label = record.status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          record.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          record.studentCode ?? label,
          style: const TextStyle(color: AppColors.slate500, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              record.formattedCheckinTime,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (record.minutesDiff != null)
              Text(
                record.minutesDiffLabel,
                style: TextStyle(
                  color: record.isLate ? AppColors.orange : AppColors.slate500,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
