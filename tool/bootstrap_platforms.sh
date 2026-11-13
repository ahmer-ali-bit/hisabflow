#!/usr/bin/env sh
set -eu
# Run once after installing Flutter to generate canonical native runners for this package.
flutter create --project-name hisabflow --platforms=android,ios,web,linux,macos,windows .
# flutter create adds a sample test for its default MyApp class; HisabFlow has its own entry point.
if [ -f test/widget_test.dart ] && grep -q 'MyApp' test/widget_test.dart; then
  rm test/widget_test.dart
fi
