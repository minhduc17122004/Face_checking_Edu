import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/room.dart';
import 'package:face_time_keeping/entities/room_session.dart';
import 'bloc/room_session_bloc.dart';
import 'bloc/room_session_state.dart';
import 'package:face_time_keeping/pages/checking/checking_page.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:collection/collection.dart';
import 'package:face_time_keeping/entities/course.dart';

class RoomSessionPage extends StatelessWidget {
  final Room room;

  const RoomSessionPage({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final bloc = getIt<RoomSessionBloc>()..loadRoomSessions(room.id);
    return BlocProvider.value(
      value: bloc,
      child: _RoomSessionView(bloc: bloc, room: room),
    );
  }
}

class _RoomSessionView extends StatefulWidget {
  final RoomSessionBloc bloc;
  final Room room;

  const _RoomSessionView({required this.bloc, required this.room});

  @override
  State<_RoomSessionView> createState() => _RoomSessionViewState();
}

class _RoomSessionViewState extends State<_RoomSessionView> {
  DateTime? _selectedDate;
  final LocalService _localService = getIt<LocalService>();
  bool _canManageSessions = false;
  String? _activeRoomName;

  @override
  void initState() {
    super.initState();
    _loadRoomBindingContext();
  }

  Future<void> _loadRoomBindingContext() async {
    final role = _localService.getUserRole().toLowerCase();
    final roomName = await _localService.getActiveRoomName();
    if (!mounted) return;
    setState(() {
      _canManageSessions = role == 'teacher' || role == 'admin';
      _activeRoomName = roomName;
    });
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
              widget.room.name,
              style: const TextStyle(
                color: AppColors.slate900,
                fontWeight: FontWeight.bold,
                fontSize: 20,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: AppColors.blue),
            onPressed: _showDatePicker,
          ),
        ],
      ),
      body: BlocConsumer<RoomSessionBloc, RoomSessionState>(
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
        },
        builder: (context, state) {
          if (state.requestStatus == RequestStatus.requesting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = state.sessions;
          final courses = state.courses;

          if (sessions.isEmpty && courses.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: AppColors.slate500,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Phòng này chưa có lớp học phần nào',
                    style: TextStyle(color: AppColors.slate500),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              widget.bloc.loadRoomSessions(
                widget.room.id,
                sessionDate: _selectedDate,
              );
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_activeRoomName != null && _activeRoomName!.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.room_preferences,
                            size: 16, color: AppColors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Phòng đang gán trên thiết bị: $_activeRoomName',
                            style: const TextStyle(
                              color: AppColors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_selectedDate != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt,
                            size: 16, color: AppColors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Ngày: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                          style: const TextStyle(color: AppColors.blue),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            setState(() => _selectedDate = null);
                            widget.bloc.loadRoomSessions(widget.room.id);
                          },
                          child: const Icon(Icons.close,
                              size: 18, color: AppColors.blue),
                        ),
                      ],
                    ),
                  ),

                // Active Sessions Section
                if (state.activeSessions.isNotEmpty) ...[
                  _buildSectionHeader('Đang diễn ra', AppColors.green),
                  ...state.activeSessions.map(_buildSessionCard),
                ],

                // Upcoming Sessions Section
                if (state.scheduledSessions.isNotEmpty) ...[
                  _buildSectionHeader('Sắp tới', AppColors.blue),
                  ...state.scheduledSessions.map(_buildSessionCard),
                ],

                // All Courses Section (Lớp học phần)
                if (courses.isNotEmpty) ...[
                  _buildSectionHeader('Các lớp học phần', AppColors.slate900),
                  ...courses.map((course) {
                    // Check if there is an active session for this course
                    final activeSession = sessions.firstWhereOrNull(
                        (s) => s.courseId == course.id && s.isActive);
                    final scheduledSession = sessions.firstWhereOrNull(
                        (s) => s.courseId == course.id && s.isScheduled);

                    return _buildCourseCard(
                        course, activeSession, scheduledSession);
                  }),
                ],

                // Closed Sessions Section
                if (state.closedSessions.isNotEmpty) ...[
                  _buildSectionHeader('Đã kết thúc', AppColors.slate500),
                  ...state.closedSessions.map(_buildSessionCard),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(RoomSession session) {
    Color statusColor;
    switch (session.mappedStatus) {
      case 'OPEN':
        statusColor = AppColors.green;
        break;
      case 'CLOSED':
        statusColor = AppColors.slate500;
        break;
      case 'CAN_OPEN':
        statusColor = AppColors.blue;
        break;
      default:
        statusColor = AppColors.slate500;
    }

    final canCheckIn = session.isActive && session.canCheckin;
    final bool isOutsideWindow = session.isActive && !session.canCheckin;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      color: isOutsideWindow ? Colors.grey.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOutsideWindow
            ? BorderSide(color: Colors.grey.shade300, width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: canCheckIn
            ? () {
                AppNavigator.pushNamed(
                  RouterName.checking,
                  arguments: const CheckingArgs(isCheckIn: true),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.courseName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _mappedStatusLabel(session.mappedStatus),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: AppColors.slate500),
                  const SizedBox(width: 4),
                  Text(
                    session.formattedDate,
                    style: const TextStyle(
                        color: AppColors.slate500, fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time,
                      size: 14, color: AppColors.slate500),
                  const SizedBox(width: 4),
                  Text(
                    '${session.formattedStartTime} - ${session.formattedEndTime}',
                    style: const TextStyle(
                        color: AppColors.slate500, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle,
                            size: 14, color: AppColors.green),
                        const SizedBox(width: 4),
                        Text(
                          '${session.attendanceCount}/${session.totalEnrolled}',
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (session.isActive && session.canCheckin) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.how_to_reg,
                              size: 14, color: AppColors.green),
                          SizedBox(width: 4),
                          Text(
                            'Điểm danh',
                            style: TextStyle(
                              color: AppColors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (_canManageSessions) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (session.isScheduled)
                      OutlinedButton.icon(
                        onPressed: session.canOpen
                            ? () {
                                widget.bloc.activateSession(
                                  session.id,
                                  widget.room.id,
                                  sessionDate: _selectedDate,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.play_circle_outline, size: 16),
                        label: const Text('Mở buổi'),
                      ),
                    if (session.isActive) ...[
                      OutlinedButton.icon(
                        onPressed: session.canClose
                            ? () {
                                widget.bloc.closeSession(
                                  session.id,
                                  widget.room.id,
                                  sessionDate: _selectedDate,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.stop_circle_outlined, size: 16),
                        label: const Text('Đóng buổi'),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _mappedStatusLabel(String status) {
    switch (status) {
      case 'OPEN':
        return 'OPEN';
      case 'CAN_OPEN':
        return 'CAN_OPEN';
      case 'CLOSED':
        return 'CLOSED';
      default:
        return 'NOT_OPEN';
    }
  }

  Widget _buildCourseCard(Course course, RoomSession? activeSession,
      RoomSession? scheduledSession) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: activeSession != null
            ? () {
                AppNavigator.pushNamed(
                  RouterName.checking,
                  arguments: const CheckingArgs(isCheckIn: true),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.courseName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mã lớp: ${course.courseCode}',
                      style: const TextStyle(
                        color: AppColors.slate500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getAttendanceModeBackgroundColor(
                                course.attendanceMode),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            course.attendanceMode.shortLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getAttendanceModeColor(
                                  course.attendanceMode),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.people_outline,
                            size: 14, color: AppColors.slate500),
                        const SizedBox(width: 4),
                        Text(
                          'Sĩ số: ${course.enrolledCount}',
                          style: const TextStyle(
                            color: AppColors.slate500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (course.dayOfWeek != null &&
                        course.timeSlotName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month,
                              size: 14, color: AppColors.slate500),
                          const SizedBox(width: 4),
                          Text(
                            '${_getDayLabel(course.dayOfWeek!)} - ${course.timeSlotName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (activeSession != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Vào điểm danh',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (scheduledSession != null && (scheduledSession.canOpen || scheduledSession.canClose))
                GestureDetector(
                  onTap: scheduledSession.canOpen
                      ? () {
                          widget.bloc.activateSession(
                            scheduledSession.id,
                            widget.room.id,
                            sessionDate: _selectedDate,
                          );
                        }
                      : null,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: scheduledSession.canOpen ? AppColors.blue : AppColors.slate200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      scheduledSession.canOpen ? 'Bắt đầu điểm danh' : 'Không thể mở',
                      style: TextStyle(
                        color: scheduledSession.canOpen ? Colors.white : AppColors.slate500,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.slate200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Không có tiết',
                    style: TextStyle(
                      color: AppColors.slate500,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      widget.bloc.loadRoomSessions(
        widget.room.id,
        sessionDate: picked,
      );
    }
  }

  Color _getAttendanceModeColor(AttendanceMode mode) {
    switch (mode) {
      case AttendanceMode.preset:
        return AppColors.blue600;
      case AttendanceMode.flexible:
        return AppColors.purple600;
      case AttendanceMode.custom:
        return AppColors.teal600;
    }
  }

  Color _getAttendanceModeBackgroundColor(AttendanceMode mode) {
    switch (mode) {
      case AttendanceMode.preset:
        return AppColors.blue50;
      case AttendanceMode.flexible:
        return AppColors.purple50;
      case AttendanceMode.custom:
        return AppColors.teal50;
    }
  }

  String _getDayLabel(int day) {
    const days = {
      1: 'Thứ 2',
      2: 'Thứ 3',
      3: 'Thứ 4',
      4: 'Thứ 5',
      5: 'Thứ 6',
      6: 'Thứ 7',
      7: 'Chủ Nhật',
    };
    return days[day] ?? '???';
  }
}
