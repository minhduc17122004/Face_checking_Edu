import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/entities/room.dart';

class RoomState {
  final RequestStatus requestStatus;
  final List<Room> rooms;
  final String? message;
  final Room? selectedRoom;

  RoomState({
    this.requestStatus = RequestStatus.initial,
    this.rooms = const [],
    this.message,
    this.selectedRoom,
  });

  RoomState copyWith({
    RequestStatus? requestStatus,
    List<Room>? rooms,
    String? message,
    Room? selectedRoom,
  }) {
    return RoomState(
      requestStatus: requestStatus ?? this.requestStatus,
      rooms: rooms ?? this.rooms,
      message: message,
      selectedRoom: selectedRoom ?? this.selectedRoom,
    );
  }
}
