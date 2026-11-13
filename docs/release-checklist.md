# Release checklist

## Available locally

- [x] Encrypted, offline-first workspace storage
- [x] Customer and ledger-entry create/edit/delete/transfer flows
- [x] Stock and weight ledger calculations and opening balances
- [x] Ledger year creation, selection, deletion and balance carry-forward
- [x] Daily-log opening balances, snapshots, visibility controls and snapshot recalculation
- [x] JSON workspace backup/restore, formula-safe active-year CSV export and customer statement PDF printing
- [x] Workspace switching, company profile and private notes

## Before a production release

- [x] Run `flutter analyze` and `flutter test` on Flutter 3.44.0 in GitHub Actions
- [ ] Build and manually test macOS, Windows, Linux, Android, iOS and web targets
- [ ] Manually verify PDF pagination, printer selection, privacy and paper sizing on target platforms
- [ ] Add optional PIN/biometric app lock with platform-specific secure storage
- [ ] Implement a signed/manual update channel appropriate to each platform
- [ ] If linked devices are enabled, finish authenticated pairing, end-to-end key exchange, device revocation, replay protection, conflict resolution and membership-management RLS; keep sync off by default
- [ ] Review backup/export warnings and test restore from each supported legacy schema

Linked-device schema in `supabase/` is a starter only. Do not deploy it as a production sync service or add a service-role key to the client app. The application currently stores ledger data locally and does not synchronize it to a server.
