# HisabFlow

Offline-first, cross-platform ledger app built with Flutter. Responsive navigation adapts between desktop/tablet navigation rail and compact mobile bottom navigation. The local vault uses AES-256-GCM with its key held in platform secure storage.

## Development

Requires Flutter 3.22+ and Dart 3.4+. Generate native platform runner folders once, then fetch dependencies:

```sh
./tool/bootstrap_platforms.sh
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

The workspace currently includes the responsive overview, customer list/create flow, basic ledger-entry creation, customer ledger totals, daily-log listing, JSON backup/restore flow and the encrypted local persistence foundation. Broader requirements (year rollover, snapshot editing/recalculation, full export/print, biometric/PIN, workspace switching and production-grade linked-device sync) still need implementation and platform testing; the Supabase schema is a security starter, not a production sync service.

## Structure

- `lib/app`: app shell, theme and adaptive navigation entry point
- `lib/features/ledger/domain`: ledger entities, validation and deterministic calculations
- `lib/features/ledger/data`: persistence/import adapters
- `lib/core/security`: encrypted local vault
- `lib/features/dashboard`: responsive dashboard and customer workspace
- `supabase`: optional linked-device service schema and security notes
- `docs`: decisions, migration notes and release checklist

## Ledger JSON restore

The importer recognizes the Drive file's `balancedesk-manual-backup` version 2 envelope and maps customer/stock settings plus common entry fields. The original parsed payload is retained inside the encrypted workspace and included in subsequent JSON backups so unmapped legacy fields are not silently discarded. Restore is previewed and confirmed before replacing the active workspace. The user's financial file is not copied into this source repository.

## Linked devices

Linked devices require an authenticated relay and strict workspace membership checks. A cloud relay must not become the source of truth: each installation remains usable offline, and changes synchronize only after explicit device linking. See `docs/linked_devices.md`. Cloud keys and credentials must be supplied outside source control.
