#!/usr/bin/env sh
set -eu
# Run once after installing Flutter to generate canonical native runners for this package.
flutter create --project-name hisabflow --platforms=android,ios,web,linux,macos,windows .
