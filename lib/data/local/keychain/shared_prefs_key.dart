class SharedPrefsKey {
  static const String token = 'token';
  static const String refreshToken = 'refreshToken';
  static const String userId = 'userId';
  static const String loginId = 'loginId';
  static const String userEmail = 'userEmail';
  static const String userFullName = 'userFullName';
  static const String devices = 'devices';
  static const String deviceCode = 'deviceCode';
  static const String logs = 'logs';
  static const String domain = 'domain';
  static const String recentDomains = 'recentDomains';
  static const String morningTime = 'morningTime';
  static const String afternoonTime = 'afternoonTime';
  static const String nightTime = 'nightTime';
  static const String syncSchedules = 'syncSchedules';
  static const String licenseKey = 'licenseKey';
  static const String pinApp = 'pinApp';
  static const String dbName = 'dbName';
  static const String latestTimePullFaceData = 'latestTimePullFaceData';
  static const String syncFaceSchedule = 'syncFaceSchedule';
  static const String isInitializedDefaultData = 'isInitializedDefaultData';
  static const String serverType = 'serverType';
  static const String tempServerType = 'tempServerType';
  static const String savedCookied = 'savedCookied';
  static const String avatarPath = 'avatarPath';
  static const String userRole = 'userRole';
  static const String activeRoom = 'active_room';
  static const String activeRoomName = 'active_room_name';

  /// Comma-separated list of student PINs (studentCode) that were manually
  /// reset at local level.  importFaceData will skip re-importing embeddings
  /// for these PINs for ONE pull cycle, then clear the list automatically.
  static const String faceResetSkipPins = 'faceResetSkipPins';

  static const String pendingRecoveryStudentIds = 'pendingRecoveryStudentIds';

  /// TTL-based face sync lock — stores expiry timestamp (ISO-8601).
  /// Used instead of in-memory boolean to work across background isolates.
  static const String faceSyncLockExpiresAt = 'faceSyncLockExpiresAt';
}
