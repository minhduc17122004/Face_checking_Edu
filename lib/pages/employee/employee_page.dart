import 'dart:math';

import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/common/utils/widgets/default_image_widget.dart';
import 'package:face_time_keeping/common/utils/widgets/search_text_field.dart';
import 'package:face_time_keeping/common/utils/widgets/spacing.dart';
import 'package:face_time_keeping/entities/employee.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/resources/index.dart';
import '../../di/injection.dart';
import '../../route/app_route.dart';
import '../../route/navigator.dart';
import '../widgets/content_widget.dart';
import '../widgets/default_app_bar.dart';
import 'add_employee_dialog.dart';
import 'blocs/employee_bloc.dart';
import 'blocs/employee_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/pages/setting/cubit/setting/setting_cubit.dart';
import 'package:face_time_keeping/common/enums/server_type.dart';

class EmployeePage extends StatefulWidget {
  const EmployeePage({super.key});

  @override
  State<EmployeePage> createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  final Random _random = Random();
  final EmployeeBloc _bloc = getIt();
  final SettingCubit _settingCubit = getIt();
  bool _hasServerConfig = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      _bloc.init();
      await _checkServerConfig();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkServerConfig() async {
    final serverType = await _settingCubit.getServerType();
    setState(() {
      _hasServerConfig = serverType != null && serverType != ServerType.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<EmployeeBloc>(create: (_) => _bloc),
        BlocProvider<SettingCubit>(create: (_) => _settingCubit),
      ],
      child: Scaffold(
        appBar: DefaultAppBar(
          titleText: Strings.localized.employee.toUpperCase(),
          trailingActions: [
            IconButton(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert),
              onPressed: _showMoreOptions,
            ),
            const SizedBox(width: 8),
          ],
        ),
        backgroundColor: AppColors.white,
        body: _buildEmployeeList(),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddEmployeeDialog,
          backgroundColor: AppColors.primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmployeeList() {
    return BlocBuilder<EmployeeBloc, EmployeeState>(builder: (context, state) {
      return Column(
        children: [
          const Spacing(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SearchTextField(
              onChanged: (text) {
                _bloc.onSearch(text, isServerTab: false);
              },
              hintText: 'Nhập tên để tìm...',
            ),
          ),
          Expanded(
            child: ContentBundle(
              status: state.status,
              onRefresh: (_) => _bloc.onRefresh(),
              emptyAction: (_) {
                _bloc.onRefresh();
              },
              emptyActionTitle: 'Thử lại',
              child: ListView.separated(
                padding: const EdgeInsets.only(
                    top: 8, left: 8, right: 8, bottom: 80),
                itemCount: state.employees?.length ?? 0,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final employee = state.employees?[index];
                  final color = getRandomColor();
                  final firstChar = (employee?.name ?? 'U').isNotEmpty
                      ? employee?.name[0].toUpperCase()
                      : 'U';

                  return Material(
                    color: AppColors.transparent,
                    child: InkWell(
                      onTap: () {
                        AppNavigator.pushNamed(
                          RouterName.registerFace,
                          arguments: employee,
                        );
                      },
                      child: Ink(
                        decoration: BoxDecoration(
                          color: AppColors.cyan2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        height: 60,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              (employee?.avatar?.isNotEmpty ?? false)
                                  ? DefaultImageWidget(
                                      employee?.avatar,
                                      width: 40,
                                      height: 40,
                                      radius: 20,
                                      fit: BoxFit.cover,
                                      defaultImage: CircleAvatar(
                                        backgroundColor: Colors.white,
                                        child: Text(
                                          firstChar ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    )
                                  : CircleAvatar(
                                      backgroundColor: Colors.white,
                                      child: Text(
                                        firstChar ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                              const SizedBox(height: 8, width: 8),
                              Expanded(
                                child: Text(
                                  employee?.name ?? Strings.localized.unknown,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white,
                                ),
                                onPressed: () => _showItemOptions(employee),
                                tooltip: 'Thêm',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    });
  }

  Color getRandomColor() {
    return Color.fromARGB(
      255,
      _random.nextInt(256),
      _random.nextInt(256),
      _random.nextInt(256),
    );
  }

  void _showAddEmployeeDialog() {
    showDialog(
      context: context,
      builder: (context) => BlocProvider.value(
        value: _bloc,
        child: AddEmployeeDialog(
          hasServerConfig: _hasServerConfig,
        ),
      ),
    );
  }

  Future<void> _showMoreOptions() async {
    final action = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasServerConfig)
              ListTile(
                leading: const Icon(Icons.sync, color: Colors.orange),
                title: const Text(
                  'Đồng bộ học sinh',
                  style: TextStyle(color: Colors.orange),
                ),
                onTap: () => Navigator.of(ctx).pop('sync'),
              ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Export JSON'),
              onTap: () => Navigator.of(ctx).pop('export'),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Import JSON'),
              onTap: () => Navigator.of(ctx).pop('import'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.red),
              title: const Text(
                'Xóa tất cả học sinh trong thiết bị',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.of(ctx).pop('reset_all'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Hủy'),
              onTap: () => Navigator.of(ctx).pop(null),
            ),
          ],
        ),
      ),
    );

    if (action == null) return;

    switch (action) {
      case 'sync':
        await _confirmAndSyncEmployees();
        break;
      case 'export':
        await _exportJson();
        break;
      case 'import':
        await _importJson();
        break;
      case 'reset_all':
        await _resetAllLocalData();
        break;
    }
  }

  Future<void> _confirmAndSyncEmployees() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đồng bộ'),
        content: const Text(
          'Bạn có chắc muốn đồng bộ tất cả học sinh local lên server?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Đồng bộ',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _syncLocalEmployeesToServer();
    }
  }

  Future<void> _exportJson() async {
    try {
      final success = await getIt<LocalService>().shareModelJsonFile();
      if (!success) return;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Export Thành Công',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      await pushLog('Export Thất Bại: $e');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          title: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Export Thất Bại',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          content: SelectableText.rich(
            TextSpan(
              text: '$e',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.red),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _importJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withReadStream: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;

      final imported = await getIt<LocalService>().importFromJsonFile(path);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Thành Công'),
          content: SelectableText.rich(
            TextSpan(
              text: 'Đã import ${imported.length} records',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      await pushLog('Import Thất Bại: $e');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import failed'),
          content: SelectableText.rich(
            TextSpan(
              text: '$e',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.red),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showItemOptions(Employee? employee) async {
    if (employee == null) return;

    final action = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Cập nhật tên'),
              onTap: () => Navigator.of(ctx).pop('edit_name'),
            ),
            ListTile(
              leading: const Icon(Icons.work_outline),
              title: const Text('Cập nhật lớp'),
              onTap: () => Navigator.of(ctx).pop('edit_position'),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Cập nhật PIN'),
              onTap: () => Navigator.of(ctx).pop('edit_pin'),
            ),
            ListTile(
              leading: const Icon(Icons.face_retouching_natural),
              title: const Text('Reset face'),
              onTap: () => Navigator.of(ctx).pop('reset'),
            ),
            if (!_hasServerConfig)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Xóa',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.of(ctx).pop('delete'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Hủy'),
              onTap: () => Navigator.of(ctx).pop(null),
            ),
          ],
        ),
      ),
    );

    if (action == null) return;

    switch (action) {
      case 'reset':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận reset face'),
            content:
                Text('Bạn có chắc muốn reset face cho "${employee.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Reset', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          _bloc.onResetFace(employee.id);
        }
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Text('Bạn có chắc muốn xóa học sinh "${employee.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          final removed = await _bloc.onRemoveEmployee(employee.id);
          if (!removed && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_bloc.state.error ?? 'Xóa thất bại'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        break;
      case 'edit_name':
        final newName = await _showEditInputDialog(
          title: 'Cập nhật tên',
          label: 'Tên mới',
          initialValue: employee.name,
        );

        if (newName != null && newName.trim().isNotEmpty) {
          _bloc.onUpdatEmployeeInList(employee.copyWith(name: newName.trim()));
        }
        break;
      case 'edit_position':
        final newPos = await _showEditInputDialog(
          title: 'Cập nhật lớp',
          label: 'Lớp mới',
          initialValue: employee.jobTitle ?? '',
        );
        if (newPos != null && newPos.trim().isNotEmpty) {
          _bloc.onUpdatEmployeeInList(
              employee.copyWith(jobTitle: newPos.trim()));
        }
        break;
      case 'edit_pin':
        final newPin = await _showEditInputDialog(
          title: 'Cập nhật PIN',
          label: 'PIN mới (numbers only)',
          initialValue: employee.pin ?? '',
          keyboardType: TextInputType.number,
        );
        if (newPin != null && newPin.trim().isNotEmpty) {
          await _bloc.onUpdatEmployeeInList(
              employee.copyWith(pin: newPin.trim()),
              isUpdatePin: true);
          if (_bloc.state.status == DataSourceStatus.failed &&
              _bloc.state.error != null &&
              mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_bloc.state.error!),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        break;
      default:
        break;
    }
  }

  Future<String?> _showEditInputDialog({
    required String title,
    required String label,
    String initialValue = '',
    TextInputType keyboardType = TextInputType.text,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAllLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận reset tất cả dữ liệu'),
        content: const Text(
          'Bạn có chắc muốn xóa TẤT CẢ dữ liệu học sinh local? '
          'Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await getIt<LocalService>().clearAllData();
      _bloc.onRefresh();

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã reset tất cả dữ liệu local'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _bloc.onRefresh();
      await pushLog('Reset Thất Bại: $e');
      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi reset: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _syncLocalEmployeesToServer() async {
    _bloc.syncData();
  }
}
