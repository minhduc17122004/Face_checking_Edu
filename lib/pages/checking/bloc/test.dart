
// @injectable
// class WorkShiftService {
// final SharedPrefs _sharedPrefs;

// WorkShiftService(this._sharedPrefs);

// // Lưu thời gian ca làm việc
// Future<void> saveShiftTimes({
// required TimeOfDay morningStart,
// required TimeOfDay morningEnd,
// required TimeOfDay afternoonStart,
// required TimeOfDay afternoonEnd,
// required TimeOfDay nightStart,
// required TimeOfDay nightEnd,
// }) async {
// await _sharedPrefs.put<String>(SharedPrefsKey.morningStartTime, '${morningStart.hour}:${morningStart.minute.toString().padLeft(2, '0')}');
// await _sharedPrefs.put<String>(SharedPrefsKey.morningEndTime, '${morningEnd.hour}:${morningEnd.minute.toString().padLeft(2, '0')}');
// await _sharedPrefs.put<String>(SharedPrefsKey.afternoonStartTime, '${afternoonStart.hour}:${afternoonStart.minute.toString().padLeft(2, '0')}');
// await _sharedPrefs.put<String>(SharedPrefsKey.afternoonEndTime, '${afternoonEnd.hour}:${afternoonEnd.minute.toString().padLeft(2, '0')}');
// await _sharedPrefs.put<String>(SharedPrefsKey.nightStartTime, '${nightStart.hour}:${nightStart.minute.toString().padLeft(2, '0')}');
// await _sharedPrefs.put<String>(SharedPrefsKey.nightEndTime, '${nightEnd.hour}:${nightEnd.minute.toString().padLeft(2, '0')}');
// }

// // Lấy thời gian bắt đầu và kết thúc cho một ca cụ thể
// ShiftTime? getShiftTime(String shiftName) {
// switch (shiftName) {
// case 'Ca sáng':
// return ShiftTime(
// startTime: _getTimeOfDay(SharedPrefsKey.morningStartTime, const TimeOfDay(hour: 7, minute: 0)),
// endTime: _getTimeOfDay(SharedPrefsKey.morningEndTime, const TimeOfDay(hour: 15, minute: 0)),
// );
// case 'Ca chiều':
// return ShiftTime(
// startTime: _getTimeOfDay(SharedPrefsKey.afternoonStartTime, const TimeOfDay(hour: 13, minute: 0)),
// endTime: _getTimeOfDay(SharedPrefsKey.afternoonEndTime, const TimeOfDay(hour: 21, minute: 0)),
// );
// case 'Ca tối':
// return ShiftTime(
// startTime: _getTimeOfDay(SharedPrefsKey.nightStartTime, const TimeOfDay(hour: 22, minute: 0)),
// endTime: _getTimeOfDay(SharedPrefsKey.nightEndTime, const TimeOfDay(hour: 6, minute: 0)),
// );
// default:
// return null;
// }
// }

// // Lấy tất cả thời gian ca làm việc
// Map<String, ShiftTime> getAllShiftTimes() {
// return {
// 'Ca sáng': ShiftTime(
// startTime: _getTimeOfDay(SharedPrefsKey.morningStartTime, const TimeOfDay(hour: 7, minute: 0)),
// endTime: _getTimeOfDay(SharedPrefsKey.morningEndTime, const TimeOfDay(hour: 15, minute: 0)),
// ),
// 'Ca chiều': ShiftTime(
// startTime: _getTimeOfDay(SharedPrefsKey.afternoonStartTime, const TimeOfDay(hour: 13, minute: 0)),
// endTime: _getTimeOfDay(SharedPrefsKey.afternoonEndTime, const TimeOfDay(hour: 21, minute: 0)),
// ),
// 'Ca tối': ShiftTime(
// startTime: _getTimeOfDay(SharedPrefsKey.nightStartTime, const TimeOfDay(hour: 22, minute: 0)),
// endTime: _getTimeOfDay(SharedPrefsKey.nightEndTime, const TimeOfDay(hour: 6, minute: 0)),
// ),
// };
// }

// // Helper method để parse TimeOfDay từ string
// TimeOfDay _getTimeOfDay(String key, TimeOfDay defaultTime) {
// final timeString = _sharedPrefs.get<String>(key);
// if (timeString == null) return defaultTime;

// try {
// final parts = timeString.split(':');
// if (parts.length == 2) {
// final hour = int.parse(parts[0]);
// final minute = int.parse(parts[1]);
// return TimeOfDay(hour: hour, minute: minute);
// }
// } catch (e) {
// return defaultTime;
// }

// return defaultTime;
// }

// // Format TimeOfDay thành string HH:mm
// String formatTimeOfDay(TimeOfDay time) {
// return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
// }
// }

// // Model để lưu thời gian bắt đầu và kết thúc của ca
// class ShiftTime {
// final TimeOfDay startTime;
// final TimeOfDay endTime;

// ShiftTime({
// required this.startTime,
// required this.endTime,
// });

// String get startTimeString => '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
// String get en