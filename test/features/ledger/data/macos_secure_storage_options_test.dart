import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS vault uses the login keychain without data-protection entitlements', () {
    const options = MacOsOptions(useDataProtectionKeyChain: false);
    expect(options.toMap()['useDataProtectionKeyChain'], 'false');
  });
}
