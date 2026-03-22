import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/resources/styles/text_styles.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/session.dart';
import 'package:face_time_keeping/pages/session/bloc/session_bloc.dart';
import 'package:face_time_keeping/pages/session/bloc/session_state.dart';
import 'package:face_time_keeping/pages/widgets/empty_state_widget.dart';
import 'package:face_time_keeping/route/navigator.dart';

class SessionListPage extends StatelessWidget {
  final String? courseId;

  const SessionListPage({super.key, this.courseId});

  @override
  Widget build(BuildContext context) {
    final sessionBloc = getIt<SessionBloc>();
    if (courseId != null) {
      sessionBloc.loadSessions(courseId: courseId);
    } else {
      sessionBloc.loadSessions();
    }
    return BlocProvider.value(
      value: sessionBloc,
      child: _SessionListView(
        sessionBloc: sessionBloc,
        courseId: courseId,
      ),
    );
  }
}

class _SessionListView extends StatefulWidget {
  final SessionBloc sessionBloc;
  final String? courseId;

  const _SessionListView({
    required this.sessionBloc,
    this.courseId,
  });

  @override
  State<_SessionListView> createState() => _SessionListViewState();
}

class _SessionListViewState extends State<_SessionListView> {
  String _selectedFilter = 'all';

  List<Session> _filterSessions(List<Session> sessions) {
    if (_selectedFilter == 'all') return sessions;
    return sessions.where((s) {
      switch (_selectedFilter) {
        case 'scheduled':
          return s.status == SessionStatus.scheduled;
        case 'active':
          return s.status == SessionStatus.active;
        case 'closed':
          return s.status == SessionStatus.closed;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'PHIÊN ĐIỂM DANH',
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
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Tất cả',
                    isSelected: _selectedFilter == 'all',
                    onSelected: () => setState(() => _selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Đã lên lịch',
                    isSelected: _selectedFilter == 'scheduled',
                    onSelected: () => setState(() => _selectedFilter = 'scheduled'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Đang diễn ra',
                    isSelected: _selectedFilter == 'active',
                    onSelected: () => setState(() => _selectedFilter = 'active'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Đã kết thúc',
                    isSelected: _selectedFilter == 'closed',
                    onSelected: () => setState(() => _selectedFilter = 'closed'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: BlocConsumer<SessionBloc, SessionState>(
              listener: (context, state) {
                if (state.requestStatus == RequestStatus.failed &&
                    state.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: SelectableText(state.message!),
                      backgroundColor: AppColors.red600,
                    ),
                  );
                } else if (state.requestStatus == RequestStatus.success &&
                    state.selectedSession != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        state.selectedSession!.status == SessionStatus.active
                            ? 'Đã bắt đầu phiên điểm danh'
                            : 'Đã kết thúc phiên điểm danh',
                      ),
                      backgroundColor: AppColors.green600,
                    ),
                  );
                }
              },
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
                            size: 48, color: AppColors.red600),
                        const SizedBox(height: 16),
                        Text(state.message ?? 'Có lỗi xảy ra',
                            style: TextStyles.blackNormalRegular,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (widget.courseId != null) {
                              widget.sessionBloc.loadSessions(courseId: widget.courseId);
                            } else {
                              widget.sessionBloc.loadSessions();
                            }
                          },
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }

                if (state.requestStatus == RequestStatus.success) {
                  final filteredSessions = _filterSessions(state.sessions);

                  if (filteredSessions.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'Chưa có phiên điểm danh',
                      subtitle: 'Nhấn nút + để tạo phiên điểm danh mới',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredSessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final session = filteredSessions[index];
                      return _SessionCard(
                        session: session,
                        onActivate: () {
                          widget.sessionBloc.activateSession(session.id);
                        },
                        onClose: () {
                          widget.sessionBloc.closeSession(session.id);
                        },
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          AppNavigator.pushNamed('/sessions/form', arguments: {'courseId': widget.courseId});
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.blue50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.slate300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.slate500,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback onActivate;
  final VoidCallback onClose;

  const _SessionCard({
    required this.session,
    required this.onActivate,
    required this.onClose,
  });

  Color _getStatusColor() {
    switch (session.status) {
      case SessionStatus.active:
        return AppColors.green600;
      case SessionStatus.scheduled:
        return AppColors.orange;
      case SessionStatus.closed:
        return AppColors.slate500;
    }
  }

  Color _getStatusBackgroundColor() {
    switch (session.status) {
      case SessionStatus.active:
        return AppColors.green100;
      case SessionStatus.scheduled:
        return AppColors.orange50;
      case SessionStatus.closed:
        return AppColors.slate300.withOpacity(0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.courseName ?? 'ID: ${session.courseId}',
                      style: TextStyles.blackNormalBold.copyWith(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 14, color: AppColors.slate500),
                        const SizedBox(width: 4),
                        Text(
                          session.formattedDate,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.slate500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time,
                            size: 14, color: AppColors.slate500),
                        const SizedBox(width: 4),
                        Text(
                          session.formattedStartTime,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusBackgroundColor(),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  session.status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(),
                  ),
                ),
              ),
            ],
          ),
          if (session.totalCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _StatItem(
                  icon: Icons.check_circle,
                  count: session.presentCount,
                  label: 'Có mặt',
                  color: AppColors.green600,
                ),
                const SizedBox(width: 16),
                _StatItem(
                  icon: Icons.cancel,
                  count: session.absentCount,
                  label: 'Vắng',
                  color: AppColors.red600,
                ),
                const SizedBox(width: 16),
                _StatItem(
                  icon: Icons.people,
                  count: session.totalCount,
                  label: 'Tổng',
                  color: AppColors.slate500,
                ),
              ],
            ),
          ],
          if (session.status == SessionStatus.scheduled ||
              session.status == SessionStatus.active) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (session.status == SessionStatus.scheduled)
                  ElevatedButton.icon(
                    onPressed: onActivate,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Bắt đầu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                if (session.status == SessionStatus.active)
                  ElevatedButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('Kết thúc'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
