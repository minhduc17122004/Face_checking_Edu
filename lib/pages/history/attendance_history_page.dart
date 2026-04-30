import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:face_time_keeping/pages/course/bloc/course_bloc.dart';
import 'package:face_time_keeping/pages/course/bloc/course_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child:
                  BlocConsumer<AttendanceHistoryBloc, AttendanceHistoryState>(
                listener: (context, state) {
                  if (state.requestStatus == RequestStatus.failed &&
                      state.message != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(state.message!)),
                          ],
                        ),
                        backgroundColor: AppColors.red600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  if (state.requestStatus == RequestStatus.requesting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.5,
                      ),
                    );
                  }

                  if (state.items.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  final grouped = _groupByDate(state.items);

                  return RefreshIndicator(
                    onRefresh: () async =>
                        context.read<AttendanceHistoryBloc>().loadHistory(),
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final entry = grouped.entries.elementAt(index);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDateHeader(entry.key, entry.value.length,
                                isFirst: index == 0),
                            ...entry.value.map(_buildHistoryItem),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header (matches home_page style) ─────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.slate200, width: 0.5),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: AppColors.slate900),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const Text(
            'LỊCH SỬ ĐIỂM DANH',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.slate900,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => _showExportDialog(context),
              icon: const Icon(Icons.file_download, color: AppColors.primary),
              tooltip: 'Xuất dữ liệu',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_edu_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa có lịch sử',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Các buổi điểm danh của bạn\nsẽ xuất hiện tại đây',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.slate500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  context.read<AttendanceHistoryBloc>().loadHistory(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(
                'Tải lại',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Date section header ───────────────────────────────────
  Widget _buildDateHeader(String date, int count, {bool isFirst = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10, top: isFirst ? 16 : 20),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            date,
            style: const TextStyle(
              color: AppColors.slate900,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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

  // ── History card ──────────────────────────────────────────
  Widget _buildHistoryItem(AttendanceHistoryItem item) {
    Color statusColor;
    IconData statusIcon;
    Color iconBg;

    if (item.isSpoof) {
      // Spoof override — always red warning style
      statusColor = AppColors.red600;
      iconBg = AppColors.red100;
      statusIcon = Icons.warning_amber_rounded;
    } else {
      switch (item.status) {
        case 'early':
          statusColor = AppColors.teal600;
          iconBg = AppColors.teal50;
          statusIcon = Icons.alarm;
          break;
        case 'on_time':
          statusColor = AppColors.green600;
          iconBg = AppColors.green100;
          statusIcon = Icons.check_circle;
          break;
        case 'late':
          statusColor = AppColors.orange;
          iconBg = AppColors.orange50;
          statusIcon = Icons.access_time_filled;
          break;
        case 'present':
          statusColor = AppColors.green600;
          iconBg = AppColors.green100;
          statusIcon = Icons.check_circle;
          break;
        case 'absent':
          statusColor = AppColors.red600;
          iconBg = AppColors.red100;
          statusIcon = Icons.cancel;
          break;
        default:
          statusColor = AppColors.slate500;
          iconBg = AppColors.slate200;
          statusIcon = Icons.help_outline;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: item.isSpoof
            ? Border.all(color: AppColors.red.withOpacity(0.4), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.courseName ?? 'Không rõ học phần',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.slate900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.studentName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${item.studentName}${item.studentCode != null ? ' • ${item.studentCode}' : ''}',
                      style: const TextStyle(
                        color: AppColors.slate500,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (item.roomName != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.meeting_room_outlined,
                            size: 11, color: AppColors.slate500),
                        const SizedBox(width: 3),
                        Text(
                          item.roomName!,
                          style: const TextStyle(
                            color: AppColors.slate500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Time + badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeFormat.format(item.checkinTime.toLocal()),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    item.isSpoof ? 'Giả mạo' : item.statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (item.minutesDiff != null && item.minutesDiff != 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.minutesDiff! < 0
                        ? '${item.minutesDiff!.abs()} phút sớm'
                        : '${item.minutesDiff!} phút trễ',
                    style: TextStyle(
                      color: item.minutesDiff! > 0
                          ? AppColors.orange
                          : AppColors.slate500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    final courseBloc = getIt<CourseBloc>();
    final role = getIt<LocalService>().getUserRole().toLowerCase();
    courseBloc.loadCourses(mine: role != 'admin');

    String? selectedCourseId;
    String? selectedCourseName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Xuất dữ liệu điểm danh',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BlocBuilder<CourseBloc, CourseState>(
                  bloc: courseBloc,
                  builder: (context, state) {
                    return DropdownButtonFormField<String?>(
                      value: selectedCourseId,
                      decoration:
                          const InputDecoration(labelText: 'Lọc theo học phần'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Tất cả học phần')),
                        ...state.courses.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.courseName,
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) => setState(() {
                        selectedCourseId = val;
                        selectedCourseName = state.courses
                            .where((c) => c.id == val)
                            .firstOrNull
                            ?.courseName;
                      }),
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _performExport(
                        courseId: selectedCourseId,
                        courseName: selectedCourseName,
                        format: 'csv',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Xuất tất cả (CSV)'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        Navigator.pop(ctx);
                        _performExport(
                          courseId: selectedCourseId,
                          courseName: selectedCourseName,
                          fromDate: date,
                          format: 'csv',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.date_range),
                    label: const Text('Xuất từ ngày (CSV)'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _performExport(
                        courseId: selectedCourseId,
                        courseName: selectedCourseName,
                        format: 'excel',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Xuất tất cả (Excel)'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        Navigator.pop(ctx);
                        _performExport(
                          courseId: selectedCourseId,
                          courseName: selectedCourseName,
                          fromDate: date,
                          format: 'excel',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.date_range),
                    label: const Text('Xuất từ ngày (Excel)'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: AppColors.slate500),
              child: const Text('Hủy'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performExport({
    String? courseId,
    String? courseName,
    DateTime? fromDate,
    required String format,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text('Đang tải file...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final service = getIt<AttendanceHistoryService>();
      final result = await service.downloadExportFile(
        courseId: courseId,
        fromDate: fromDate,
        toDate: DateTime.now(),
        format: format,
        courseName: courseName,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Đóng thẻ tải

      if (result.error == null && result.data != null) {
        await Share.shareXFiles(
          [XFile(result.data!)],
          text: 'Báo Cáo Điểm Danh',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Xuất file sẵn sàng!'),
              backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result.error ?? 'Xuất file thất bại'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Đóng thẻ tải nếu lỗi ngầm định
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Có lỗi xảy ra: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
