# Fireside — backup and recovery

Integrated 76 qualification candidate; November 3, 2026. Native release approval is pending separately for Forever and Retail.

Exit WoW normally before replacing addon folders in Interface/AddOns. This is a supported update method; it must not reset your data. Install both OlympusChatWarden and FiresideRecovery. SavedVariables belong in the client's WTF/Account folder and must not be deleted during an addon update.

Before native testing, preserve a closed-client external copy of the complete main, auxiliary, FiresideRecovery and .bak files. Text history exports are selected history/profile parts, not complete backups of settings, privacy, conversations, Journal, Relay or the pending recording journal. Never test recovery on the only copy.

Athena's Safeguard always protects failed, missing, unsupported or unexpectedly smaller established data. It blocks replacement and checkpoint rotation rather than silently selecting an older save. Optional snapshots can be disabled; the protection and accepted-history membership marker remain active. Clearing optional copies preserves that marker.

Integrated 73 fixes a false recovery warning: startup recording reserves ID ranges before committing events. Later valid observations can fill those holes. New markers retain exact committed membership as compact interval text. Older markers can acquire membership only from a verified checkpoint whose event counts, profiles, sequence and both identity checksums match. No older content is restored by that upgrade. Without sufficient proof, recovery protection remains active.

Manual recovery checks supported schemas, canonical history and snapshot dependencies in bounded chunks. Pending v2 startup observations are dry-run through the actual replay/remapping algorithm on private copies; the original pending journal stays intact. Saved reading pages use the actual Journal cleaner, seal and lineage. Restoring history preserves the CURRENT sharing identity, replay counters and privacy denials, and disables capture/sharing until explicitly resumed. A missing current sharing identity needs separate recovery. Populated conversation/recollection archives and legacy v1 pending observations still require application recovery; the in-game rollback refuses unsupported cases with originals retained.

Normal pre-restore undo retains two complete generations. Damaged originals are exact-byte deduplicated in quarantine and never automatically evicted. At 20 unique originals or 1 GiB, further risky recovery is refused. Existing larger stores are preserved. Owner-scoped privacy erasure redacts that owner's checkpoints; unreadable quarantine makes that operation refuse safely. Some older record-level deletion paths still clear optional recovery copies; this remains an audit item.

WoW persists SavedVariables at its own save points, including logout/reload. In-memory snapshots and a separate addon file do not guarantee immediate disk writes. A crash can lose changes since the last completed native save. Actual disk/crash behavior, memory attribution and native gameplay still need independent Forever and Retail qualification. Preserve originals before rollback; older releases cannot read the encoded save format.

Integrated 74 also allows an explicit verified restore when the current primary has a failed byte checksum. The damaged envelope must first be preserved in quarantine. Undo marks that root as requiring recovery, rather than treating damaged content as a valid checkpoint. If retention fails or reaches its ceiling, restore remains refused without changing the primary.

Integrated 75 keeps admitted, already-decoded large roots in lossless compiler-safe form even when semantic validation blocks saving. That representation-only sealing does not repair records, initialize defaults, update expected-history markers or rotate checkpoints. Known startup-journal validation errors also prevent checkpoint rotation and appear in recovery health.

Integrated 76 preserves schema-valid zero-padded event identities exactly. Canonical numeric ranges and exceptional literal suffixes have separate exact membership. No record IDs are renamed during upgrade or protection. A newer numeric spelling cannot substitute for a previously accepted padded ID, or vice versa.
