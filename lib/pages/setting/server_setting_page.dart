import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/pages/domain/domain_page.dart';
import 'package:face_time_keeping/pages/setting/cubit/server_setting/server_setting_cubit.dart';
import 'package:face_time_keeping/pages/setting/cubit/server_setting/server_setting_state.dart';
import 'package:face_time_keeping/common/enums/server_type.dart';
import 'package:face_time_keeping/common/resources/index.dart';
import 'package:face_time_keeping/pages/widgets/default_app_bar.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus_detector/focus_detector.dart';

class ServerSettingPage extends StatelessWidget {
  const ServerSettingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const _ServerSettingView();
  }
}

const List<ServerType> _serverTypes = [
  ServerType.none,
  ServerType.odoo,
  // ServerType.sap,
  // ServerType.aws,
];

class _ServerSettingView extends StatefulWidget {
  const _ServerSettingView({Key? key}) : super(key: key);

  @override
  State<_ServerSettingView> createState() => _ServerSettingViewState();
}

class _ServerSettingViewState extends State<_ServerSettingView> {
  final _bloc = getIt<ServerSettingCubit>();


  Widget _buildSavedInfo(ServerType? saved) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Hiện tại: ${saved?.label ?? "None"}',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (saved == ServerType.odoo)
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showEditOptions(context),
              tooltip: 'Edit',
            ),
        ],
      ),
    );
  }

  void _showEditOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Chuyển đổi url'),
                onTap: () {
                  Navigator.pop(context);
                  AppNavigator.pushNamed(RouterName.domain);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DefaultAppBar(titleText: 'Cài đặt Server'),
      backgroundColor: AppColors.white,
      body: FocusDetector(
        onFocusGained: () => _bloc.load(),
        child: BlocProvider(
          create: (context) => _bloc,
          child: BlocBuilder<ServerSettingCubit, ServerSettingState>(
            builder: (context, state) {
              final selected = state.selected;
              final saved = state.saved;
              final isSaving = state.isSaving;
              final canNext = selected != saved && !isSaving;

              return Column(
                children: [
                  _buildSavedInfo(saved),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _serverTypes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final type = _serverTypes[index];
                        return RadioListTile<ServerType>(
                          title: Text(type.label),
                          value: type,
                          groupValue: selected,
                          onChanged: (v) {
                            if (v != null) _bloc.select(v);
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: canNext ? _onNext : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          textStyle: const TextStyle(
                              fontSize: 16, color: Colors.black),
                          disabledBackgroundColor: AppColors.gray300,
                          disabledForegroundColor: AppColors.white,
                          foregroundColor: AppColors.white,
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(selected == ServerType.none
                                ? 'Áp dụng'
                                : 'Tiếp theo'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _onNext() async {
    final sel = _bloc.state.selected;

    if (sel == ServerType.none) {
      // Reset server data when selecting none
      await _resetServerData();
      return;
    }

    await _bloc.saveTemp();
    if (!context.mounted) return;
    switch (sel) {
      case ServerType.none:
        // Already handled above
        break;
      case ServerType.sap:
      case ServerType.aws:
        // Do nothing for now
        break;
      case ServerType.odoo:
        AppNavigator.pushNamed(RouterName.domain);
        break;
    }
  }

  Future<void> _resetServerData() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận'),
          content: const Text(
              'Bạn có chắc chắn muốn xóa tất cả dữ liệu và đặt lại máy chủ không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Call bloc to reset server data
      await _bloc.resetServerData();

      if (!context.mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đặt lại máy chủ thành công')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }
}
