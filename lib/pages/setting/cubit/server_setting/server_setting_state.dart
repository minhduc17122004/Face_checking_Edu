import 'package:face_time_keeping/common/enums/server_type.dart';

class ServerSettingState {
  final ServerType selected;
  final ServerType? saved;
  final bool isSaving;

  ServerSettingState(
      {this.selected = ServerType.none, this.saved, this.isSaving = false});

  ServerSettingState copyWith(
      {ServerType? selected, ServerType? saved, bool? isSaving}) {
    return ServerSettingState(
      selected: selected ?? this.selected,
      saved: saved ?? this.saved,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
