# Legacy backup import

Verified Drive backup metadata: `balancedesk-manual-backup`, schema version 2, active year 2026, with customer records carrying `ledgerYear`, `isStockLedger`, and `useWeight`. No customer financial data is copied into this repository.

Importer supports legacy alternatives such as `clients`, `transactions`, snake_case properties, numeric booleans, stock buy/sell amounts and bag quantities. Before shipping restore, extend field mapping to the complete entry/opening/snapshot schema and add golden tests based on a redacted fixture. Any restore must parse and validate the entire document first, show counts and workspace/year, ask for confirmation, then atomically replace the selected workspace.
