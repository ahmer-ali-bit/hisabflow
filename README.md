# HisabFlow

Offline-first, cross-platform ledger app built with Flutter. Responsive navigation adapts between desktop/tablet navigation rail and compact mobile bottom navigation. The local vault uses AES-256-GCM with its key held in platform secure storage.

## Development

Requires Flutter 3.32+ and Dart 3.8+. Generate native platform runner folders once, then fetch dependencies:

```sh
./tool/bootstrap_platforms.sh
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

The app now includes a responsive overview, customer and ledger-entry management, ledger filters and balances, opening balances, stock/weight ledgers, independent local workspaces, year carry-forward, daily-log snapshots, workspace notes and company profile, encrypted local storage, JSON backup/restore and active-year CSV export. See the release checklist for platform-specific work still in progress. Flutter analysis, tests and target-platform builds must pass before release.

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

The app currently stays local and does not sync ledger data. The safest future direction is optional, end-to-end encrypted pairing while preserving offline use; do not enable cloud sync until pairing, revocation, conflict handling and membership policies are production-ready. See `docs/linked_devices.md` and `docs/release-checklist.md`.
