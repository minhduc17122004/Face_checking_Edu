import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/data/remote/attendance_history_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/pages/history/bloc/attendance_history_bloc.dart';

class AttendanceHistoryPage extends StatelessWidget {
  const AttendanceHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AttendanceHistoryBloc>()..loadHistory(),
      child: const _AttendanceHistoryView(),
    );
  }
}

class _AttendanceHistoryView extends StatefulWidget {
  const _AttendanceHistoryView();

  @override
  State<_AttendanceHistoryView> createState() => _AttendanceHistoryViewState();
}

class _AttendanceHistoryViewState extends State<_AttendanceHistoryView> {
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _timeFormat = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Lịch sử điểm danh',
          style: TextStyle(
            color: AppColors.slate900,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
      ),
      body: BlocConsumer<AttendanceHistoryBloc, AttendanceHistoryState>(
        listener: (context, state) {
          if (state.requestStatus == RequestStatus.failed &&
              state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message!),
                backgroundColor: AppColors.red600,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.requestStatus == RequestStatus.requesting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 72,
                    color: AppColors.slate500.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có lịch sử điểm danh',
                    style: TextStyle(
                      color: AppColors.slate500,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context.read<AttendanceHistoryBloc>().loadHistory(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Tải lại'),
                  ),
                ],
              ),
            );
          }

          // Group items by date
          final grouped = _groupByDate(state.items);

          return RefreshIndicator(
            onRefresh: () async => context.read<AttendanceHistoryBloc>().loadHistory(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final entry = grouped.entries.elementAt(index);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date header
                    Padding(
                      padding: EdgeInsets.only(bottom: 8, top: index > 0 ? 16 : 0),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.blue,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.key,
                            style: const TextStyle(
                              color: AppColors.slate900,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${entry.value.length}',
                              style: const TextStyle(
                                color: AppColors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Items for this date
                    ...entry.value.map(_buildHistoryItem),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Map<String, List<AttendanceHistoryItem>> _groupByDate(
      List<AttendanceHistoryItem> items) {
    final grouped = <String, List<AttendanceHistoryItem>>{};
    for (final item in items) {
      final dateKey = item.sessionDate != null
          ? _dateFormat.format(item.sessionDate!)
          : _dateFormat.format(item.checkinTime);
      grouped.putIfAbsent(dateKey, () => []).add(item);
    }
    return grouped;
  }

  Widget _buildHistoryItem(AttendanceHistoryItem item) {
    Color statusColor;
    IconData statusIcon;

    switch (item.status) {
      case 'early':
        statusColor = AppColors.teal600;
        statusIcon = Icons.alarm;
        break;
      case 'on_time':
        statusColor = AppColors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'late':
        statusColor = AppColors.orange;
        statusIcon = Icons.access_time;
        break;
      case 'present':
        statusColor = AppColors.green;
        statusIcon = Icons.check;
        break;
      case 'absent':
        statusColor = AppColors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = AppColors.slate500;
        statusIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status icon
            CircleAvatar(
              radius: 20,
              backgroundColor: statusColor.withValues(alpha: 0.1),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.courseName ?? 'Không rõ học phần',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (item.studentName != null)
                    Text(
                      '${item.studentName}${item.studentCode != null ? ' (${item.studentCode})' : ''}',
                      style: const TextStyle(
                        color: AppColors.slate500,
                        fontSize: 12,
                      ),
                    ),
                  if (item.roomName != null)
                    Text(
                      'Phòng: ${item.roomName}',
                      style: const TextStyle(
                        color: AppColors.slate500,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            // Time + status badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeFormat.format(item.checkinTime.toLocal()),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (item.minutesDiff != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.minutesDiff! < 0
                          ? '${item.minutesDiff!.abs()} phút sớm'
                          : item.minutesDiff! > 0
                              ? '${item.minutesDiff!} phút trễ'
                              : 'Đúng giờ',
                      style: TextStyle(
                        color: item.minutesDiff! > 0
                            ? AppColors.orange
                            : AppColors.slate500,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
