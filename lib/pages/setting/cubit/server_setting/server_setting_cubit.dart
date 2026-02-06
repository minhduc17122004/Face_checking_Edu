import 'package:bloc/bloc.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:injectable/injectable.dart';
import 'package:face_time_keeping/common/enums/server_type.dart';
import 'server_setting_state.dart';

@injectable
class ServerSettingCubit extends Cubit<ServerSettingState> {
  final LocalService _localService;

  ServerSettingCubit(this._localService) : super(ServerSettingState());

  Future<void> load() async {
    final saved = await _localService.getServerType();
    final selected = saved ?? ServerType.none;
    emit(state.copyWith(selected: selected, saved: saved));
  }

  void select(ServerType type) {
    emit(state.copyWith(selected: type));
  }

  Future<void> saveTemp() async {
    final toSave = state.selected;
    emit(state.copyWith(isSaving: true));
    await _localService.saveTempServerType(toSave);
    emit(state.copyWith(saved: toSave, isSaving: false));
  }

  Future<void> resetServerData() async {
    try {
      emit(state.copyWith(isSaving: true));

      // Clear all data
      await _localService.clearAllData();

      // Save server type as none
      await _localService.saveServerType(ServerType.none);
      await _localService.saveTempServerType(ServerType.none);

      // Update state
      emit(state.copyWith(
        selected: ServerType.none,
        saved: ServerType.none,
        isSaving: false,
      ));
    } catch (e) {
      emit(state.copyWith(isSaving: false));
      rethrow;
    }
  }
}
