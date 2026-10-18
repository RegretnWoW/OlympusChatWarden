# Olympus Warden 1.1.2 — Recording startup hotfix

Fixes a login timing issue that could leave ChronicleWarden and IntelWarden inactive after saved history loaded, even with recording enabled. Older records remained visible, but new events and inspected players could fail to save.

- Previously enabled recording resumes after validation even when Olympus access resolves during world entry.
- Login and reload state is retained while loading, without starting a second copy of an active session.
- `/warden chronicle check` gives a short recording-status report.
- Existing history, notes, watchlists, feature selections and consent are retained. No reset is needed.

Events missed while recording was inactive cannot be reconstructed. The complete-file Windows backup tool remains compatible.
