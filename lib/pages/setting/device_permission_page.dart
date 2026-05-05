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
      body: BlocConsumer<DevicePermissionCubit, DevicePermissionState>(
        listener: (context, state) {
          if (state.requestStatus == RequestStatus.failed &&
              state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: SelectableText(state.message!),
                backgroundColor: AppColors.red600,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.requestStatus == RequestStatus.requesting &&
              state.allRequests.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () =>
                widget.cubit.loadAllRequests(status: _filterStatus),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _buildSummary(state),
                const SizedBox(height: 12),
                _buildFilterChips(),
                const SizedBox(height: 12),
                if (state.requestStatus == RequestStatus.requesting)
                  const LinearProgressIndicator(minHeight: 2),
                if (state.allRequests.isEmpty)
                  _buildEmptyState()
                else
                  ...state.allRequests
                      .map((request) => _buildRequestCard(request, state)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary(DevicePermissionState state) {
    final pending = state.allRequests.where((r) => r.isPending).length;
    final approved = state.allRequests.where((r) => r.isApproved).length;
    final rejected = state.allRequests.where((r) => r.isRejected).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Danh sách thiết bị chờ cấp quyền',
            style: TextStyle(
              color: AppColors.slate900,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Duyệt hoặc từ chối thiết bị kiosk trước khi cho phép điểm danh theo phòng.',
            style: TextStyle(color: AppColors.slate500, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryItem('Chờ duyệt', pending, AppColors.orange),
              const SizedBox(width: 8),
              _summaryItem('Đã duyệt', approved, AppColors.green),
              const SizedBox(width: 8),
              _summaryItem('Từ chối', rejected, AppColors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.slate600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
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
          color: isSelected
              ? AppColors.blue
              : AppColors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.blue
                : AppColors.blue.withValues(alpha: 0.2),
          ),
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

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: const Column(
        children: [
          Icon(Icons.devices_other_outlined,
              size: 44, color: AppColors.slate400),
          SizedBox(height: 12),
          Text(
            'Không có yêu cầu nào',
            style: TextStyle(
              color: AppColors.slate700,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Kéo xuống để tải lại danh sách yêu cầu thiết bị.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.slate500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(DeviceRequest request, DevicePermissionState state) {
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

    final isProcessing = state.processingRequestId == request.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.slate200),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  const Icon(Icons.meeting_room,
                      size: 14, color: AppColors.slate500),
                  const SizedBox(width: 4),
                  Text(
                    'Phòng: ${request.roomName}',
                    style: const TextStyle(
                        color: AppColors.slate500, fontSize: 13),
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
                      onPressed: isProcessing
                          ? null
                          : () => _showRejectDialog(request),
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
                      onPressed: isProcessing
                          ? null
                          : () => _showApproveDialog(request),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Duyệt'),
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

  void _showApproveDialog(DeviceRequest request) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Duyệt thiết bị'),
        content: Text(
          'Cho phép thiết bị "${request.deviceName ?? request.deviceCode}" sử dụng điểm danh'
          '${request.roomName == null ? ' cho tất cả phòng?' : ' tại phòng ${request.roomName}?'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.cubit.approveRequest(request.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Duyệt'),
          ),
        ],
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
                adminNote:
                    noteController.text.isNotEmpty ? noteController.text : null,
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
