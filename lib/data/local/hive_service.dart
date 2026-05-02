import 'package:collection/collection.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/entities/pending_edu_check_in.dart';
import 'package:face_time_keeping/entities/person.dart';
import 'package:hive/hive.dart';
import 'package:face_time_keeping/entities/check_in_out.dart';
import 'package:injectable/injectable.dart';

abstract class HiveService {
  Future<int> saveCheckInOut(CheckInOut checkInOut);
  Future<List<CheckInOut>> getAllCheckInOuts();
  Future<List<CheckInOut>> getCheckInOutsOnOrAfter(DateTime? date);
  Future<CheckInOut?> getCheckInOut(int id);
  Future<void> deleteCheckInOut(int id);
  Future<void> updateCheckInOut(CheckInOut checkInOut);
  Future<void> dispose();
  Future<void> clearCheckInOut();
  Future<void> savePerson(Person person);
  Future<Person?> getPerson(int studentId);
  Future<Person?> getPersonByPin(String pin);
  Future<void> deletePerson(int studentId);
  Future<void> updatePerson(Person person);
  Future<void> clearPersons();
  Future<List<CheckInOut>> getUnSyncedCheckInOuts();
  Future<void> updateCheckInOutFlag(int ioId, bool isSynced);
  Future<void> init();
  Future<List<Person>> getAllPersons();
  Future<void> refreshCheckInOutBox();
  Future<void> refreshPersonBox();
  Future<void> updatePersonSynced(int studentId, bool isSynced);

  // --- EDU Pending Check-In (offline queue) ---
  Future<int> savePendingEduCheckIn(PendingEduCheckIn item);
  Future<List<PendingEduCheckIn>> getPendingEduCheckIns();
  Future<void> markEduCheckInSynced(String localId);
  Future<void> incrementEduRetryCount(String localId);
  Future<void> clearSyncedEduCheckIns();
  Future<void> clearAllEduCheckIns();
  Future<void> deletePendingEduCheckInForRecord(CheckInOut checkInOut);
  Future<int> purgeInvalidEduCheckIns();
}

@LazySingleton(as: HiveService)
class HiveServiceImplement implements HiveService {
  static const String _checkInOutBoxName = 'checkIO_box';
  static const String _personBoxName = 'person_box';
  static const String _pendingEduBoxName = 'pending_edu_checkin_box';
  Box<CheckInOut>? _checkInOutBox;
  Box<Person>? _personBox;
  Box<PendingEduCheckIn>? _pendingEduBox;

  HiveServiceImplement() {}

  @override
  Future<void> init() async {
    try {
      if (_checkInOutBox?.isOpen ?? false) {
        await _checkInOutBox?.close();
      }
      if (_personBox?.isOpen ?? false) {
        await _personBox?.close();
      }
      _checkInOutBox = await Hive.openBox<CheckInOut>(_checkInOutBoxName);

      _personBox = await Hive.openBox<Person>(_personBoxName);
    } catch (e, stackTrace) {
      await pushLog('Error initializing Hive: $e\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> refreshCheckInOutBox() async {
    try {
      if (_checkInOutBox?.isOpen ?? false) {
        await _checkInOutBox?.close();
      }
      _checkInOutBox = await Hive.openBox<CheckInOut>(_checkInOutBoxName);
    } catch (e, stackTrace) {
      await pushLog('Error refreshing CheckInOut box: $e\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> refreshPersonBox() async {
    try {
      if (_personBox?.isOpen ?? false) {
        await _personBox?.close();
      }
      _personBox = await Hive.openBox<Person>(_personBoxName);
    } catch (e, stackTrace) {
      await pushLog('Error refreshing Person box: $e\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<List<Person>> getAllPersons() async {
    _personBox ??= await Hive.openBox<Person>(_personBoxName);
    final result = _personBox!.values.toList();
    return result;
  }

  @override
  Future<void> updateCheckInOutFlag(int ioId, bool isSynced) async {
    try {
      _checkInOutBox ??= await Hive.openBox<CheckInOut>(_checkInOutBoxName);
      final checkInOut = _checkInOutBox!.get(ioId);
      if (checkInOut != null) {
        await _checkInOutBox?.put(
            ioId, checkInOut.copyWith(isSynced: isSynced));
      }
    } catch (e, stackTrace) {
      await pushLog('Error updating CheckInOut flag: $e\n$stackTrace');
    }
  }

  @override
  Future<List<CheckInOut>> getUnSyncedCheckInOuts() async {
    final allCheckInOuts = await getAllCheckInOuts();
    return allCheckInOuts.where((e) => e.isSynced == false).toList();
  }

  // CheckInOut methods
  @override
  Future<int> saveCheckInOut(CheckInOut checkInOut) async {
    _checkInOutBox ??= await Hive.openBox<CheckInOut>(_checkInOutBoxName);
    final id = await _checkInOutBox!.add(checkInOut);
    return id;
  }

  @override
  Future<CheckInOut?> getCheckInOut(int id) async {
    _checkInOutBox ??= await Hive.openBox<CheckInOut>(_checkInOutBoxName);
    final checkInOut = _checkInOutBox!.get(id);
    if (checkInOut == null) return null;
    return checkInOut.copyWith(id: id);
  }

  @override
  Future<List<CheckInOut>> getAllCheckInOuts() async {
    _checkInOutBox ??= await Hive.openBox<CheckInOut>(_checkInOutBoxName);
    final entries = _checkInOutBox!.toMap().entries;
    final items =
        entries.map((e) => e.value.copyWith(id: e.key)).toList(growable: false);
    items.sort(
      (a, b) {
        final aTime = a.time;
        final bTime = b.time;
        return bTime.compareTo(aTime);
      },
    );

    return items;
  }

  @override
  Future<List<CheckInOut>> getCheckInOutsOnOrAfter(DateTime? date) async {
    _checkInOutBox ??= await Hive.openBox<CheckInOut>(_checkInOutBoxName);
    final entries = _checkInOutBox!.toMap().entries;
    final items =
        entries.map((e) => e.value.copyWith(id: e.key)).toList(growable: false);
    if (date == null) return items;
    final filtered = items.where((e) => e.time.isAfter(date)).toList();
    return filtered;
  }

  @override
  Future<void> updateCheckInOut(CheckInOut checkInOut) async {
    _checkInOutBox ??= await Hive.openBox<CheckInOut>(_checkInOutBoxName);
    await _checkInOutBox!.put(checkInOut.id, checkInOut);
  }

  @override
  Future<void> deleteCheckInOut(int id) async {
    _checkInOutBox ??= await Hive.openBox<CheckInOut>(_checkInOutBoxName);
    await _checkInOutBox!.delete(id);
  }

  @override
  Future<void> clearCheckInOut() async {
    _checkInOutBox ??= await Hive.openBox<CheckInOut>(_checkInOutBoxName);
    await _checkInOutBox!.clear();
  }

  // Person methods
  @override
  Future<void> savePerson(Person person) async {
    _personBox ??= await Hive.openBox<Person>(_personBoxName);

    await _personBox!.put(person.studentId, person);
  }

  @override
  Future<Person?> getPerson(int studentId) async {
    _personBox ??= await Hive.openBox<Person>(_personBoxName);
    return _personBox!.get(studentId);
  }

  @override
  Future<Person?> getPersonByPin(String pin) async {
    _personBox ??= await Hive.openBox<Person>(_personBoxName);
    return _personBox!.values.firstWhereOrNull((p) => p.pin == pin);
  }

  @override
  Future<void> updatePerson(Person person) async {
    _personBox ??= await Hive.openBox<Person>(_personBoxName);
    final key = (_personBox?.keys ?? []).firstWhereOrNull(
      (k) {
        final p = _personBox!.get(k);
        return p != null && p.studentId == person.studentId;
      },
    );
    if (key != null) {
      await _personBox!.put(key, person);
    }
  }

  @override
  Future<void> deletePerson(int studentId) async {
    _personBox ??= await Hive.openBox<Person>(_personBoxName);
    final key = (_personBox?.keys ?? []).firstWhereOrNull(
      (k) {
        final p = _personBox!.get(k);
        return p != null && p.studentId == studentId;
      },
    );
    if (key != null) {
      await _personBox!.delete(key);
    }
  }

  @override
  Future<void> clearPersons() async {
    try {
      _personBox ??= await Hive.openBox<Person>(_personBoxName);
      // clear all person
      await _personBox!.clear();
    } catch (e, stackTrace) {
      await pushLog('Error clearing persons: $e\n$stackTrace');
    }
  }

  @override
  Future<void> updatePersonSynced(int studentId, bool isSynced) async {
    try {
      _personBox ??= await Hive.openBox<Person>(_personBoxName);
      final currentPerson = _personBox!.get(studentId);
      if (currentPerson != null) {
        await _personBox!.put(
            studentId,
            currentPerson.copyWith(
              updatedTime: DateTime.now(),
              isSynced: isSynced,
            ));
      } else {
        await _personBox!.put(
            studentId,
            Person(
              studentId: studentId,
              updatedTime: DateTime.now(),
              isSynced: isSynced,
              name: '',
            ));
      }
    } catch (e, stackTrace) {
      await pushLog('Error updating person synced: $e\n$stackTrace');
      rethrow;
    }
  }

  // Utility methods
  @override
  Future<void> dispose() async {
    await _checkInOutBox?.close();
    await _personBox?.close();
    await _pendingEduBox?.close();
  }

  // --- EDU Pending Check-In ---

  Future<Box<PendingEduCheckIn>> _getPendingEduBox() async {
    _pendingEduBox ??=
        await Hive.openBox<PendingEduCheckIn>(_pendingEduBoxName);
    return _pendingEduBox!;
  }

  @override
  Future<int> savePendingEduCheckIn(PendingEduCheckIn item) async {
    final box = await _getPendingEduBox();
    return box.add(item);
  }

  @override
  Future<List<PendingEduCheckIn>> getPendingEduCheckIns() async {
    final box = await _getPendingEduBox();
    return box.values.where((e) => !e.isSynced).toList();
  }

  @override
  Future<void> markEduCheckInSynced(String localId) async {
    final box = await _getPendingEduBox();
    final entry = box.values.firstWhereOrNull((e) => e.localId == localId);
    if (entry != null) {
      await box.put(entry.key, entry.copyWith(isSynced: true));
    }
  }

  @override
  Future<void> incrementEduRetryCount(String localId) async {
    final box = await _getPendingEduBox();
    final entry = box.values.firstWhereOrNull((e) => e.localId == localId);
    if (entry != null) {
      await box.put(
          entry.key, entry.copyWith(retryCount: entry.retryCount + 1));
    }
  }

  @override
  Future<void> clearSyncedEduCheckIns() async {
    final box = await _getPendingEduBox();
    final syncedKeys = box
        .toMap()
        .entries
        .where((e) => e.value.isSynced)
        .map((e) => e.key)
        .toList();
    await box.deleteAll(syncedKeys);
  }

  @override
  Future<void> clearAllEduCheckIns() async {
    final box = await _getPendingEduBox();
    await box.clear();
  }

  @override
  Future<void> deletePendingEduCheckInForRecord(CheckInOut checkInOut) async {
    final box = await _getPendingEduBox();
    final entries = box.toMap().entries.where((entry) {
      final item = entry.value;
      final sameTimestamp = item.timestamp.millisecondsSinceEpoch ==
          checkInOut.time.millisecondsSinceEpoch;
      final sameStudent = item.studentId == checkInOut.studentId;
      final samePin = item.pin == checkInOut.pin ||
          (item.pin == null || item.pin!.isEmpty) &&
              (checkInOut.pin == null || checkInOut.pin!.isEmpty);
      final sameRoom = item.roomId == checkInOut.roomId ||
          (item.roomId == null || item.roomId!.isEmpty) &&
              (checkInOut.roomId == null || checkInOut.roomId!.isEmpty);

      return !item.isSynced &&
          sameTimestamp &&
          sameStudent &&
          samePin &&
          sameRoom;
    }).toList();

    await box.deleteAll(entries.map((entry) => entry.key));
  }

  @override
  Future<int> purgeInvalidEduCheckIns() async {
    final box = await _getPendingEduBox();
    int purgedCount = 0;
    final entries = box.toMap().entries.toList();
    for (final entry in entries) {
      final item = entry.value;
      if (item.studentId == 0 &&
          item.serverUserId == null &&
          (item.pin == null || item.pin!.isEmpty)) {
        await box.delete(entry.key);
        purgedCount++;
      }
    }
    return purgedCount;
  }
}
