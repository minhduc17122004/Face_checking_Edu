import 'dart:io';
import 'package:face_time_keeping/common/resources/index.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/check_in_out.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SpoofListPage extends StatefulWidget {
  const SpoofListPage({super.key});

  @override
  State<SpoofListPage> createState() => _SpoofListPageState();
}

class _SpoofListPageState extends State<SpoofListPage> {
  late final LocalService _localService;
  List<CheckInOut> _spoofRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _localService = getIt<LocalService>();
    _loadSpoofRecords();
  }

  Future<void> _loadSpoofRecords() async {
    setState(() => _isLoading = true);
    final records = await _localService.getSpoofedCheckIns();
    setState(() {
      _spoofRecords = records;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Danh sách giả mạo khuôn mặt',
          style: TextStyle(color: AppColors.slate900, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.slate900),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _spoofRecords.isEmpty
              ? _buildEmptyState()
              : _buildList(),
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
        return _SpoofCard(record: record);
      },
    );
  }
}

class _SpoofCard extends StatelessWidget {
  const _SpoofCard({required this.record});

  final CheckInOut record;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
    final roomDisplay = record.roomId != null ? 'Phòng: ${record.roomId}' : '';
    final studentDisplay = record.pin != null ? '${record.pin} - ${record.name}' : record.name;

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
              child: _buildImage(),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 16),
                    const SizedBox(width: 4),
                    const Text(
                      'Phát hiện giả mạo',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.red, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  studentDisplay,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: AppColors.slate500),
                    const SizedBox(width: 4),
                    Text(
                      dateFormat.format(record.time),
                      style: const TextStyle(fontSize: 13, color: AppColors.slate500),
                    ),
                  ],
                ),
                if (roomDisplay.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.room, size: 14, color: AppColors.slate500),
                      const SizedBox(width: 4),
                      Text(
                        roomDisplay,
                        style: const TextStyle(fontSize: 13, color: AppColors.slate500),
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

  Widget _buildImage() {
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
    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const Center(child: Icon(Icons.broken_image)),
    );
  }
}
