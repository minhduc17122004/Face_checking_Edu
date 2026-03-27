import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/enums/session_attendance_mode.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
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
    final bloc = getIt<RoomSessionBloc>()..loadRooms();
    return BlocProvider.value(
      value: bloc,
      child: _RoomSelectionView(bloc: bloc),
    );
  }
}

class _RoomSelectionView extends StatefulWidget {
  final RoomSessionBloc bloc;

  const _RoomSelectionView({required this.bloc});

  @override
  State<_RoomSelectionView> createState() => _RoomSelectionViewState();
}

class _RoomSelectionViewState extends State<_RoomSelectionView> {
  final LocalService _localService = getIt<LocalService>();
  String? _selectedRoomId;

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
        centerTitle: true,
        title: const Text(
          'CHỌN PHÒNG ĐIỂM DANH',
          style: TextStyle(
            color: AppColors.slate900,
            fontWeight: FontWeight.bold,
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
          if (state.requestStatus == RequestStatus.requesting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.requestStatus == RequestStatus.failed) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.red),
                  const SizedBox(height: 16),
                  Text(state.message ?? 'Lỗi tải danh sách phòng'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => widget.bloc.loadRooms(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (state.rooms.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.meeting_room_outlined,
                      size: 64, color: AppColors.slate500),
                  SizedBox(height: 16),
                  Text('Không có phòng nào được cấp phép',
                      style: TextStyle(color: AppColors.slate500)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => widget.bloc.loadRooms(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.rooms.length,
              itemBuilder: (context, index) {
                final room = state.rooms[index];
                return _buildRoomCard(room);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoomCard(Room room) {
    final isSelected = _selectedRoomId == room.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.blue : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: () => _onSelectRoom(room),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Radio<String>(
                value: room.id,
                groupValue: _selectedRoomId,
                onChanged: (_) => _onSelectRoom(room),
                activeColor: AppColors.blue,
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.meeting_room,
                    color: AppColors.blue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.slate500),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSelectRoom(Room room) async {
    // Save room selection first
    await _localService.saveActiveRoomId(room.id);
    await _localService.saveActiveRoomName(room.name);

    if (!mounted) return;
    setState(() {
      _selectedRoomId = room.id;
    });

    // Load active session for this room to find exactly 1 record
    widget.bloc.loadActiveRoomSession(room.id);

    if (!mounted) return;

    // Show session info popup
    await showDialog<void>(
      context: context,
      builder: (ctx) => _RoomSessionDialog(
        room: room,
        bloc: widget.bloc,
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
        if (state.requestStatus == RequestStatus.requesting ||
            !state.hasActiveSession) {
          return const AlertDialog(
            content: SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final activeSession = state.activeSession;
        final isClosedEarly = activeSession?.isClosedEarly ?? false;

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.meeting_room,
                    color: AppColors.blue, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  room.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate900,
                  ),
                ),
              ),
            ],
          ),
          content: activeSession == null
              ? _buildNoSession()
              : isClosedEarly
                  ? _buildClosedSessionWarning(activeSession)
                  : _buildSessionInfo(activeSession),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng',
                  style: TextStyle(color: AppColors.slate500)),
            ),
            if (activeSession != null && !isClosedEarly)
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  AppNavigator.pushNamed(
                    RouterName.checking,
                    arguments: CheckingArgs(
                      isCheckIn: true,
                      sessionId: activeSession.id,
                      // Active session → always on-time, no lateReferenceTime
                      sessionStartTime: activeSession.startTime,
                      lateReferenceTime: null,
                    ),
                  );
                },
                icon: const Icon(Icons.face_retouching_natural, size: 18),
                label: const Text('Điểm danh ngay'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            if (activeSession != null && isClosedEarly)
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(); // close session dialog
                  AppNavigator.pushNamed(
                    RouterName.checking,
                    arguments: CheckingArgs(
                      isCheckIn: true,
                      sessionId: activeSession.id,
                      sessionStartTime: activeSession.startTime,
                      // Use checkinWindowEnd (or endTime) as the late reference point
                      lateReferenceTime: activeSession.checkinWindowEnd ??
                          activeSession.endTime,
                    ),
                  );
                },
                label: const Text('Điểm danh muộn'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        );
      },
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
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.lock_clock_outlined,
                size: 40, color: Colors.orange.shade700),
          ),
          const SizedBox(height: 12),
          Text(
            'Phiên điểm danh đã đóng',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Phiên điểm danh của học phần\n"${session.courseName}"\nhiện tại đã đóng từ $closedFmt.\nBạn có muốn tiếp tục điểm danh không?',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSession() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.orange50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.event_busy_outlined,
                size: 40, color: AppColors.orange600),
          ),
          const SizedBox(height: 12),
          const Text(
            'Không có phiên điểm danh',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hiện không có phiên học nào đang mở tại phòng này.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.slate500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfo(RoomSession session) {
    final startFmt = DateFormat('HH:mm').format(session.startTime.toLocal());
    final endFmt = session.endTime != null
        ? DateFormat('HH:mm').format(session.endTime!.toLocal())
        : '--:--';

    Color modeBg;
    Color modeColor;
    String modeLabel;
    IconData modeIcon;
    switch (session.attendanceMode) {
      case SessionAttendanceMode.preset:
        modeBg = AppColors.blue50;
        modeColor = AppColors.blue600;
        modeLabel = 'Cố định';
        modeIcon = Icons.timer_outlined;
        break;
      case SessionAttendanceMode.custom:
        modeBg = AppColors.teal50;
        modeColor = AppColors.teal600;
        modeLabel = 'Tự thiết lập';
        modeIcon = Icons.tune_rounded;
        break;
      default:
        modeBg = AppColors.purple50;
        modeColor = AppColors.purple600;
        modeLabel = 'Linh hoạt';
        modeIcon = Icons.all_inclusive;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.green100,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.green600,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Đang mở điểm danh',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Course name
          Text(
            session.courseName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 10),
          // Time info
          _infoRow(Icons.access_time, '$startFmt – $endFmt'),
          const SizedBox(height: 6),
          if (session.attendanceMode == SessionAttendanceMode.custom &&
              session.checkinWindowStart != null &&
              session.checkinWindowEnd != null) ...[
            _infoRow(
              Icons.timer_outlined,
              'Giờ điểm danh: ${DateFormat('HH:mm').format(session.checkinWindowStart!.toLocal())} – ${DateFormat('HH:mm').format(session.checkinWindowEnd!.toLocal())}',
            ),
            const SizedBox(height: 6),
          ],
          // Attendance mode
          Row(
            children: [
              const Icon(Icons.school_outlined,
                  size: 16, color: AppColors.slate400),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: modeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(modeIcon, size: 13, color: modeColor),
                    const SizedBox(width: 4),
                    Text(
                      modeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: modeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Attendance count
          // _infoRow(
          // Icons.people_outline,
          // // '${session.attendanceCount} / ${session.totalEnrolled} sinh viên đã điểm danh',
          // ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.slate400),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.slate600),
          ),
        ),
      ],
    );
  }
}
