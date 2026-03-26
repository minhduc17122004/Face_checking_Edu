import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/resources/app_theme.dart';
import 'package:face_time_keeping/common/resources/styles/text_styles.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_time_keeping/pages/setting/cubit/setting/setting_cubit.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/pages/setting/pin_app_page.dart';
import 'package:face_time_keeping/pages/setting/sync_schedule_page.dart';
import 'package:face_time_keeping/entities/sync_face_schedule.dart';
import 'package:face_time_keeping/pages/widgets/app_dialog.dart';
import 'package:face_time_keeping/pages/setting/teacher_list_page.dart';
import 'package:face_time_keeping/pages/widgets/default_app_bar.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:face_time_keeping/common/enums/server_type.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  late final SettingCubit _settingCubit = getIt();
  bool _isAdmin = false;
  bool _isTeacherOrAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await _settingCubit.getUserRole();
    if (mounted) {
      final roleLower = role.toLowerCase();
      setState(() {
        _isAdmin = roleLower == 'admin';
        _isTeacherOrAdmin = roleLower == 'admin' || roleLower == 'teacher';
      });
    }
  }

  Future<void> _syncFaceData() async {
    int hours = 0;
    int minutes = 30;
    SyncFaceSchedule? existingSchedule;

    try {
      existingSchedule = await _settingCubit.getSyncFaceSchedule();
      if (existingSchedule != null) {
        hours = existingSchedule.repeatIntervalHours;
        minutes = existingSchedule.repeatIntervalMinutes;
      }
    } catch (_) {}
    if (!mounted) return;
    if (!await _ensureServerConfigured()) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AppDialog(
              title: 'Đồng bộ dữ liệu khuôn mặt',
              icon: Icons.sync_problem,
              accentColor: AppColors.blue,
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sync Now Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.blue.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              'Đồng bộ dữ liệu với server',
                              style: TextStyles.blackNormalRegular.copyWith(
                                color: AppColors.gray200,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await _performSyncNow();
                                },
                                icon: const Icon(Icons.sync, size: 18),
                                label: const Text('Đồng bộ dữ liệu ngay'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.blue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Schedule Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.green.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.green.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  color: AppColors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Đồng bộ định kỳ',
                                  style: TextStyles.blackNormalBold.copyWith(
                                    color: AppColors.green,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Thiết lập khoảng thời gian tự động đồng bộ',
                              style: TextStyles.blackNormalRegular.copyWith(
                                color: AppColors.gray200,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Current schedule display
                            if (existingSchedule != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.yellow.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.yellow.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      color: AppColors.orange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Lịch hiện tại: ${existingSchedule.repeatIntervalHours}h ${existingSchedule.repeatIntervalMinutes}m',
                                      style: TextStyles.blackNormalRegular
                                          .copyWith(
                                        color: AppColors.orange,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            if (existingSchedule != null)
                              const SizedBox(height: 12),

                            // Time selectors
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            AppColors.gray200.withOpacity(0.3),
                                      ),
                                    ),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Giờ',
                                        labelStyle: TextStyles
                                            .blackNormalRegular
                                            .copyWith(
                                          color: AppColors.gray200,
                                          fontSize: 12,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      child: DropdownButton<int>(
                                        isExpanded: true,
                                        value: hours,
                                        underline: const SizedBox.shrink(),
                                        items: List.generate(24, (i) => i)
                                            .map((h) => DropdownMenuItem<int>(
                                                  value: h,
                                                  child: Text(
                                                    '$h giờ',
                                                    style: TextStyles
                                                        .blackNormalRegular,
                                                  ),
                                                ))
                                            .toList(),
                                        onChanged: (v) =>
                                            setState(() => hours = v ?? 0),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            AppColors.gray200.withOpacity(0.3),
                                      ),
                                    ),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Phút',
                                        labelStyle: TextStyles
                                            .blackNormalRegular
                                            .copyWith(
                                          color: AppColors.gray200,
                                          fontSize: 12,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      child: DropdownButton<int>(
                                        isExpanded: true,
                                        value: minutes,
                                        underline: const SizedBox.shrink(),
                                        items: List.generate(60, (i) => i)
                                            .map((m) => DropdownMenuItem<int>(
                                                  value: m,
                                                  child: Text(
                                                    '$m phút',
                                                    style: TextStyles
                                                        .blackNormalRegular,
                                                  ),
                                                ))
                                            .toList(),
                                        onChanged: (v) =>
                                            setState(() => minutes = v ?? 0),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      try {
                                        await _settingCubit
                                            .saveSyncFaceSchedule(
                                          SyncFaceSchedule(
                                            repeatIntervalHours: hours,
                                            repeatIntervalMinutes: minutes,
                                          ),
                                        );
                                        if (!mounted) return;
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Đã lưu lịch đồng bộ: ${hours}h ${minutes}m',
                                            ),
                                            backgroundColor: AppColors.green,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Lỗi lưu lịch đồng bộ: $e'),
                                            backgroundColor: AppColors.red,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.save, size: 18),
                                    label: const Text('Lưu lịch'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                if (existingSchedule != null) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        // Show confirmation dialog
                                        final confirmed =
                                            await showDialog<bool>(
                                          context: context,
                                          builder:
                                              (BuildContext dialogContext) {
                                            return AppDialog(
                                              title: 'Xác nhận hủy lịch',
                                              icon: Icons.warning_amber_rounded,
                                              accentColor: AppColors.orange,
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Bạn có chắc chắn muốn hủy lịch đồng bộ tự động không?',
                                                    style: TextStyles
                                                        .blackNormalRegular
                                                        .copyWith(
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.red
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                        color: AppColors.red
                                                            .withOpacity(0.3),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'Lịch hiện tại: ${existingSchedule?.repeatIntervalHours}h ${existingSchedule?.repeatIntervalMinutes}m sẽ bị xóa.',
                                                      style: TextStyles
                                                          .blackNormalRegular
                                                          .copyWith(
                                                        color: AppColors.red,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                          dialogContext)
                                                      .pop(false),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        AppColors.gray200,
                                                  ),
                                                  child: const Text('Không'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.of(
                                                          dialogContext)
                                                      .pop(true),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppColors.red,
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                      'Có, hủy lịch'),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        // Only proceed if user confirmed
                                        if (confirmed == true) {
                                          try {
                                            await _settingCubit
                                                .clearSyncFaceSchedule();
                                            if (!mounted) return;
                                            Navigator.of(context).pop();
                                            ScaffoldMessenger.of(this.context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                    'Đã hủy lịch đồng bộ tự động'),
                                                backgroundColor:
                                                    AppColors.orange,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(this.context)
                                                .showSnackBar(
                                              SnackBar(
                                                content:
                                                    Text('Lỗi hủy lịch: $e'),
                                                backgroundColor: AppColors.red,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.cancel_outlined,
                                          size: 18),
                                      label: const Text('Hủy lịch'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.orange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.gray200,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('Đóng'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performSyncNow() async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Đang đồng bộ khuôn mặt...'),
          ],
        ),
        backgroundColor: AppColors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      final push = await _settingCubit.pushFaceData();
      if (!push.isSuccess && mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                      'Đẩy dữ liệu thất bại: ${push.error ?? 'Lỗi không xác định'}'),
                ),
              ],
            ),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      final pull = await _settingCubit.pullFaceData();
      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      if (pull.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Đồng bộ khuôn mặt thành công!'),
              ],
            ),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                      'Tải dữ liệu thất bại: ${pull.error ?? 'Lỗi không xác định'}'),
                ),
              ],
            ),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Lỗi đồng bộ: $e'),
              ),
            ],
          ),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<bool> _ensureServerConfigured() async {
    final serverType = await _settingCubit.getServerType();
    if (serverType == null || serverType == ServerType.none) {
      if (!mounted) return false;
      await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AppDialog(
            title: 'Chưa cấu hình Server',
            icon: Icons.cloud_off,
            accentColor: AppColors.orange,
            content: Text(
              'Bạn chưa thiết lập server. Vui lòng thiết lập server trước khi đồng bộ dữ liệu.',
              style: TextStyles.blackNormalRegular.copyWith(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Đóng'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.gray200,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  AppNavigator.pushNamed(RouterName.serverSettings);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Thiết lập'),
              ),
            ],
          );
        },
      );
      return false;
    }
    return true;
  }



  Future<void> _syncData() async {
    try {
      if (!await _ensureServerConfigured()) return;
      // Show loading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Đang đồng bộ dữ liệu...'),
              ],
            ),
            duration: Duration(seconds: 30), // Long duration for sync operation
            backgroundColor: AppColors.blue,
          ),
        );
      }

      final result = await _settingCubit.syncCheckInOutData();

      // Clear any existing snackbars
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();

        if (result.isSuccess) {
          // Show success snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Đồng bộ dữ liệu thành công!'),
                ],
              ),
              backgroundColor: AppColors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // Show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        'Đồng bộ thất bại: ${result.error ?? "Lỗi không xác định"}'),
                  ),
                ],
              ),
              backgroundColor: AppColors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      await pushLog('Error in _syncData: $e');
      // Clear loading snackbar and show error
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Lỗi đồng bộ: $e'),
                ),
              ],
            ),
            backgroundColor: AppColors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }


  @override
  void dispose() {
    _settingCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _settingCubit,
      child: Theme(
        data: AppTheme.lightTheme,
        child: Scaffold(
          appBar: DefaultAppBar(
            titleText: "Menu",
            showNotificationAction: false,
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSettingItem(
                      icon: Icons.sync_alt,
                      title: "Đồng bộ dữ liệu điểm danh",
                      subtitle: "Đồng bộ dữ liệu điểm danh hàng ngày",
                      onTap: _syncData,
                    ),
                    _buildSettingItem(
                      icon: Icons.history,
                      title: "Báo cáo điểm danh",
                      subtitle: "Xem báo cáo điểm danh của học sinh",
                      onTap: () {
                        AppNavigator.pushNamed(RouterName.attendanceReport);
                      },
                    ),
                    // _buildSettingItem(
                    //   icon: Icons.cloud,
                    //   title: "Chọn Server",
                    //   subtitle: "Chọn loại server (odoo, SAP, AWS, ...)",
                    //   onTap: () {
                    //     AppNavigator.pushNamed(RouterName.serverSettings);
                    //   },
                    // ),
                    _buildSettingItem(
                      icon: Icons.face_retouching_natural,
                      title: "Đăng ký khuôn mặt",
                      subtitle: "Đăng ký khuôn mặt học sinh",
                      onTap: () {
                        AppNavigator.pushNamed(RouterName.students);
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.sync,
                      title: "Thiết lập đồng bộ dữ liệu",
                      subtitle: "Thiết lập thời gian đồng bộ dữ liệu",
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const SyncSchedulePage()));
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.schedule_rounded,
                      title: "Thiết lập tiết học",
                      subtitle: "Thiết lập thời gian học phần",
                      onTap: () {
                        AppNavigator.pushNamed(RouterName.timeSlot);
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.sync_problem,
                      title: "Đồng bộ dữ liệu khuôn mặt",
                      subtitle: "Đồng bộ dữ liệu đăng ký khuôn mặt",
                      onTap: _syncFaceData,
                    ),
                    _buildSettingItem(
                      icon: Icons.card_membership,
                      title: "Quản lý điểm danh thiết bị",
                      subtitle: "Gửi và xem yêu cầu duyệt thiết bị",
                      onTap: () {
                        AppNavigator.pushNamed(RouterName.deviceRequestSubmit);
                      },
                    ),
                    if (_isAdmin) ...[
                      _buildSettingItem(
                        icon: Icons.phonelink_setup,
                        title: "Yêu cầu quyền thiết bị",
                        subtitle: "Duyệt/từ chối yêu cầu thiết bị",
                        onTap: () {
                          AppNavigator.pushNamed(RouterName.devicePermission);
                        },
                      ),
                      _buildSettingItem(
                        icon: Icons.business,
                        title: "Quản lý phòng ban",
                        subtitle: "Thêm, sửa, xóa phòng ban",
                        onTap: () {
                          AppNavigator.pushNamed(RouterName.departmentList);
                        },
                      ),
                      _buildSettingItem(
                        icon: Icons.meeting_room,
                        title: "Quản lý phòng học",
                        subtitle: "Thêm, sửa, xóa phòng học",
                        onTap: () {
                          AppNavigator.pushNamed(RouterName.roomList);
                        },
                      ),
                    ],
                    if (_isAdmin || _isTeacherOrAdmin) ...[
                      _buildSettingItem(
                        icon: Icons.checklist_rtl,
                        title: "Điểm danh theo phòng",
                        subtitle: "Chọn phòng và buổi học để điểm danh",
                        onTap: () {
                          AppNavigator.pushNamed(RouterName.roomSelection);
                        },
                      ),
                    ],
                    if (_isAdmin) ...[
                      _buildSettingItem(
                        icon: Icons.class_,
                        title: "Quản lý lớp học",
                        subtitle: "Thêm, sửa, xóa lớp học",
                        onTap: () {
                          AppNavigator.pushNamed(RouterName.studentGroupList);
                        },
                      ),
                      _buildSettingItem(
                        icon: Icons.school,
                        title: "Quản lý học phần",
                        subtitle: "Thêm, sửa, xóa học phần",
                        onTap: () {
                          AppNavigator.pushNamed(RouterName.courseList);
                        },
                      ),
                      // _buildSettingItem(
                      // icon: Icons.assignment_ind,
                      // title: "Gán giáo viên",
                      // subtitle: "Gán giáo viên vào phòng ban",
                      // onTap: () {
                      // // AppNavigator.pushNamed(RouterName.teacherAssignment);
                      // },
                      // ),
                      _buildSettingItem(
                        icon: Icons.person_add,
                        title: "Quản lý người dùng",
                        subtitle: "Đăng ký student và teacher",
                        onTap: () {
                          AppNavigator.pushNamed(RouterName.userRegister);
                        },
                      ),
                      _buildSettingItem(
                        icon: Icons.list_alt,
                        title: "Danh sách giáo viên",
                        subtitle: "Quản lý danh sách giáo viên",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TeacherListPage(),
                            ),
                          );
                        },
                      ),
                    ],
                    _buildSettingItem(
                      icon: Icons.lock,
                      title: "Đặt mã PIN",
                      subtitle: "Đặt mã PIN để bảo mật ứng dụng",
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const PinAppPage()));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: AppColors.blue,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyles.blackNormalBold,
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.slate500,
          fontSize: 14,
        ),
      ),
      trailing: const Padding(
        padding: EdgeInsets.only(right: 10),
        child: Icon(
          Icons.chevron_right,
          color: AppColors.gray200,
          size: 20,
        ),
      ),
      onTap: onTap,
    );
  }
}
