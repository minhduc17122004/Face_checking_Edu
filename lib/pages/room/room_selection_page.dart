import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/room.dart';
import 'room_session/bloc/room_session_bloc.dart';
import 'room_session/bloc/room_session_state.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';

class RoomSelectionPage extends StatelessWidget {
  const RoomSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = getIt<RoomSessionBloc>()..loadRooms();
    return BlocProvider.value(
      value: bloc,
      child: _RoomSelectionView(bloc: bloc),
    );
  }
}

class _RoomSelectionView extends StatefulWidget {
  final RoomSessionBloc bloc;

  const _RoomSelectionView({required this.bloc});

  @override
  State<_RoomSelectionView> createState() => _RoomSelectionViewState();
}

class _RoomSelectionViewState extends State<_RoomSelectionView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'CHỌN PHÒNG ĐIỂM DANH',
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
      body: BlocBuilder<RoomSessionBloc, RoomSessionState>(
        builder: (context, state) {
          if (state.requestStatus == RequestStatus.requesting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.requestStatus == RequestStatus.failed) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.red),
                  const SizedBox(height: 16),
                  Text(state.message ?? 'Lỗi tải danh sách phòng'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => widget.bloc.loadRooms(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (state.rooms.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.meeting_room_outlined,
                      size: 64, color: AppColors.slate500),
                  SizedBox(height: 16),
                  Text('Không có phòng nào được cấp phép',
                      style: TextStyle(color: AppColors.slate500)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => widget.bloc.loadRooms(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.rooms.length,
              itemBuilder: (context, index) {
                final room = state.rooms[index];
                return _buildRoomCard(room);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoomCard(Room room) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          AppNavigator.pushNamed(
            RouterName.roomSessions,
            arguments: room,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.meeting_room,
                    color: AppColors.blue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.slate500),
            ],
          ),
        ),
      ),
    );
  }
}
