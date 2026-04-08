/// Determines how a face data record from server should be processed locally.
///
/// Decision order in [shouldImport]:
///   1. Person not found → [fullImport]
///   2. Physical check (no local embedding) → [recover]
///   3. Hash mismatch → [fullImport]
///   4. Timestamp newer but same hash → [metadataOnly]
///   5. Nothing changed → [skip]
enum ImportMode {
  /// No action needed — local data is up-to-date.
  skip,

  /// Local embedding is physically missing — re-import regardless of timestamp.
  recover,

  /// Content has changed (hash mismatch or new person) — full write cycle.
  fullImport,

  /// Hash matches but server timestamp is newer — update only metadata
  /// (Person.serverUpdatedAt, name, pin) without touching FaceNative IO.
  metadataOnly,
}
