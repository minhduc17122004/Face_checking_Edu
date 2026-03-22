import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/resources/styles/text_styles.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/session.dart';
import 'package:face_time_keeping/pages/checking/checking_page.dart';
import 'package:face_time_keeping/pages/session/bloc/session_bloc.dart';
import 'package:face_time_keeping/pages/session/bloc/session_state.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';

class SessionDetailPage extends StatelessWidget {
  final Session session;

  const SessionDetailPage({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SessionBloc>(),
      child: _SessionDetailView(initialSession: session),
    );
  }
}

class _SessionDetailView extends StatefulWidget {
  final Session initialSession;

  const _SessionDetailView({required this.initialSession});

  @override
  State<_SessionDetailView> createState() => _SessionDetailViewState();
}

class _SessionDetailViewState extends State<_SessionDetailView> {
  late Session _session;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
  }

  Color _getStatusColor() {
    switch (_session.status) {
      case SessionStatus.active:
        return AppColors.green600;
      case SessionStatus.scheduled:
        return AppColors.orange;
      case SessionStatus.closed:
        return AppColors.slate500;
    }
  }

  Color _getStatusBackgroundColor() {
    switch (_session.status) {
      case SessionStatus.active:
        return AppColors.green100;
      case SessionStatus.scheduled:
        return AppColors.orange50;
      case SessionStatus.closed:
        return AppColors.slate300.withOpacity(0.3);
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'CHI TIẾT PHIÊN ĐIỂM DANH',
          style: TextStyle(
            color: AppColors.slate900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.slate900),
          onPressed: () => AppNavigator.pop(),
        ),
      ),
      body: BlocListener<SessionBloc, SessionState>(
        listener: (context, state) {
          if (state.requestStatus == RequestStatus.success &&
              state.selectedSession != null) {
            setState(() => _session = state.selectedSession!);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _session.status == SessionStatus.active
                      ? 'Đã bắt đầu phiên điểm danh'
                      : 'Đã kết thúc phiên điểm danh',
                ),
                backgroundColor: AppColors.green600,
              ),
            );
          } else if (state.requestStatus == RequestStatus.failed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: SelectableText(state.message ?? 'Có lỗi xảy ra'),
                backgroundColor: AppColors.red600,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 16),
              _buildAttendanceWindowCard(),
              const SizedBox(height: 16),
              _buildStatsCard(),
              const SizedBox(height: 16),
              _buildActionCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school,
                  color: AppColors.blue600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _session.courseName ?? 'ID: ${_session.courseId}',
                      style: TextStyles.blackNormalBold,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusBackgroundColor(),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _session.status.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _InfoItem(
                  icon: Icons.calendar_today,
                  label: 'Ngày',
                  value: _session.formattedDate.isNotEmpty
                      ? _session.formattedDate
                      : '--/--/----',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.slate200,
              ),
              Expanded(
                child: _InfoItem(
                  icon: Icons.access_time,
                  label: 'Giờ bắt đầu',
                  value: _session.formattedStartTime,
                ),
              ),
              if (_session.endTime != null) ...[
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.slate200,
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.access_time_filled,
                    label: 'Giờ kết thúc',
                    value: _session.formattedEndTime,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceWindowCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: AppColors.blue600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Cửa sổ điểm danh',
                style: TextStyles.blackSmallBold.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bắt đầu',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.slate500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(_session.checkinWindowStart),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward, color: AppColors.slate400),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.orange50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kết thúc',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.slate500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(_session.checkinWindowEnd),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: AppColors.blue600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Thống kê',
                style: TextStyles.blackSmallBold.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle,
                  count: _session.presentCount,
                  label: 'Có mặt',
                  color: AppColors.green600,
                  backgroundColor: AppColors.green100,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.cancel,
                  count: _session.absentCount,
                  label: 'Vắng',
                  color: AppColors.red600,
                  backgroundColor: AppColors.red100,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.people,
                  count: _session.totalCount,
                  label: 'Tổng sĩ số',
                  color: AppColors.slate500,
                  backgroundColor: AppColors.slate200,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        final isLoading = state.requestStatus == RequestStatus.requesting;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_session.status == SessionStatus.scheduled) ...[
                ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () {
                          context
                              .read<SessionBloc>()
                              .activateSession(_session.id);
                        },
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Bắt đầu điểm danh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    AppNavigator.pushNamed(RouterName.checking,
                        arguments: CheckingArgs(isCheckIn: true, sessionId: _session.id));
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Điểm danh ngay'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.blue600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.blue600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else if (_session.status == SessionStatus.active) ...[
                ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () {
                          context
                              .read<SessionBloc>()
                              .closeSession(_session.id);
                        },
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.stop),
                  label: const Text('Kết thúc điểm danh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    AppNavigator.pushNamed(RouterName.checking,
                        arguments: CheckingArgs(isCheckIn: true, sessionId: _session.id));
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Tiếp tục điểm danh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.slate200.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.slate500),
                      SizedBox(width: 8),
                      Text(
                        'Phiên điểm danh đã kết thúc',
                        style: TextStyle(
                          color: AppColors.slate500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.slate500),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.slate500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.slate900,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;
  final Color backgroundColor;

  const _StatCard({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.slate500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
