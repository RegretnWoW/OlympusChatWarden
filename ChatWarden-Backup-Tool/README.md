# ChatWarden Backup Tool for Windows

1. Exit WoW normally so it saves your latest history. Keep it closed.
2. Extract this tool ZIP and double-click **Open-ChatWarden-Backup.cmd**.
3. Choose your account's `WTF/Account/<account>/SavedVariables/OlympusChatWarden.lua`.
4. Confirm that WoW is closed and choose **Create one backup ZIP**.
5. Save that ZIP outside the WoW installation. Keep another copy on a different drive.

The tool copies the complete saved file without parsing or executing its Lua.
It verifies the copied bytes with SHA256. Backups contain all saved addon data:
settings, signed imports, captures, reports, Chronicle history and personal notes.
Keep them private. Nothing is uploaded. ZIP files are not encrypted.

To restore, keep WoW closed, choose **Restore a backup ZIP**, and select your own
trusted backup. Confirm the correct account destination. Existing data is saved
to a separate `ChatWarden-before-restore-...zip` beside your chosen backup first.
The staged restore is checked before the file is replaced, then verified again.
Restore replaces all saved choices, including recording consent; the addon
applies its usual permission and consent checks at next launch.

For a new installation, open WoW once with ChatWarden, exit normally, then select
the newly created saved file. The restore dialog can also create the file inside
an existing correct account SavedVariables folder. The tool does not install WoW
or ChatWarden and never creates an account folder on your behalf.

The `.lua.bak` file beside WoW's saved file is an optional older recovery copy.
This tool backs up the selected current `.lua` file. A crash may have left it older
than your last in-game activity; exit normally before making a backup.

The launcher uses Windows PowerShell with a policy setting limited to that process;
it does not change your computer's execution policy. No extra runtime is required.
Common WoW process names are checked, but your confirmation is still required.
The checksum detects copying errors; it does not authenticate someone else's backup.

In-game history-only text merge remains available when you want to combine history
without replacing other settings. Large complete backups should use the saved file.
