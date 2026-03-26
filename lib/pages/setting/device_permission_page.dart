import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/device_request.dart';
import 'package:face_time_keeping/pages/setting/cubit/device_permission/device_permission_cubit.dart';
import 'package:face_time_keeping/pages/setting/cubit/device_permission/device_permission_state.dart';
import 'package:face_time_keeping/route/navigator.dart';

class DevicePermissionPage extends StatelessWidget {
  const DevicePermissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = getIt<DevicePermissionCubit>()..loadAllRequests();
    return BlocProvider.value(
      value: cubit,
      child: _DevicePermissionView(cubit: cubit),
    );
  }
}

class _DevicePermissionView extends StatefulWidget {
  final DevicePermissionCubit cubit;

  const _DevicePermissionView({required this.cubit});

  @override
  State<_DevicePermissionView> createState() => _DevicePermissionViewState();
}

class _DevicePermissionViewState extends State<_DevicePermissionView> {
  String? _filterStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'YÊU CẦU QUYỀN THIẾT BỊ',
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
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: BlocConsumer<DevicePermissionCubit, DevicePermissionState>(
              listener: (context, state) {
                if (state.requestStatus == RequestStatus.failed &&
                    state.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: SelectableText(state.message!),
                      backgroundColor: AppColors.red600,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state.requestStatus == RequestStatus.requesting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final requests = state.allRequests;

                if (requests.isEmpty) {
                  return const Center(child: Text('Không có yêu cầu nào'));
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    widget.cubit.loadAllRequests(status: _filterStatus);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      return _buildRequestCard(requests[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          _filterChip('Tất cả', null),
          const SizedBox(width: 8),
          _filterChip('Đang chờ', 'PENDING'),
          const SizedBox(width: 8),
          _filterChip('Đã duyệt', 'APPROVED'),
          const SizedBox(width: 8),
          _filterChip('Từ chối', 'REJECTED'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? status) {
    final isSelected = _filterStatus == status;
    return GestureDetector(
      onTap: () {
        setState(() => _filterStatus = status);
        widget.cubit.loadAllRequests(status: status);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue : AppColors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : AppColors.blue,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(DeviceRequest request) {
    Color statusColor;
    IconData statusIcon;
    switch (request.status) {
      case DeviceRequestStatus.approved:
        statusColor = AppColors.green;
        statusIcon = Icons.check_circle;
        break;
      case DeviceRequestStatus.rejected:
        statusColor = AppColors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = AppColors.orange;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tablet, color: AppColors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.deviceName ?? request.deviceCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        request.deviceCode,
                        style: const TextStyle(
                          color: AppColors.slate500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        request.status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (request.roomName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.meeting_room, size: 14, color: AppColors.slate500),
                  const SizedBox(width: 4),
                  Text(
                    'Phòng: ${request.roomName}',
                    style: const TextStyle(color: AppColors.slate500, fontSize: 13),
                  ),
                ],
              ),
            ],
            if (request.adminNote != null && request.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Ghi chú: ${request.adminNote}',
                style: const TextStyle(color: AppColors.slate500, fontSize: 13),
              ),
            ],
            if (request.status == DeviceRequestStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showRejectDialog(request),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                        side: const BorderSide(color: AppColors.red),
                      ),
                      child: const Text('Từ chối'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => widget.cubit.approveRequest(request.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Duyệt'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(DeviceRequest request) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Từ chối yêu cầu'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.cubit.rejectRequest(
                request.id,
                adminNote: noteController.text.isNotEmpty ? noteController.text : null,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
  }
}
