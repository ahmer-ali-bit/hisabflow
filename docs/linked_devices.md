# Linked device security design

Local-first storage remains authoritative and works without a network. Linking is an opt-in feature, not an implicit cloud backup.

The included Supabase starter uses authenticated users, workspace-scoped membership rows and PostgreSQL row-level security. A production release must add device enrollment, key rotation/revocation, replay-safe change IDs, conflict handling, audit history and end-to-end payload encryption before turning sync on. Never place the Supabase service-role key in a client build. TLS and provider-side encryption alone are not end-to-end encryption.

Recommended linking flow: one already-authorized device creates a short-lived, one-use pairing code; new device authenticates independently and redeems it; the existing device approves a fingerprint; workspace data keys are wrapped for the new device; unlinking revokes its key and session. Keep encryption keys out of the database and backups unless separately password-encrypted by the user.
