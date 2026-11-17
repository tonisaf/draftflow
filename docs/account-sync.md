# Accounts and synchronization

Notes uses the same Supabase Auth project as Tasks Here, with separate session keys, database files, event journal and RPC. No Tasks tables or functions are changed.

## Deployment

The local public configuration is already in ignored `config/supabase.json`.

1. Open the shared Supabase project → **SQL Editor** → **New query**.
2. Paste and run the entire `supabase/notes_schema.sql`. The script is transactional and can be applied again. It creates Notes tables/policies and `notes_sync_push_v2`, and revokes the obsolete Notes v1 write RPC if present.
3. Start the new Notes build, sign in, and use **Синхронизировать** in the account dialog. Automatic polling also retries after setup.

The user applied the SQL on 2026-11-08 and reported success. The follow-up endpoint check returned HTTP 401 / 42501 for an anonymous request, confirming that the v2 RPC now exists and rejects anonymous execution. No user data was written by that check. Authenticated two-device testing remains to be completed. No admin credentials are needed in the app.

Do not expose a secret/service_role key in client configuration. In another checkout, copy `config/supabase.example.json` to `config/supabase.json` and supply only the project URL and public key.

```powershell
flutter pub get
flutter run -d windows --dart-define-from-file=config/supabase.json
# Configured debug build:
flutter build windows --debug --dart-define-from-file=config/supabase.json
# Distribution build:
flutter build windows --release --dart-define-from-file=config/supabase.json
```

The verified debug executable is `build/windows/x64/runner/Debug/notes_here.exe`. Keep its DLLs and data directory alongside it.

## Account behavior

- Email/password login, registration, email-confirmation feedback, logout and repeat login are implemented. The same credentials work in Tasks Here; the apps keep separate local sessions.
- Tokens use OS-protected storage, without a plaintext fallback. Vault failures are surfaced. Unexpired saved sessions restore into the SDK. An expired cold-start session permits access to cached notes but requests repeat login before networking; automatic recovery of that expired session remains future work.
- UUID-validated account-specific filenames separate guest and account data. Switching waits for mounted editors to save. The guest workspace is never silently copied or uploaded. Old database handles remain open for the process lifetime to allow captured late writes to finish against their original workspace.

## Sync protocol v2

- SQLite schema 11 upgrades prior queue metadata without changing pending operation IDs. The queue captures pages, blocks, databases and columns atomically through SQLite triggers. Search-index maintenance and editor drafts stay local.
- Each DB persists a random device ID, incoming cursor, accepted remote shadows, conflict records and recovery snapshots. Downloaded writes suppress outgoing capture within their transaction. Cursor advancement, conflict preservation, row application and acknowledgements commit together.
- The engine downloads until the journal returns an empty page, uploads a bounded batch, then reads acknowledgements from the journal. An upload response never advances the download cursor or removes local operations. A response lost after server commit is safe to retry.
- A batch carries at most the first pending operation for each entity; queued dependencies are visited before dependents. Subsequent local edits are rebased only after acknowledging this device's own earlier operation. New edits made during upload are retained.
- The server serializes appends per user, deduplicates immutable operation IDs and checks base sequence numbers. Stale writes are rejected atomically. It also guards deletion against unseen changes to descendants from another device and refuses insertion under deleted parents.
- Every request checks the backend identity against the repository owner before and after the request and pins that owner's bearer token in the request header. Logout/account switching stops the old worker before changing authentication. A late response after stop cannot change the old local database.
- Mounted editors are saved before applying an incoming batch. Input is briefly excluded during that save/apply boundary; network requests happen before the boundary. Affected clean documents reload, while uncommitted text becomes a normal queued local version and is preserved as a conflict. Unrelated pages do not reload the editor.
- Polling is every 20 seconds, local writes schedule a debounced sync, and a manual button is available. Requests time out after 20 seconds; the durable queue remains for retry.

## Conflicts and recovery

The first version uses conservative row/structure conflicts rather than CRDT merging. Different independent rows can converge automatically; competing writes to the same row or its structure require a choice.

The account dialog exposes **Разрешить конфликты**, showing device/cloud versions with selectable text. **Оставить мою** creates a new operation against the reviewed remote version; **Принять облачную** applies that version without echo. Changes to either reviewed version invalidate the choice and require reopening the comparison.

Before resolution, a full local workspace/draft/outbox snapshot is saved in `notes_sync_recovery`. **Копия до разрешения конфликта** exports the latest copy through a native save dialog. Its pages/blocks/tables are compatible with existing workspace JSON restore; extra recovery fields retain drafts and historical queued payloads. Restoration of those extra recovery fields is not automated.

Remote permanent deletion handles owned pages, databases and nested blocks. Pending descendant edits and drafts prevent automatic destructive application. Accepting a cloud subtree deletion explicitly clears its corresponding pending operations/conflicts after saving the recovery snapshot.

## Validation (2026-11-08)

- Windows debug build with the supplied public configuration passed.
- `flutter analyze --no-pub`: no issues.
- Full suite: 198 passed; three existing Windows temporary-SQLite cleanup failures remain (`database_paging_test` schema 8 and `incremental_blocks_test` schema 7, trashed true/false).
- New tests cover two clients, all four entity kinds with foreign keys enabled, offline retry, lost responses, in-flight edits, echo prevention, malformed-batch rollback, stale conflict choices, subtree deletion, actual recovery import, stopped workers, HTTP owner/cursor filters, RPC errors and v10→v11 migration.
- Widget tests verify clean-document reload and preservation of text entered before autosave. Their real asynchronous stream teardown runs outside the widget test's fake clock.
- PostgreSQL/WASM (PGlite 0.5.15) executes the actual SQL: nine checks cover CAS, immutable retries, rollback, RLS for two users, denied direct/anonymous writes and delete-versus-edit behavior. This is not a live two-device Supabase test or a multi-connection concurrency benchmark.

To repeat SQL checks without touching the hosted project:

```powershell
npm install --prefix build/tmp/sql-validation --no-audit --no-fund --ignore-scripts @electric-sql/pglite@0.5.15
node tools/check_sync_schema.mjs
```

Logs and the SQL test runtime stay under ignored `build/`. Remaining follow-ups: hosted two-device smoke test after SQL deployment, journal compaction/checkpoints and recovery retention UI, attachments, explicit guest import, finer-grained merging and collaborative editing. Single queued operations above 3 MiB are retained with an actionable error instead of being silently dropped.
