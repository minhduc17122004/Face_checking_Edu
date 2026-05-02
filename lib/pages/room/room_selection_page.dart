import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/enums/session_attendance_mode.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/utils/preset_checkin_policy.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/entities/room.dart';
import 'package:face_time_keeping/entities/room_session.dart';
import 'room_session/bloc/room_session_bloc.dart';
import 'room_session/bloc/room_session_state.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:face_time_keeping/pages/checking/checking_page.dart';

class RoomSelectionPage extends StatelessWidget {
  const RoomSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<RoomSessionBloc>()..loadRooms(),
      child: const _RoomSelectionView(),
    );
  }
}

class _RoomSelectionView extends StatefulWidget {
  const _RoomSelectionView();

  @override
  State<_RoomSelectionView> createState() => _RoomSelectionViewState();
}

class _RoomSelectionViewState extends State<_RoomSelectionView> {
  final LocalService _localService = getIt<LocalService>();
  String? _selectedRoomId;

  RoomSessionBloc get _bloc => context.read<RoomSessionBloc>();

  @override
  void initState() {
    super.initState();
    _loadCurrentRoomBinding();
  }

  Future<void> _loadCurrentRoomBinding() async {
    final roomId = await _localService.getActiveRoomId();
    if (!mounted) return;
    setState(() {
      _selectedRoomId = roomId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'Chọn phòng điểm danh',
          style: TextStyle(
            color: AppColors.slate900,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.slate900),
          onPressed: () => AppNavigator.pop(),
        ),
      ),
      body: BlocBuilder<RoomSessionBloc, RoomSessionState>(
        builder: (context, state) {
          if (state.requestStatus == RequestStatus.requesting &&
              state.rooms.isEmpty) {
            return _buildLoadingState();
          }

          if (state.requestStatus == RequestStatus.failed &&
              state.rooms.isEmpty) {
            return _buildErrorState(state.message);
          }

          if (state.rooms.isEmpty) {
            return _buildEmptyState();
          }

          return Stack(
            children: [
              RefreshIndicator(
                color: AppColors.blue600,
                onRefresh: _bloc.loadRooms,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildSummaryHeader(state.rooms)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      sliver: SliverList.separated(
                        itemCount: state.rooms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final room = state.rooms[index];
                          return _buildRoomCard(room);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (state.requestStatus == RequestStatus.requesting)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.blue600,
                    backgroundColor: AppColors.blue50,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 16),
          Text(
            'Đang tải danh sách phòng',
            style: TextStyle(
              color: AppColors.slate600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.red100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 34,
                color: AppColors.red600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không tải được danh sách phòng',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.slate900,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Vui lòng kiểm tra kết nối và thử lại.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.slate500,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _bloc.loadRooms,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.meeting_room_outlined,
              size: 64,
              color: AppColors.slate400,
            ),
            SizedBox(height: 14),
            Text(
              'Không có phòng được cấp phép',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.slate900,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Thiết bị này chưa được duyệt quyền điểm danh theo phòng.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(List<Room> rooms) {
    final selectedRoom = _selectedRoom(rooms);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.school_outlined,
              color: AppColors.blue600,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${rooms.length} phòng khả dụng',
                  style: const TextStyle(
                    color: AppColors.slate900,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedRoom == null
                      ? 'Chưa chọn phòng'
                      : 'Đang chọn: ${selectedRoom.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.slate500,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _bloc.loadRooms,
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.slate600,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.slate100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Room? _selectedRoom(List<Room> rooms) {
    for (final room in rooms) {
      if (room.id == _selectedRoomId) return room;
    }
    return null;
  }

  String _roomLocation(Room room) {
    final parts = <String>[];
    if (room.building != null && room.building!.trim().isNotEmpty) {
      parts.add(room.building!.trim());
    }
    if (room.floor != null) {
      parts.add('Tầng ${room.floor}');
    }
    return parts.join(' • ');
  }

  Widget _roomMetaChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.slate500),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.slate600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Room room) {
    final isSelected = _selectedRoomId == room.id;
    final location = _roomLocation(room);

    return Semantics(
      selected: isSelected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue50 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.blue600 : AppColors.slate200,
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.slate900.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _onSelectRoom(room),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.blue600 : AppColors.blue50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.meeting_room_outlined,
                    color: isSelected ? Colors.white : AppColors.blue600,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              room.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.slate900,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.blue600,
                              size: 20,
                            )
                          else
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.slate400,
                              size: 20,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (location.isNotEmpty)
                            _roomMetaChip(
                              icon: Icons.location_city_outlined,
                              text: location,
                            ),
                          if (room.capacity != null)
                            _roomMetaChip(
                              icon: Icons.groups_outlined,
                              text: '${room.capacity} chỗ',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSelectRoom(Room room) async {
    await _localService.saveActiveRoomId(room.id);
    await _localService.saveActiveRoomName(room.name);

    if (!mounted) return;
    setState(() {
      _selectedRoomId = room.id;
    });

    _bloc.loadActiveRoomSession(room.id);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => _RoomSessionDialog(
        room: room,
        bloc: _bloc,
      ),
    );
  }
}

/// Dialog that waits for sessions to load and shows the active session info
class _RoomSessionDialog extends StatelessWidget {
  final Room room;
  final RoomSessionBloc bloc;

  const _RoomSessionDialog({required this.room, required this.bloc});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoomSessionBloc, RoomSessionState>(
      bloc: bloc,
      builder: (context, state) {
        final activeSession = state.activeSession;
        final isLoading = state.requestStatus == RequestStatus.requesting ||
            !state.hasActiveSession;
        final isFailed = state.requestStatus == RequestStatus.failed &&
            state.hasActiveSession &&
            activeSession == null;
        final isClosedEarly = activeSession?.isClosedEarly ?? false;
        final isEarlyCheckIn =
            activeSession != null && _isEarlyCheckInSession(activeSession);
        final sessionForAction = activeSession;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          title: _DialogTitle(room: room),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: isLoading
                  ? _buildDialogLoading()
                  : isFailed
                      ? _buildSessionError(state.message)
                      : activeSession == null
                          ? _buildNoSession(state.message)
                          : isClosedEarly
                              ? _buildClosedSessionWarning(activeSession)
                              : _buildSessionInfo(
                                  activeSession,
                                  isEarlyCheckIn: isEarlyCheckIn,
                                ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Đóng',
                style: TextStyle(color: AppColors.slate500),
              ),
            ),
            if (sessionForAction != null && !isClosedEarly)
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  getIt<LocalService>()
                      .saveActiveCourseName(sessionForAction.courseName);
                  AppNavigator.pushNamed(
                    RouterName.checking,
                    arguments: CheckingArgs(
                      isCheckIn: true,
                      sessionId: sessionForAction.id,
                      sessionStartTime: sessionForAction.startTime,
                      lateReferenceTime: null,
                      detectEarlyStatus: isEarlyCheckIn,
                      detectLateStatus: _shouldDetectLateStatus(
                        sessionForAction,
                      ),
                    ),
                  );
                },
                icon: Icon(
                  isEarlyCheckIn
                      ? Icons.schedule_outlined
                      : Icons.face_retouching_natural,
                  size: 18,
                ),
                label:
                    Text(isEarlyCheckIn ? 'Điểm danh sớm' : 'Điểm danh ngay'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isEarlyCheckIn ? AppColors.teal600 : AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            if (sessionForAction != null && isClosedEarly)
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  getIt<LocalService>()
                      .saveActiveCourseName(sessionForAction.courseName);
                  AppNavigator.pushNamed(
                    RouterName.checking,
                    arguments: CheckingArgs(
                      isCheckIn: true,
                      sessionId: sessionForAction.id,
                      sessionStartTime: sessionForAction.startTime,
                      lateReferenceTime: sessionForAction.checkinWindowEnd ??
                          sessionForAction.endTime,
                    ),
                  );
                },
                icon: const Icon(Icons.lock_clock_outlined, size: 18),
                label: const Text('Điểm danh muộn'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDialogLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }

  Widget _buildSessionError(String? message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.red100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 36,
              color: AppColors.red600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Không tải được phiên điểm danh',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.slate900,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message ?? 'Vui lòng thử lại sau.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Warning content shown when session was manually closed early
  Widget _buildClosedSessionWarning(RoomSession session) {
    final closedAtTime = session.checkinWindowEnd ?? session.endTime;
    final closedFmt = closedAtTime != null
        ? DateFormat('HH:mm').format(closedAtTime.toLocal())
        : '--:--';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.orange50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.lock_clock_outlined,
              size: 38,
              color: AppColors.orange600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Phiên điểm danh đã đóng',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.orange600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Phiên điểm danh của học phần "${session.courseName}" đã đóng từ $closedFmt.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  bool _isEarlyCheckInSession(RoomSession session) {
    return isWithinPresetEarlyCheckInWindow(session);
  }

  bool _shouldDetectLateStatus(RoomSession session) {
    return session.attendanceMode == SessionAttendanceMode.preset;
  }

  Widget _buildNoSession(String? message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.orange50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.event_busy_outlined,
              size: 40,
              color: AppColors.orange600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Không có phiên điểm danh',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message ?? 'Hiện không có phiên học nào đang mở tại phòng này.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfo(
    RoomSession session, {
    required bool isEarlyCheckIn,
  }) {
    final startFmt = DateFormat('HH:mm').format(session.startTime.toLocal());
    final endFmt = session.endTime != null
        ? DateFormat('HH:mm').format(session.endTime!.toLocal())
        : '--:--';
    final checkinStartFmt = session.checkinWindowStart != null
        ? DateFormat('HH:mm').format(session.checkinWindowStart!.toLocal())
        : null;
    final checkinEndFmt = session.checkinWindowEnd != null
        ? DateFormat('HH:mm').format(session.checkinWindowEnd!.toLocal())
        : null;

    final mode = _attendanceModeData(session.attendanceMode);
    final earlyStartFmt = isEarlyCheckIn
        ? DateFormat('HH:mm').format(
            session.startTime.toLocal().subtract(presetEarlyCheckInWindow),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusPill(
            icon: isEarlyCheckIn ? Icons.schedule_outlined : Icons.circle,
            text:
                isEarlyCheckIn ? 'Cho phép điểm danh sớm' : 'Đang mở điểm danh',
            backgroundColor:
                isEarlyCheckIn ? AppColors.teal50 : AppColors.green100,
            foregroundColor:
                isEarlyCheckIn ? AppColors.teal600 : AppColors.green600,
          ),
          const SizedBox(height: 14),
          Text(
            session.courseCode != null
                ? '${session.courseName} (${session.courseCode})'
                : session.courseName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.access_time,
            label: 'Giờ học',
            value: '$startFmt – $endFmt',
          ),
          if (checkinStartFmt != null && checkinEndFmt != null)
            _InfoTile(
              icon: Icons.how_to_reg_outlined,
              label: 'Cửa điểm danh',
              value: '$checkinStartFmt – $checkinEndFmt',
            ),
          if (isEarlyCheckIn)
            _InfoTile(
              icon: Icons.schedule_outlined,
              label: 'Cửa điểm danh sớm',
              value: '$earlyStartFmt – $startFmt',
            ),
          if (session.teacherName != null)
            _InfoTile(
              icon: Icons.co_present_outlined,
              label: 'Giáo viên',
              value: session.teacherName!,
            ),
          _InfoTile(
            icon: Icons.people_outline,
            label: 'Sĩ số',
            value: '${session.totalEnrolled} sinh viên',
          ),
          const SizedBox(height: 4),
          _StatusPill(
            icon: mode.icon,
            text: mode.label,
            backgroundColor: mode.backgroundColor,
            foregroundColor: mode.foregroundColor,
          ),
        ],
      ),
    );
  }

  _ModeData _attendanceModeData(SessionAttendanceMode? mode) {
    switch (mode) {
      case SessionAttendanceMode.preset:
        return const _ModeData(
          label: 'Cố định',
          icon: Icons.timer_outlined,
          backgroundColor: AppColors.blue50,
          foregroundColor: AppColors.blue600,
        );
      case SessionAttendanceMode.custom:
        return const _ModeData(
          label: 'Tự thiết lập',
          icon: Icons.tune_rounded,
          backgroundColor: AppColors.teal50,
          foregroundColor: AppColors.teal600,
        );
      default:
        return const _ModeData(
          label: 'Linh hoạt',
          icon: Icons.all_inclusive,
          backgroundColor: AppColors.purple50,
          foregroundColor: AppColors.purple600,
        );
    }
  }
}

class _DialogTitle extends StatelessWidget {
  final Room room;

  const _DialogTitle({required this.room});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.meeting_room_outlined,
            color: AppColors.blue600,
            size: 24,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                room.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: AppColors.slate600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.slate400,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.slate700,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color foregroundColor;

  const _StatusPill({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foregroundColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeData {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  const _ModeData({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });
}
