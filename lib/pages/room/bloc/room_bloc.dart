import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/data/remote/room_service.dart';
import 'package:face_time_keeping/pages/room/bloc/room_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

@injectable
class RoomBloc extends Cubit<RoomState> {
  RoomBloc(this._roomService) : super(RoomState());

  final RoomService _roomService;

  Future<void> loadRooms() async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _roomService.getRooms();
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        rooms: result.data ?? [],
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to load rooms',
      ));
    }
  }

  Future<void> createRoom({
    String? code,
    required String name,
    String? building,
    int? floor,
    int? capacity,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _roomService.createRoom(
      code: code,
      name: name,
      building: building,
      floor: floor,
      capacity: capacity,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedRoom: result.data,
      ));
      await loadRooms();
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to create room',
      ));
    }
  }

  Future<void> updateRoom({
    required String id,
    String? code,
    String? name,
    String? building,
    int? floor,
    int? capacity,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _roomService.updateRoom(
      id,
      code: code,
      name: name,
      building: building,
      floor: floor,
      capacity: capacity,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedRoom: result.data,
      ));
      await loadRooms();
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to update room',
      ));
    }
  }

  Future<bool> deleteRoom(String id) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _roomService.deleteRoom(id);
    if (result.isSuccess) {
      emit(state.copyWith(requestStatus: RequestStatus.success));
      await loadRooms();
      return true;
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to delete room',
      ));
      return false;
    }
  }
}
