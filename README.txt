Athena's Safeguard is part of Fireside. Install this folder beside OlympusChatWarden. It stores private local recovery checkpoints in a separate WoW SavedVariables file. It does not connect to a network.

Data-loss prevention is always active. Automatic snapshots can be disabled independently in setup or Settings > Data & backups. Snapshot frequency is every WoW save, at most hourly, or at most daily. Retention is 2, 5, or 10 copies. WoW persists these files on logout/reload; unsaved changes made after the last persisted state cannot be recovered after a crash.

A small independent presence marker remains active when snapshots are off or cleared. It records that a valid main save was expected, so a missing main file enters protected recovery instead of being mistaken for a first installation. The marker contains no history and is not a recovery copy. Without a valid persisted copy, missing history cannot be reconstructed.

Missing or corrupt primary saves recover from an intact checkpoint when available. Damaged sources are retained separately before replacement. If primary and recovery copies cannot be validated, Fireside protects the original files instead of replacing them with defaults. Use /fireside recovery for validated rollback. Clear-all history also clears recovery and retained-original copies. The separate recovery store is not included in data shared with peers.

This candidate changes the saved-data encoding. Earlier builds do not understand the encoding; retain a complete closed-client copy of all Fireside/Warden SavedVariables before changing versions. Native reload/crash qualification remains required.
