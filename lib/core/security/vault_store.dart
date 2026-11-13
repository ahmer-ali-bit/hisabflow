/// Storage boundary for encrypted repository data. Implementations must keep
/// writes atomic so a failed save never leaves a partial ledger document.
abstract interface class VaultStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, Object?> document);
}
