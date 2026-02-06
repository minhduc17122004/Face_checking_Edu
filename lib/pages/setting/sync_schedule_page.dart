import 'dart:io';

import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:flutter/material.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/resources/styles/text_styles.dart';
import 'package:face_time_keeping/entities/sync_schedule.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/di/injection.dart';

class SyncSchedulePage extends StatefulWidget {
  const SyncSchedulePage({super.key});

  @override
  State<SyncSchedulePage> createState() => _SyncSchedulePageState();
}

class _SyncSchedulePageState extends State<SyncSchedulePage> {
  final LocalService _localService = getIt<LocalService>();
  List<SyncSchedule> _syncSchedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSyncSchedules();
  }

  Future<void> _loadSyncSchedules() async {
    try {
      setState(() => _isLoading = true);
      final schedules = await _localService.getSyncSchedules();
      setState(() {
        _syncSchedules = schedules;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải lịch đồng bộ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSyncSchedules() async {
    try {
      await _localService.saveSyncSchedules(_syncSchedules);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu lịch đồng bộ thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      await pushLog('Error in saveSyncSchedules: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu lịch đồng bộ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddScheduleDialog() async {
    TimeOfDay? selectedTime;
    final hoursController = TextEditingController(text: '0');
    final minutesController = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              int selectedHours = int.tryParse(hoursController.text) ?? 0;
              int selectedMinutes = int.tryParse(minutesController.text) ?? 0;

              return AlertDialog(
                title: const Text(
                  'Thêm lịch đồng bộ',
                  style: TextStyles.blackNormalBold,
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chọn thời gian bắt đầu:',
                          style: TextStyles.blackNormalBold,
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime ?? TimeOfDay.now(),
                            );
                            if (time != null) {
                              setDialogState(() {
                                selectedTime = time;
                              });
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.gray200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              selectedTime != null
                                  ? _formatTimeOfDay(selectedTime!)
                                  : 'Chọn thời gian',
                              style: TextStyle(
                                color: selectedTime != null ? Colors.black : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Khoảng thời gian lặp lại:',
                          style: TextStyles.blackNormalBold,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Giờ:',
                                    style: TextStyles.blackNormalRegular,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: hoursController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppColors.gray200),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 16,
                                      ),
                                      hintText: '0',
                                    ),
                                    validator: (value) {
                                      final number = int.tryParse(value ?? '');
                                      if (number == null || number < 0 || number > 24) {
                                        return 'Từ 0-24';
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      setDialogState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Phút:',
                                    style: TextStyles.blackNormalRegular,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: minutesController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppColors.gray200),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 16,
                                      ),
                                      hintText: '0',
                                    ),
                                    validator: (value) {
                                      final number = int.tryParse(value ?? '');
                                      if (number == null || number < 0 || number > 59) {
                                        return 'Từ 0-59';
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      setDialogState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (selectedHours > 0 || selectedMinutes > 0)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Text(
                              'Lặp lại: ${_formatInterval(selectedHours, selectedMinutes)}',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  ElevatedButton(
                    onPressed: selectedTime != null && (selectedHours > 0 || selectedMinutes > 0)
                        ? () {
                            if (formKey.currentState!.validate()) {
                              Navigator.pop(context, {
                                'time': selectedTime,
                                'hours': selectedHours,
                                'minutes': selectedMinutes,
                              });
                            }
                          }
                        : null,
                    child: const Text('Thêm'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != null) {
        final time = result['time'] as TimeOfDay;
        final hours = result['hours'] as int;
        final minutes = result['minutes'] as int;

        final newSchedule = SyncSchedule(
          time: _formatTimeOfDay(time),
          repeatIntervalHours: hours,
          repeatIntervalMinutes: minutes,
        );
        final scheduleResult = await _localService.scheduleSyncData(newSchedule);
        if (!scheduleResult) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lỗi khi đồng bộ dữ liệu'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        setState(() {
          _syncSchedules.add(newSchedule);
        });

        await _saveSyncSchedules();
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      hoursController.dispose();
      minutesController.dispose();
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatInterval(int hours, int minutes) {
    List<String> parts = [];
    if (hours > 0) {
      parts.add('$hours giờ');
    }
    if (minutes > 0) {
      parts.add('$minutes phút');
    }
    return parts.join(' ');
  }

  String _formatScheduleInterval(SyncSchedule schedule) {
    List<String> parts = [];
    if (schedule.repeatIntervalHours > 0) {
      parts.add('${schedule.repeatIntervalHours} giờ');
    }
    if (schedule.repeatIntervalMinutes > 0) {
      parts.add('${schedule.repeatIntervalMinutes} phút');
    }

    if (parts.isEmpty) {
      return 'Không lặp lại';
    }
    return 'Lặp lại mỗi ${parts.join(' ')}';
  }

  Future<void> _removeSchedule(int index) async {
    try {
      final schedule = _syncSchedules[index];
      await _localService.cancelSyncData(schedule);
      setState(() {
        _syncSchedules.removeAt(index);
      });
      _saveSyncSchedules();
    } catch (e) {
      debugPrint('_removeSchedule: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Platform.isAndroid
        ? Scaffold(
            appBar: AppBar(
              title: const Text(
                'Thiết lập đồng bộ',
                style: TextStyles.whiteNormalBold,
              ),
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                if (_syncSchedules.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.5),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _showClearAllConfirmDialog,
                      child: const Text(
                        'Xóa toàn bộ lịch',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: Colors.blue[50],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Thông tin',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Thiết lập thời gian tự động đồng bộ dữ liệu với server. '
                              'Dữ liệu sẽ được đồng bộ theo lịch đã thiết lập.',
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _syncSchedules.isEmpty ? _buildEmptyState() : _buildScheduleList(),
                      ),
                    ],
                  ),
            floatingActionButton: FloatingActionButton(
              onPressed: _showAddScheduleDialog,
              backgroundColor: AppColors.blue,
              child: const Icon(
                Icons.add,
                color: Colors.white,
              ),
            ),
          )
        : Scaffold(
            appBar: AppBar(
              title: const Text('Thiết lập đồng bộ dữ liệu'),
              centerTitle: true,
            ),
            body: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(32),
              child: const Text(
                "Chỉ hỗ trợ cho hệ điều hành Android",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có lịch đồng bộ nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhấn nút + để thêm lịch đồng bộ mới',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _syncSchedules.length,
      itemBuilder: (context, index) {
        final schedule = _syncSchedules[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.access_time,
                color: AppColors.blue,
                size: 24,
              ),
            ),
            title: Text(
              'Đồng bộ lúc ${schedule.time}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              _formatScheduleInterval(schedule),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            trailing: IconButton(
              onPressed: () => _showDeleteConfirmDialog(index),
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmDialog(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Xác nhận xóa',
            style: TextStyles.blackNormalBold,
          ),
          content: const Text(
            'Bạn có chắc chắn muốn xóa lịch đồng bộ này không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _removeSchedule(index);
    }
  }

  Future<void> _showClearAllConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Xóa tất cả lịch đồng bộ',
            style: TextStyles.blackNormalBold,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bạn có chắc chắn muốn xóa tất cả lịch đồng bộ không?',
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_outlined,
                      color: Colors.red[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hành động này không thể hoàn tác!',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xóa tất cả'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _clearAllSchedules();
    }
  }

  Future<void> _clearAllSchedules() async {
    try {
      setState(() => _isLoading = true);
      await _localService.cancelAllSyncData();
      // Clear all schedules from storage
      await _localService.clearSyncSchedules();

      setState(() {
        _syncSchedules.clear();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa tất cả lịch đồng bộ thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('_clearAllSchedules: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa lịch đồng bộ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
