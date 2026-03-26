import 'package:collection/collection.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/pending_edu_check_in.dart';
import 'package:face_time_keeping/entities/person.dart';
import 'package:face_time_keeping/entities/tenant.dart';
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
  Future<void> deletePerson(int studentId);
  Future<void> updatePerson(Person person);
  Future<void> clearPersons();
  Future<List<CheckInOut>> getUnSyncedCheckInOuts();
  Future<void> updateCheckInOutFlag(int ioId, bool isSynced);
  Future<void> init(String tenantKey);
  Future<int> addTenant(Tenant tenant);
  Future<int?> getTenantId(String url, String dbName);
  Future<List<Person>> getAllPersons();
  Future<void> refreshCheckInOutBox();
  Future<void> refreshPersonBox();
  Future<void> updatePersonSynced(int studentId, bool isSynced);
  Future<void> cloneDataFromOldTenant(String oldTenantKey, String newTenantKey);

  // --- EDU Pending Check-In (offline queue) ---
  Future<int> savePendingEduCheckIn(PendingEduCheckIn item);
  Future<List<PendingEduCheckIn>> getPendingEduCheckIns();
  Future<void> markEduCheckInSynced(String localId);
  Future<void> incrementEduRetryCount(String localId);
  Future<void> clearSyncedEduCheckIns();
}

@LazySingleton(as: HiveService)
class HiveServiceImplement implements HiveService {
  static const String _checkInOutBoxName = 'checkIO_box';
  static const String _personBoxName = 'person_box';
  static const String _tenantBoxName = 'tenant_box';
  static const String _pendingEduBoxName = 'pending_edu_checkin_box';
  Box<CheckInOut>? _checkInOutBox;
  Box<Person>? _personBox;
  Box<PendingEduCheckIn>? _pendingEduBox;
  late final Future<Box<Tenant>> _tenantBox;
  String? _tenantKey;

  HiveServiceImplement() {
    _tenantBox = Hive.openBox<Tenant>(_tenantBoxName);
  }

  @override
  Future<void> init(String tenantKey) async {
    try {
      if (_tenantKey != null && tenantKey == _tenantKey) return;
      _tenantKey = tenantKey;
      if (_checkInOutBox?.isOpen ?? false) {
        await _checkInOutBox?.close();
      }
      if (_personBox?.isOpen ?? false) {
        await _personBox?.close();
      }
      _checkInOutBox =
          await Hive.openBox<CheckInOut>('$_checkInOutBoxName-$_tenantKey');

      _personBox = await Hive.openBox<Person>('$_personBoxName-$_tenantKey');
    } catch (e, stackTrace) {
      await pushLog('Error initializing Hive: $e\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> refreshCheckInOutBox() async {
    try {
      await checkTenantKey();
      if (_checkInOutBox?.isOpen ?? false) {
        await _checkInOutBox?.close();
      }
      _checkInOutBox =
          await Hive.openBox<CheckInOut>('$_checkInOutBoxName-$_tenantKey');
    } catch (e, stackTrace) {
      await pushLog('Error refreshing CheckInOut box: $e\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> refreshPersonBox() async {
    try {
      await checkTenantKey();
      if (_personBox?.isOpen ?? false) {
        await _personBox?.close();
      }
      _personBox = await Hive.openBox<Person>('$_personBoxName-$_tenantKey');
    } catch (e, stackTrace) {
      await pushLog('Error refreshing Person box: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<void> checkTenantKey() async {
    try {
      if (_tenantKey == null) {
        final tenantId = await getIt<LocalService>().getTenantId();
        _tenantKey = tenantId.toString();
      }
    } catch (e, stackTrace) {
      await pushLog('Error in checkTenantKey: $e\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<List<Person>> getAllPersons() async {
    await checkTenantKey();
    _personBox ??= await Hive.openBox<Person>('$_personBoxName-$_tenantKey');
    final result = _personBox!.values.toList();
    return result;
  }

  @override
  Future<int> addTenant(Tenant tenant) async {
    final box = await _tenantBox;
    return await box.add(tenant);
  }

  @override
  Future<int?> getTenantId(String url, String dbName) async {
    try {
      final box = await _tenantBox;
      final tenant = box.values
          .firstWhereOrNull((e) => e.url == url && e.databaseName == dbName);
      return tenant?.key;
    } catch (e, stackTrace) {
      await pushLog('Error getting tenant: $e\n$stackTrace');
      return null;
    }
  }

  @override
  Future<void> updateCheckInOutFlag(int ioId, bool isSynced) async {
    try {
      await checkTenantKey();
      _checkInOutBox ??=
          await Hive.openBox<CheckInOut>('$_checkInOutBoxName-$_tenantKey');
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
    await checkTenantKey();
    _checkInOutBox ??=
        await Hive.openBox<CheckInOut>('$_checkInOutBoxName-$_tenantKey');
    final id = await _checkInOutBox!.add(checkInOut);
    return id;
  }

  @override
  Future<CheckInOut?> getCheckInOut(int id) async {
    await checkTenantKey();
    _checkInOutBox ??=
        await Hive.openBox<CheckInOut>('$_checkInOutBoxName-$_tenantKey');
    final checkInOut = _checkInOutBox!.get(id);
    if (checkInOut == null) return null;
    return checkInOut.copyWith(id: id);
  }

  @override
  Future<List<CheckInOut>> getAllCheckInOuts() async {
    await checkTenantKey();
    _checkInOutBox ??=
        await Hive.openBox<CheckInOut>('$_checkInOutBoxName-$_tenantKey');
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
    await checkTenantKey();
    _checkInOutBox ??=
        await Hive.openBox<CheckInOut>('$_checkInOutBoxName-$_tenantKey');
    final entries = _checkInOutBox!.toMap().entries;
    final items =
        entries.map((e) => e.value.copyWith(id: e.key)).toList(growable: false);
    if (date == null) return items;
    final filtered = items.where((e) => e.time.isAfter(date)).toList();
    return filtered;
  }

  @override
  Future<void> updateCheckInOut(CheckInOut checkInOut) async {
    await checkTenantKey();
    _checkInOutBox ??=
        await Hive.openBox<CheckInOut>('$_checkInOutBoxName-$_tenantKey');
    await _checkInOutBox!.put(checkInOut.id, checkInOut);
  }

  @override
  Future<void> deleteCheckInOut(int id) async {
    await checkTenantKey();
    _checkInOutBox ??=
        await Hive.openBox<CheckInOut>('$_checkInOutBoxName-$_tenantKey');
    await _checkInOutBox!.delete(id);
  }

  @override
  Future<void> clearCheckInOut() async {
    await checkTenantKey();
    _checkInOutBox ??=
        await Hive.openBox<CheckInOut>('$_checkInOutBoxName-$_tenantKey');
    await _checkInOutBox!.clear();
  }

  // Person methods
  @override
  Future<void> savePerson(Person person) async {
    await checkTenantKey();
    _personBox ??= await Hive.openBox<Person>('$_personBoxName-$_tenantKey');

    await _personBox!.put(person.studentId, person);
  }

  @override
  Future<Person?> getPerson(int studentId) async {
    await checkTenantKey();
    _personBox ??= await Hive.openBox<Person>('$_personBoxName-$_tenantKey');
    return _personBox!.get(studentId);
  }

  @override
  Future<void> updatePerson(Person person) async {
    await checkTenantKey();
    _personBox ??= await Hive.openBox<Person>('$_personBoxName-$_tenantKey');
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
    await checkTenantKey();
    _personBox ??= await Hive.openBox<Person>('$_personBoxName-$_tenantKey');
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
      await checkTenantKey();
      _personBox ??= await Hive.openBox<Person>('$_personBoxName-$_tenantKey');
      // clear all person
      await _personBox!.clear();
    } catch (e, stackTrace) {
      await pushLog('Error clearing persons: $e\n$stackTrace');
    }
  }

  @override
  Future<void> updatePersonSynced(int studentId, bool isSynced) async {
    try {
      await checkTenantKey();
      _personBox ??= await Hive.openBox<Person>('$_personBoxName-$_tenantKey');
      final currentPerson = _personBox!.get(studentId);
      await _personBox!.put(
          studentId,
          Person(
            studentId: studentId,
            updatedTime: DateTime.now(),
            isSynced: isSynced,
            name: currentPerson?.name ?? '',
            pin: currentPerson?.pin,
            jobTitle: currentPerson?.jobTitle,
          ));
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
    await checkTenantKey();
    _pendingEduBox ??= await Hive.openBox<PendingEduCheckIn>('$_pendingEduBoxName-$_tenantKey');
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
      await box.put(entry.key, entry.copyWith(retryCount: entry.retryCount + 1));
    }
  }

  @override
  Future<void> clearSyncedEduCheckIns() async {
    final box = await _getPendingEduBox();
    final syncedKeys = box.toMap().entries
        .where((e) => e.value.isSynced)
        .map((e) => e.key)
        .toList();
    await box.deleteAll(syncedKeys);
  }

  @override
  Future<void> cloneDataFromOldTenant(
      String oldTenantKey, String newTenantKey) async {
    try {
      // Open old tenant boxes
      final oldPersonBox =
          await Hive.openBox<Person>('$_personBoxName-$oldTenantKey');
      final oldCheckInOutBox =
          await Hive.openBox<CheckInOut>('$_checkInOutBoxName-$oldTenantKey');

      // Open new tenant boxes
      final newPersonBox =
          await Hive.openBox<Person>('$_personBoxName-$newTenantKey');
      final newCheckInOutBox =
          await Hive.openBox<CheckInOut>('$_checkInOutBoxName-$newTenantKey');

      // Clone Person data
      if (oldPersonBox.isNotEmpty) {
        await pushLog(
            'Cloning ${oldPersonBox.length} persons from old tenant to new tenant');
        for (final person in oldPersonBox.values) {
          await newPersonBox.add(person.copyWith(isSynced: false));
        }
      }

      // Clone CheckInOut data
      if (oldCheckInOutBox.isNotEmpty) {
        await pushLog(
            'Cloning ${oldCheckInOutBox.length} check-in/out records from old tenant to new tenant');
        for (final checkInOut in oldCheckInOutBox.values) {
          await newCheckInOutBox.add(checkInOut.copyWith());
        }
      }

      // Close old boxes
      await oldPersonBox.clear();
      await oldCheckInOutBox.clear();
      await oldPersonBox.close();
      await oldCheckInOutBox.close();

      // Update current references to new boxes
      _personBox = newPersonBox;
      _checkInOutBox = newCheckInOutBox;
      _tenantKey = newTenantKey;

      await pushLog(
          'Successfully cloned data from tenant $oldTenantKey to $newTenantKey');
    } catch (e, stackTrace) {
      await pushLog('Error cloning data from old tenant: $e\n$stackTrace');
      rethrow;
    }
  }
}
