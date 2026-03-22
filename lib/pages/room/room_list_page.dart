import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/utils/alerts.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/room.dart';
import 'package:face_time_keeping/pages/room/bloc/room_bloc.dart';
import 'package:face_time_keeping/pages/room/bloc/room_state.dart';
import 'package:face_time_keeping/pages/widgets/empty_state_widget.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';

class RoomListPage extends StatelessWidget {
  const RoomListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final roomBloc = getIt<RoomBloc>()..loadRooms();
    return BlocProvider.value(
      value: roomBloc,
      child: _RoomListView(roomBloc: roomBloc),
    );
  }
}

class _RoomListView extends StatefulWidget {
  final RoomBloc roomBloc;

  const _RoomListView({required this.roomBloc});

  @override
  State<_RoomListView> createState() => _RoomListViewState();
}

class _RoomListViewState extends State<_RoomListView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'QUẢN LÝ PHÒNG HỌC',
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
      body: BlocBuilder<RoomBloc, RoomState>(
        builder: (context, state) {
          if (state.requestStatus == RequestStatus.requesting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (state.requestStatus == RequestStatus.failed) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SelectableText.rich(
                    TextSpan(
                      text: state.message ?? 'Có lỗi xảy ra',
                      style: const TextStyle(color: AppColors.red),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      widget.roomBloc.loadRooms();
                    },
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (state.requestStatus == RequestStatus.success) {
            if (state.rooms.isEmpty) {
              return const EmptyStateWidget(
                title: 'Chưa có phòng học',
                subtitle: 'Nhấn nút + để thêm phòng học',
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                widget.roomBloc.loadRooms();
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.rooms.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (builderContext, index) {
                  return _RoomCard(
                    roomBloc: widget.roomBloc,
                    room: state.rooms[index],
                    overallContext: context,
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await AppNavigator.pushNamed(RouterName.roomForm);
          if (result == true && context.mounted) {
            widget.roomBloc.loadRooms();
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final RoomBloc roomBloc;
  final Room room;
  final BuildContext overallContext;

  const _RoomCard({
    required this.roomBloc,
    required this.room,
    required this.overallContext,
  });

  String _buildDisplayName() {
    final parts = <String>[];
    if (room.building != null && room.building!.isNotEmpty) {
      parts.add('Tòa ${room.building}');
    }
    if (room.floor != null) {
      parts.add('Tầng ${room.floor}');
    }
    if (room.capacity != null) {
      parts.add('${room.capacity} chỗ');
    }
    return parts.isEmpty ? '' : parts.join(' • ');
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa phòng học'),
        content: Text('Bạn có chắc muốn xóa phòng "${room.name}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await roomBloc.deleteRoom(room.id);
              if (overallContext.mounted) {
                if (success) {
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (overallContext.mounted) {
                    showTopAlert(overallContext,
                        title: 'Xoá phòng học thành công!',
                        type: AlertType.success);
                  }
                } else {
                  showTopAlert(overallContext,
                      title: roomBloc.state.message ?? 'Có lỗi xảy ra',
                      type: AlertType.error);
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await AppNavigator.pushNamed(
          RouterName.roomForm,
          arguments: room,
        );
        if (result == true && context.mounted) {
          roomBloc.loadRooms();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.teal50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.meeting_room,
                color: AppColors.teal600,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate900,
                    ),
                  ),
                  if (_buildDisplayName().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _buildDisplayName(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
              onPressed: () => _showDeleteConfirmation(context),
            ),
          ],
        ),
      ),
    );
  }
}
