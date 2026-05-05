import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/device_request.dart';
import 'package:face_time_keeping/entities/room.dart';
import 'package:face_time_keeping/pages/setting/cubit/device_permission/device_permission_cubit.dart';
import 'package:face_time_keeping/pages/setting/cubit/device_permission/device_permission_state.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:face_time_keeping/data/remote/room_service.dart';

class DeviceRequestSubmitPage extends StatefulWidget {
  const DeviceRequestSubmitPage({super.key});

  @override
  State<DeviceRequestSubmitPage> createState() =>
      _DeviceRequestSubmitPageState();
}

class _DeviceRequestSubmitPageState extends State<DeviceRequestSubmitPage> {
  final _formKey = GlobalKey<FormState>();
  final _deviceNameController = TextEditingController();

  Room? _selectedRoom;
  List<Room> _rooms = [];
  bool _isLoadingRooms = false;

  late final DevicePermissionCubit _cubit;
  late final RoomService _roomService;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<DevicePermissionCubit>();
    _roomService = getIt<RoomService>();
    _loadRooms();
    _cubit.checkDeviceAuthorization();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoadingRooms = true);
    final result = await _roomService.getRooms(limit: 100);
    if (mounted) {
      setState(() {
        if (result.isSuccess) {
          _rooms = result.data ?? [];
        }
        _isLoadingRooms = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _deviceNameController.text.trim();
    await _cubit.submitRequest(
      deviceName: name.isNotEmpty ? name : null,
      roomId: _selectedRoom?.id,
    );
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocListener<DevicePermissionCubit, DevicePermissionState>(
        listener: (context, state) {
          if (state.requestStatus == RequestStatus.failed &&
              state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: SelectableText.rich(
                  TextSpan(
                    children: [
                      const WidgetSpan(
                          child: Icon(Icons.error_outline,
                              color: Colors.white, size: 20)),
                      const WidgetSpan(child: SizedBox(width: 8)),
                      TextSpan(text: state.message!),
                    ],
                  ),
                ),
                backgroundColor: AppColors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            );
          }
          if (state.requestStatus == RequestStatus.success &&
              state.selectedRequest != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Yêu cầu đã được gửi thành công!'),
                  ],
                ),
                backgroundColor: AppColors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            );
            _deviceNameController.clear();
            setState(() => _selectedRoom = null);
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            centerTitle: true,
            title: const Text(
              'QUẢN LÝ ĐIỂM DANH THIẾT BỊ',
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
            listener: (context, state) {},
            builder: (context, state) {
              // Show loading while checking authorization
              if (state.isCheckingAuthorization) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Đang kiểm tra quyền thiết bị...',
                        style: TextStyle(color: AppColors.slate500),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // --- Authorization Status Banner ---
                  _buildAuthStatusBanner(state),

                  // --- Submit Form Card ---
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
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
                              child: const Icon(Icons.tablet,
                                  color: AppColors.blue, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Gửi yêu cầu cấp quyền',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.slate900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Device code display (read-only, auto-generated)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.blue.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.qr_code,
                                  color: AppColors.blue, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Mã thiết bị',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.slate500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      state.deviceCode ?? 'Đang tải...',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.slate800,
                                        fontFamily: 'monospace',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _deviceNameController,
                                decoration: InputDecoration(
                                  labelText: 'Tên thiết bị (tùy chọn)',
                                  hintText: 'VD: Máy tính bảng phòng A1',
                                  prefixIcon:
                                      const Icon(Icons.label_outline, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Phòng học (tùy chọn)',
                                    prefixIcon: Icon(
                                        Icons.meeting_room_outlined,
                                        size: 20),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: _isLoadingRooms
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : DropdownButtonHideUnderline(
                                          child: DropdownButton<Room>(
                                            isExpanded: true,
                                            hint:
                                                const Text('-- Chọn phòng --'),
                                            value: _selectedRoom,
                                            items: [
                                              const DropdownMenuItem<Room>(
                                                value: null,
                                                child: Text(
                                                    '-- Không chọn phòng --'),
                                              ),
                                              ..._rooms.map(
                                                (room) =>
                                                    DropdownMenuItem<Room>(
                                                  value: room,
                                                  child: Text(room.displayName),
                                                ),
                                              ),
                                            ],
                                            onChanged: (room) => setState(
                                                () => _selectedRoom = room),
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: BlocBuilder<DevicePermissionCubit,
                              DevicePermissionState>(
                            builder: (context, cubitState) {
                              final isSubmitting = cubitState.requestStatus ==
                                  RequestStatus.requesting;
                              return ElevatedButton.icon(
                                onPressed: isSubmitting ? null : _submitRequest,
                                icon: isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.send, size: 18),
                                label: Text(isSubmitting
                                    ? 'Đang gửi...'
                                    : 'Gửi yêu cầu cấp quyền'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.blue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- My Requests Section ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.history,
                              color: AppColors.green, size: 18),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Yêu cầu của tôi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.slate900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _buildRequestsList(state),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAuthStatusBanner(DevicePermissionState state) {
    if (state.isAuthorized) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.green, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thiết bị đã được cấp quyền',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.green,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Bạn có thể sử dụng thiết bị này để điểm danh.',
                    style: TextStyle(color: AppColors.slate600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (state.hasPendingRequest) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.pending, color: AppColors.orange, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yêu cầu đang chờ duyệt',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.orange,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Vui lòng chờ quản trị viên duyệt yêu cầu.',
                    style: TextStyle(color: AppColors.slate600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRequestsList(DevicePermissionState state) {
    if (state.requestStatus == RequestStatus.requesting &&
        state.myRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final requests = state.myRequests;

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Chưa có yêu cầu nào',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _cubit.checkDeviceAuthorization(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: requests.length,
        itemBuilder: (context, index) => _buildRequestCard(requests[index]),
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
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.deviceName ?? request.deviceCode,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    request.deviceCode,
                    style: const TextStyle(
                        color: AppColors.slate500, fontSize: 12),
                  ),
                  if (request.roomName != null)
                    Text(
                      'Phòng: ${request.roomName}',
                      style: const TextStyle(
                          color: AppColors.slate500, fontSize: 12),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    request.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (request.adminNote != null &&
                    request.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 120,
                    child: Text(
                      request.adminNote!,
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
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
}
