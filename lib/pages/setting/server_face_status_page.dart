import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/resources/styles/text_styles.dart';
import 'package:face_time_keeping/data/remote/api_endpoint.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/common/api_client/api_client.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:flutter/material.dart';

class ServerFaceStatusPage extends StatefulWidget {
  const ServerFaceStatusPage({Key? key}) : super(key: key);

  @override
  State<ServerFaceStatusPage> createState() => _ServerFaceStatusPageState();
}

class _ServerFaceStatusPageState extends State<ServerFaceStatusPage> {
  final ApiClient _apiClient = getIt<ApiClient>();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _serverFaces = [];

  @override
  void initState() {
    super.initState();
    _fetchServerFaces();
  }

  Future<void> _fetchServerFaces() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiClient.dio.get(ApiEndpoint.pullFaceData);

      if (response.statusCode == 200) {
        final rawData = response.data;
        List<dynamic> data;
        if (rawData is List) {
          data = rawData;
        } else {
          data =
              (rawData is Map ? rawData['data'] : null) as List<dynamic>? ?? [];
        }

        final parsedList = data.map((e) {
          final map = e as Map<String, dynamic>;
          // Don't keep the huge embedding array in memory for UI, just metadata
          return {
            'student_id': map['studentId']?.toString() ?? 'N/A',
            'student_code': map['studentCode'] ?? 'N/A',
            'person_name': map['personName'] ?? 'Unknown',
            'server_updated_at': map['updatedTime'] ?? 'N/A',
            'embedding_hash': map['embedding_hash'] ?? 'N/A',
          };
        }).toList();

        // Sort by name
        parsedList.sort((a, b) =>
            (a['person_name'] as String).compareTo(b['person_name'] as String));

        // Add proper debug log
        if (parsedList.isNotEmpty) {
          final faceNames = parsedList
              .map((e) => "${e['person_name']} (ID: ${e['student_id']})")
              .toList();
          await pushLog('[DEBUG] Các khuôn mặt có trên Server: $faceNames');
        }

        if (mounted) {
          setState(() {
            _serverFaces = parsedList;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = "Lỗi HTTP: ${response.statusCode}";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Lỗi Exception: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Server Face Status',
            style: TextStyle(
                color: AppColors.slate900,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.slate900),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.slate200, height: 1.0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchServerFaces,
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.red, size: 48),
              const SizedBox(height: 16),
              Text('Không thể tải dữ liệu server',
                  style: TextStyles.blackNormalBold.copyWith(fontSize: 16)),
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyles.blackNormalRegular
                      .copyWith(color: AppColors.slate500),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchServerFaces,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white),
              )
            ],
          ),
        ),
      );
    }

    if (_serverFaces.isEmpty) {
      return const Center(
        child: Text('Không có khuôn mặt nào trên server.',
            style: TextStyle(color: AppColors.slate500)),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.blue.withOpacity(0.05),
          width: double.infinity,
          child: Text(
            'Tổng cộng: ${_serverFaces.length} khuôn mặt',
            style: TextStyles.blackNormalBold.copyWith(color: AppColors.blue),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _serverFaces.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final face = _serverFaces[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slate200),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            face['person_name'],
                            style: TextStyles.blackNormalBold
                                .copyWith(fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.green100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ID: ${face['student_id']}',
                            style: TextStyles.blackNormalBold.copyWith(
                                fontSize: 12, color: AppColors.green600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                        'Mã SV/PIN:', face['student_code'].toString()),
                    const SizedBox(height: 4),
                    _buildInfoRow(
                        'Cập nhật lúc:', face['server_updated_at'].toString()),
                    const SizedBox(height: 4),
                    _buildInfoRow('Hash:', face['embedding_hash'].toString(),
                        maxLines: 1),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {int? maxLines}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.slate900,
                fontWeight: FontWeight.w500),
            maxLines: maxLines,
            overflow: maxLines != null ? TextOverflow.ellipsis : null,
          ),
        ),
      ],
    );
  }
}
