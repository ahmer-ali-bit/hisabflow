Future<String?> readEnvelope() async => null;
Future<void> writeEnvelope(String value) async => throw UnsupportedError('Local vault is not supported on this target.');
Future<void> deleteEnvelope() async {}
