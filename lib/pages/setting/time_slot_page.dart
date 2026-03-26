import 'package:flutter/material.dart';
import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/resources/styles/text_styles.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/time_slot.dart';
import 'package:face_time_keeping/data/remote/time_slot_service.dart';
import 'package:face_time_keeping/pages/widgets/default_app_bar.dart';
import 'package:face_time_keeping/pages/widgets/empty_state_widget.dart';
import 'package:face_time_keeping/common/event/event_bus_event.dart';
import 'package:face_time_keeping/common/event/event_bus_mixin.dart';

class TimeSlotPage extends StatelessWidget {
  const TimeSlotPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TimeSlotView();
  }
}

class _TimeSlotView extends StatefulWidget {
  const _TimeSlotView();

  @override
  State<_TimeSlotView> createState() => _TimeSlotViewState();
}

class _TimeSlotViewState extends State<_TimeSlotView> {
  final TimeSlotService _service = getIt<TimeSlotService>();
  List<TimeSlot> _slots = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _service.getTimeSlots(limit: 100);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.isSuccess) {
          _slots = result.data ?? [];
        } else {
          _error = result.error ?? 'Failed to load time slots';
        }
      });
    }
  }

  Future<void> _showFormDialog({TimeSlot? slot}) async {
    final isEdit = slot != null;
    final periodController = TextEditingController(
      text: slot?.periodNumber.toString() ?? '',
    );
    TimeOfDay startTime = _parseTime(slot?.startTime ?? '07:00');
    TimeOfDay endTime = _parseTime(slot?.endTime ?? '07:45');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isEdit ? 'Sửa tiết học' : 'Thêm tiết học'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: periodController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số tiết',
                    hintText: 'VD: 1, 2, 3...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _TimePickerTile(
                        label: 'Bắt đầu',
                        time: startTime,
                        color: AppColors.blue,
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: startTime,
                          );
                          if (picked != null) {
                            setState(() => startTime = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimePickerTile(
                        label: 'Kết thúc',
                        time: endTime,
                        color: AppColors.red,
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: endTime,
                          );
                          if (picked != null) {
                            setState(() => endTime = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final periodNum = int.tryParse(periodController.text.trim());
    if (periodNum == null || periodNum < 1) {
      _showError('Số tiết không hợp lệ');
      return;
    }

    final startStr = _formatTimeOfDay(startTime);
    final endStr = _formatTimeOfDay(endTime);

    // 1. Validate Time
    final startMinutes = startTime.hour * 60 + startTime.minute;
    var endMinutes = endTime.hour * 60 + endTime.minute;

    // Nếu end < start, có thể hiểu là tiết học vắt qua ngày hôm sau (ví dụ: 23:25 - 00:10)
    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60;
    }

    if (startMinutes == endMinutes) {
      _showError('Thời gian bắt đầu và kết thúc không được giống nhau');
      return;
    }

    // 2. Validate Overlap with other slots
    for (var other in _slots) {
      if (isEdit && other.id == slot.id) continue;

      final otherStart = _parseTime(other.startTime);
      final otherEnd = _parseTime(other.endTime);
      final otherSMin = otherStart.hour * 60 + otherStart.minute;
      var otherEMin = otherEnd.hour * 60 + otherEnd.minute;

      if (otherEMin < otherSMin) {
        otherEMin += 24 * 60;
      }

      // Overlap condition: (StartA < EndB) and (EndA > StartB)
      if (startMinutes < otherEMin && endMinutes > otherSMin) {
        _showError(
            'Thời gian bị trùng với tiết ${other.periodNumber} (${other.startTime} - ${other.endTime})');
        return;
      }
    }

    if (isEdit) {
      final result = await _service.updateTimeSlot(
        slot.id,
        periodNumber: periodNum,
        startTime: startStr,
        endTime: endStr,
      );
      if (!mounted) return;
      if (result.isSuccess) {
        EventBusMixin.shareStaticEvent(CourseChangeEvent());
        _showSuccess('Đã cập nhật tiết học');
        _loadSlots();
      } else {
        _showError(result.error ?? 'Lỗi cập nhật');
      }
    } else {
      final result = await _service.createTimeSlot(
        periodNumber: periodNum,
        startTime: startStr,
        endTime: endStr,
      );
      if (!mounted) return;
      if (result.isSuccess) {
        EventBusMixin.shareStaticEvent(CourseChangeEvent());
        _showSuccess('Đã thêm tiết học');
        _loadSlots();
      } else {
        _showError(result.error ?? 'Lỗi tạo mới');
      }
    }
  }

  Future<void> _confirmDelete(TimeSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa tiết ${slot.periodNumber} không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await _service.deleteTimeSlot(slot.id);
    if (!mounted) return;
    if (result.isSuccess) {
      EventBusMixin.shareStaticEvent(CourseChangeEvent());
      _showSuccess('Đã xóa tiết học');
      _loadSlots();
    } else {
      _showError(result.error ?? 'Lỗi xóa');
    }
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SelectableText(msg),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: DefaultAppBar(titleText: 'Thiết lập tiết học'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSlots,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _slots.isEmpty
                  ? EmptyStateWidget(
                      title: 'Chưa có tiết học',
                      subtitle: 'Nhấn + để thêm tiết học mới',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSlots,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _slots.length,
                        itemBuilder: (context, index) {
                          final slot = _slots[index];
                          return Dismissible(
                            key: Key('slot_${slot.id}'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async {
                              await _confirmDelete(slot);
                              return false;
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            child: _TimeSlotCard(
                              slot: slot,
                              onTap: () => _showFormDialog(slot: slot),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _TimeSlotCard extends StatelessWidget {
  const _TimeSlotCard({required this.slot, required this.onTap});

  final TimeSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${slot.periodNumber}',
                    style: TextStyles.blackNormalBold.copyWith(
                      fontSize: 22,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tiết ${slot.periodNumber}',
                      style: TextStyles.blackNormalBold.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _TimeBadge(
                          icon: Icons.play_arrow,
                          time: slot.startTime,
                          color: AppColors.green,
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_forward,
                            size: 16, color: AppColors.slate500),
                        const SizedBox(width: 12),
                        _TimeBadge(
                          icon: Icons.stop,
                          time: slot.endTime,
                          color: AppColors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.edit_outlined,
                color: AppColors.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeBadge extends StatelessWidget {
  const _TimeBadge({
    required this.icon,
    required this.time,
    required this.color,
  });

  final IconData icon;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({
    required this.label,
    required this.time,
    required this.color,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  time.format(context),
                  style: TextStyles.blackNormalBold.copyWith(
                    fontSize: 16,
                    color: color,
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
