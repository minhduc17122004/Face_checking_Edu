import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/schedule.dart';
import 'package:face_time_keeping/entities/time_slot.dart';
import 'package:face_time_keeping/pages/schedule/bloc/schedule_bloc.dart';
import 'package:face_time_keeping/pages/schedule/bloc/schedule_state.dart';
import 'package:face_time_keeping/pages/widgets/empty_state_widget.dart';
import 'package:face_time_keeping/route/navigator.dart';

class SchedulePage extends StatelessWidget {
  final String courseId;

  const SchedulePage({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    final scheduleBloc = getIt<ScheduleBloc>();
    scheduleBloc.loadTimeSlots();
    scheduleBloc.loadSchedules(courseId: courseId);
    return BlocProvider.value(
      value: scheduleBloc,
      child: _ScheduleView(
        scheduleBloc: scheduleBloc,
        courseId: courseId,
      ),
    );
  }
}

class _ScheduleView extends StatefulWidget {
  final ScheduleBloc scheduleBloc;
  final String courseId;

  const _ScheduleView({
    required this.scheduleBloc,
    required this.courseId,
  });

  @override
  State<_ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<_ScheduleView> {
  int _selectedDay = 2;

  static const List<Map<String, dynamic>> _dayOptions = [
    {'value': 1, 'label': 'Thứ 2'},
    {'value': 2, 'label': 'Thứ 3'},
    {'value': 3, 'label': 'Thứ 4'},
    {'value': 4, 'label': 'Thứ 5'},
    {'value': 5, 'label': 'Thứ 6'},
    {'value': 6, 'label': 'Thứ 7'},
  ];

  List<TimeSlot> _timeSlots = TimeSlotConfig.defaultSlots;

  void _showAddScheduleSheet(BuildContext context) {
    int selectedDay = _selectedDay;
    TimeSlot? selectedSlot;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thêm lịch học',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ngày trong tuần',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<int>(
                  value: selectedDay,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _dayOptions.map((day) {
                    return DropdownMenuItem<int>(
                      value: day['value'] as int,
                      child: Text(day['label'] as String),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => selectedDay = value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tiết học',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<TimeSlot>(
                  value: selectedSlot,
                  isExpanded: true,
                  hint: const Text('Chọn tiết học'),
                  underline: const SizedBox(),
                  items: _timeSlots.map((slot) {
                    return DropdownMenuItem<TimeSlot>(
                      value: slot,
                      child: Text('${slot.slotName}: ${slot.displayTime}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setSheetState(() => selectedSlot = value);
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: selectedSlot == null
                      ? null
                      : () {
                          Navigator.pop(sheetContext);
                          widget.scheduleBloc.createSchedule(
                                courseId: widget.courseId,
                                dayOfWeek: selectedDay,
                                timeSlotId: selectedSlot!.id,
                              );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Thêm lịch',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Schedule schedule) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa lịch học'),
        content: Text(
          'Bạn có chắc muốn xóa lịch "${schedule.dayName}" - '
          '${schedule.timeSlot?.slotName ?? 'Tiết ${schedule.timeSlotId}'} không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.scheduleBloc.deleteSchedule(
                    id: schedule.id,
                    courseId: widget.courseId,
                  );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'LỊCH HỌC',
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
      body: BlocConsumer<ScheduleBloc, ScheduleState>(
        listener: (context, state) {
          if (state.requestStatus == RequestStatus.success &&
              state.timeSlots.isNotEmpty) {
            setState(() {
              _timeSlots = state.timeSlots;
            });
          }
        },
        builder: (context, state) {
          if (state.requestStatus == RequestStatus.requesting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state.requestStatus == RequestStatus.failed) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SelectableText.rich(
                    TextSpan(
                      text: state.message ?? 'Có lỗi xảy ra',
                      style: const TextStyle(color: AppColors.red),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      widget.scheduleBloc.loadSchedules(courseId: widget.courseId);
                    },
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          List<Schedule> schedules = [];
          if (state.requestStatus == RequestStatus.success) {
            schedules = state.schedules;
          }

          return Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: _dayOptions.map((day) {
                      final isSelected = _selectedDay == day['value'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(day['label'] as String),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedDay = day['value'] as int);
                            }
                          },
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.grey[100],
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.slate900,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _buildScheduleList(schedules),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddScheduleSheet(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildScheduleList(List<Schedule> allSchedules) {
    final filteredSchedules =
        allSchedules.where((s) => s.dayOfWeek == _selectedDay).toList();

    if (filteredSchedules.isEmpty) {
      return const EmptyStateWidget(
        title: 'Không có lịch học',
        subtitle: 'Nhấn nút + để thêm lịch học cho ngày này',
      );
    }

    final sortedSchedules = List<Schedule>.from(filteredSchedules)
      ..sort((a, b) => a.timeSlotId.compareTo(b.timeSlotId));

    return RefreshIndicator(
      onRefresh: () async {
        widget.scheduleBloc.loadSchedules(courseId: widget.courseId);
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sortedSchedules.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final schedule = sortedSchedules[index];
          return _ScheduleCard(
            scheduleBloc: widget.scheduleBloc,
            courseId: widget.courseId,
            schedule: schedule,
            onDelete: () => _showDeleteConfirmation(context, schedule),
          );
        },
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final ScheduleBloc scheduleBloc;
  final String courseId;
  final Schedule schedule;
  final VoidCallback onDelete;

  const _ScheduleCard({
    required this.scheduleBloc,
    required this.courseId,
    required this.schedule,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final timeSlot = schedule.timeSlot;
    final slotDisplay = timeSlot != null
        ? '${timeSlot.slotName}: ${timeSlot.displayTime}'
        : 'Tiết ${schedule.timeSlotId}';

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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.schedule,
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
                  schedule.dayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  slotDisplay,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.red),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
