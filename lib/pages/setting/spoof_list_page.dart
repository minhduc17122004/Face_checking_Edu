import 'dart:io';
import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/resources/index.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/check_in_out.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_time_keeping/data/remote/room_service.dart';
import 'package:face_time_keeping/pages/setting/cubit/attendance_report_cubit.dart';
import 'package:intl/intl.dart';

class SpoofListPage extends StatefulWidget {
  const SpoofListPage({super.key});

  @override
  State<SpoofListPage> createState() => _SpoofListPageState();
}

class _SpoofListPageState extends State<SpoofListPage> {
  late final LocalService _localService;
  late final RoomService _roomService;
  List<CheckInOut> _spoofRecords = [];
  Map<String, String> _roomMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _localService = getIt<LocalService>();
    _roomService = getIt<RoomService>();
    _loadSpoofRecords();
  }

  Future<void> _loadSpoofRecords() async {
    setState(() => _isLoading = true);
    try {
      final records = await _localService.getSpoofedCheckIns();

      final uniqueRoomIds = records
          .map((r) => r.roomId)
          .where((id) => id != null && id.trim().isNotEmpty)
          .cast<String>()
          .toSet();

      final roomMap = <String, String>{};

      if (uniqueRoomIds.isNotEmpty) {
        final roomResult = await _roomService.getRooms(limit: 200);
        if (roomResult.isSuccess && roomResult.data != null) {
          for (final room in roomResult.data!) {
            if (uniqueRoomIds.contains(room.id)) {
              roomMap[room.id] = room.displayName;
            }
          }
        }
      }

      final activeRoomId = await _localService.getActiveRoomId();
      final activeRoomName = await _localService.getActiveRoomName();
      if (activeRoomId != null &&
          activeRoomName != null &&
          activeRoomId.isNotEmpty) {
        roomMap.putIfAbsent(activeRoomId, () => activeRoomName);
      }

      if (mounted) {
        setState(() {
          _spoofRecords = records;
          _roomMap = roomMap;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<AttendanceReportCubit>(),
      child: BlocListener<AttendanceReportCubit, AttendanceReportState>(
        listenWhen: (previous, current) =>
            previous.isSyncing && !current.isSyncing,
        listener: (context, state) {
          if (state.syncMessage != null && state.syncMessage!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.syncMessage!)),
            );
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: const Text(
              'Danh sách giả mạo khuôn mặt',
              style: TextStyle(
                  color: AppColors.slate900,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
            backgroundColor: Colors.white,
            elevation: 0.5,
            iconTheme: const IconThemeData(color: AppColors.slate900),
            actions: [
              BlocBuilder<AttendanceReportCubit, AttendanceReportState>(
                builder: (context, state) {
                  if (state.isSyncing) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.only(right: 16.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  return IconButton(
                    icon: const Icon(Icons.cloud_upload_outlined,
                        color: AppColors.primary),
                    tooltip: 'Đồng bộ lên server',
                    onPressed: () {
                      context.read<AttendanceReportCubit>().syncToBackend();
                    },
                  );
                },
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _spoofRecords.isEmpty
                  ? _buildEmptyState()
                  : _buildList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 80, color: AppColors.slate300),
          SizedBox(height: 16),
          Text(
            'Chưa phát hiện giả mạo nào',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.slate500,
              fontWeight: FontWeight.w500,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _spoofRecords.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final record = _spoofRecords[index];
        return _SpoofCard(record: record, roomMap: _roomMap);
      },
    );
  }
}

class _SpoofCard extends StatelessWidget {
  const _SpoofCard({required this.record, required this.roomMap});

  final CheckInOut record;
  final Map<String, String> roomMap;

  @override
  Widget build(BuildContext context) {
    debugPrint(
        'SpoofRecord details. roomId: ${record.roomId}, courseName: ${record.courseName}, isSpoof: ${record.isSpoof}, sessionId_nullable: N/A');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
    final roomName = record.roomId != null
        ? (roomMap[record.roomId] ?? record.roomId)
        : null;
    final roomDisplay = roomName != null ? 'Phòng: $roomName' : '';
    final courseDisplay = record.courseName ?? '';
    final studentDisplay =
        record.pin != null ? '${record.pin} - ${record.name}' : record.name;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.red.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 80,
              height: 80,
              color: AppColors.slate200,
              child: _buildImage(context),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.red, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Phát hiện giả mạo',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.red,
                          fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  studentDisplay,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.slate900),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 14, color: AppColors.slate500),
                    const SizedBox(width: 4),
                    Text(
                      dateFormat.format(record.time),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.slate500),
                    ),
                  ],
                ),
                if (roomDisplay.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.room,
                          size: 14, color: AppColors.slate500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          roomDisplay,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.slate500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (courseDisplay.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.school_outlined,
                          size: 14, color: AppColors.slate500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          courseDisplay,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.slate500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (record.imagePath == null || record.imagePath!.isEmpty) {
      return const Center(
        child: Icon(Icons.image_not_supported, color: AppColors.slate400),
      );
    }
    final file = File(record.imagePath!);
    if (!file.existsSync()) {
      return const Center(
        child: Icon(Icons.broken_image, color: AppColors.slate400),
      );
    }
    return GestureDetector(
      onTap: () {
        showGeneralDialog(
          context: context,
          barrierColor: Colors.black.withOpacity(0.9),
          barrierDismissible: true,
          barrierLabel: 'Close',
          pageBuilder: (context, animation, secondaryAnimation) {
            return SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  InteractiveViewer(
                    child: Image.file(file, fit: BoxFit.contain),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 32),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      child: Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Icon(Icons.broken_image)),
      ),
    );
  }
}
