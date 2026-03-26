import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/enums/session_attendance_mode.dart';
import 'package:face_time_keeping/common/resources/index.dart';
import 'package:face_time_keeping/common/utils/widgets/spacing.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'bloc/session_management_cubit.dart';

enum SessionTabType { upcoming, active, closed }

class SessionManagementPage extends StatefulWidget {
  const SessionManagementPage({super.key});

  @override
  State<SessionManagementPage> createState() => _SessionManagementPageState();
}

class _SessionManagementPageState extends State<SessionManagementPage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          getIt<SessionManagementCubit>()..loadTeacherSessions(),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            centerTitle: true,
            title: const Text(
              'QUẢN LÝ ĐIỂM DANH',
              style: TextStyle(
                color: AppColors.slate900,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0.5,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.slate900),
              onPressed: () => Navigator.of(context).pop(),
            ),
            bottom: const TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.slate500,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelPadding: EdgeInsets.symmetric(vertical: 12),
              tabs: [
                Text('Sắp diễn ra',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text('Đang diễn ra',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text('Đã đóng',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          body: BlocBuilder<SessionManagementCubit, SessionManagementState>(
            builder: (context, state) {
              if (state.status == RequestStatus.requesting &&
                  state.sessions.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final sessions = state.sessions;

              final scheduledSessions =
                  sessions.where((s) => s.mappedStatus == 'NOT_OPEN').toList();
              final activeSessions = sessions
                  .where((s) =>
                      s.mappedStatus == 'OPEN' || s.mappedStatus == 'CAN_OPEN')
                  .toList();
              final closedSessions =
                  sessions.where((s) => s.mappedStatus == 'CLOSED').toList();

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    color: AppColors.primary.withOpacity(0.08),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Danh sách dưới đây chỉ hiển thị các phiên điểm danh của ngày hôm nay.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _SessionList(
                          sessions: scheduledSessions,
                          tabType: SessionTabType.upcoming,
                          emptyMessage: 'Không có phiên học nào sắp diễn ra hôm nay',
                        ),
                        _SessionList(
                          sessions: activeSessions,
                          tabType: SessionTabType.active,
                          emptyMessage: 'Không có phiên học nào đang diễn ra',
                        ),
                        _SessionList(
                          sessions: closedSessions,
                          tabType: SessionTabType.closed,
                          emptyMessage: 'Không có phiên học nào đã đóng',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  final List<Session> sessions;
  final SessionTabType tabType;
  final String emptyMessage;

  const _SessionList({
    required this.sessions,
    required this.tabType,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy_outlined,
                size: 64, color: AppColors.slate300),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(color: AppColors.slate500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<SessionManagementCubit>().loadTeacherSessions();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          return _SessionCard(
            session: sessions[index],
            showTitle: false,
            tabType: tabType,
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Session session;
  final bool showTitle;
  final SessionTabType tabType;

  const _SessionCard({
    required this.session,
    this.showTitle = true,
    required this.tabType,
  });

  bool get _showToggleButtons => tabType == SessionTabType.active;

  bool get _canClose => session.canClose;
  bool get _canOpen => session.canOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (session.attendanceMode != null)
                _buildAttendanceModeBadge(session.attendanceMode!)
              else
                const SizedBox.shrink(),
              _StatusBadge(mappedStatus: session.mappedStatus ?? 'NOT_OPEN'),
            ],
          ),
          const Spacing(height: 12),
          Text(
            session.courseName ?? 'N/A',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.slate900,
            ),
          ),
          const Spacing(height: 4),
          Row(
            children: [
              if (session.dayOfWeek != null) ...[
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.slate400),
                const SizedBox(width: 4),
                Text(
                  _getDayName(session.dayOfWeek!),
                  style: const TextStyle(fontSize: 13, color: AppColors.slate500),
                ),
                const SizedBox(width: 12),
              ],
              const Icon(Icons.access_time,
                  size: 16, color: AppColors.slate400),
              const SizedBox(width: 4),
              Text(
                '${DateFormat('HH:mm').format(session.startTime.toLocal())} - '
                '${DateFormat('HH:mm').format((session.endTime ?? session.startTime.add(const Duration(hours: 2))).toLocal())}',
                style: const TextStyle(fontSize: 13, color: AppColors.slate500),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.meeting_room_outlined,
                  size: 16, color: AppColors.slate400),
              const SizedBox(width: 4),
              Text(
                session.roomName ?? 'N/A',
                style: const TextStyle(fontSize: 13, color: AppColors.slate500),
              ),
            ],
          ),
          if (session.attendanceMode == SessionAttendanceMode.custom &&
              session.checkinWindowStart != null &&
              session.checkinWindowEnd != null) ...[
            const Spacing(height: 8),
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                    size: 16, color: AppColors.slate400),
                const SizedBox(width: 4),
                Text(
                  'Giờ điểm danh: ${DateFormat('HH:mm').format(session.checkinWindowStart!.toLocal())} - '
                  '${DateFormat('HH:mm').format(session.checkinWindowEnd!.toLocal())}',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.slate600,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
          const Spacing(height: 12),
          if (_showToggleButtons) ...[
            const Spacing(height: 20),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ElevatedButton(
                      onPressed:
                          _canOpen ? () => _showOpenDialog(context) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.slate200,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: AppColors.slate400,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline, size: 18),
                          SizedBox(width: 6),
                          Text('Mở điểm danh',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ElevatedButton(
                      onPressed: _canClose
                          ? () => _showCloseDialog(context)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red,
                        disabledBackgroundColor: AppColors.slate200,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: AppColors.slate400,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.stop_circle_outlined, size: 18),
                          SizedBox(width: 6),
                          Text('Đóng điểm danh',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showOpenDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mở điểm danh'),
        content: Text(
            'Bạn có chắc chắn muốn mở điểm danh cho phiên học "${session.courseName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              context
                  .read<SessionManagementCubit>()
                  .activateSession(session.id);
              Navigator.pop(ctx);
            },
            child: const Text('Mở'),
          ),
        ],
      ),
    );
  }

  void _showCloseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đóng điểm danh'),
        content: Text(
            'Bạn có chắc chắn muốn đóng điểm danh cho phiên học "${session.courseName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              context.read<SessionManagementCubit>().closeSession(session.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red, foregroundColor: Colors.white),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'Thứ 2';
      case 2:
        return 'Thứ 3';
      case 3:
        return 'Thứ 4';
      case 4:
        return 'Thứ 5';
      case 5:
        return 'Thứ 6';
      case 6:
        return 'Thứ 7';
      case 7:
        return 'Chủ nhật';
      default:
        return 'Thứ $dayOfWeek';
    }
  }

  Widget _buildAttendanceModeBadge(SessionAttendanceMode mode) {
    IconData icon;
    switch (mode) {
      case SessionAttendanceMode.preset:
        icon = Icons.timer_outlined;
        break;
      case SessionAttendanceMode.flexible:
        icon = Icons.all_inclusive;
        break;
      case SessionAttendanceMode.custom:
        icon = Icons.tune_rounded;
        break;
    }

    final color = _getModeTextColor(mode);
    final bgColor = _getModeBgColor(mode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            mode.shortLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getModeBgColor(SessionAttendanceMode mode) {
    switch (mode) {
      case SessionAttendanceMode.preset:
        return AppColors.blue50;
      case SessionAttendanceMode.flexible:
        return AppColors.purple50;
      case SessionAttendanceMode.custom:
        return AppColors.teal50;
    }
  }

  Color _getModeTextColor(SessionAttendanceMode mode) {
    switch (mode) {
      case SessionAttendanceMode.preset:
        return AppColors.blue600;
      case SessionAttendanceMode.flexible:
        return AppColors.purple600;
      case SessionAttendanceMode.custom:
        return AppColors.teal600;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String mappedStatus;

  const _StatusBadge({required this.mappedStatus});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (mappedStatus) {
      case 'OPEN':
        bgColor = AppColors.green100;
        textColor = AppColors.green600;
        label = 'Đang mở';
        break;
      case 'CLOSED':
        bgColor = AppColors.slate200;
        textColor = AppColors.slate600;
        label = 'Đã đóng';
        break;
      case 'CAN_OPEN':
        bgColor = AppColors.blue50;
        textColor = AppColors.blue600;
        label = 'Có thể mở';
        break;
      default:
        bgColor = AppColors.orange50;
        textColor = AppColors.orange600;
        label = 'Chưa thể mở';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }
}
