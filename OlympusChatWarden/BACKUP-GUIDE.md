# Back up your ChatWarden history

## Recommended: one complete saved file

1. Exit WoW normally and keep it closed.
2. Find `WTF/Account/<your account>/SavedVariables/OlympusChatWarden.lua` inside your WoW installation.
3. Copy that file to another drive or a safe backup folder outside WoW.

You can also use the separate optional **ChatWarden Backup Tool for Windows**:
extract its ZIP, open `Open-ChatWarden-Backup.cmd`, choose that saved file,
confirm WoW is closed, and create one dated ZIP. It verifies the copied bytes.
Nothing is uploaded. The tool never parses or executes the saved file's Lua.

## Restore

Keep WoW closed. The tool checks your backup and makes a safety ZIP of existing
data before restoring. Select the correct account destination. For a new PC,
start WoW once with ChatWarden and exit normally so its account folder and saved
file exist; then restore your older backup.

Without the tool, put your backup copy back at the same account path with WoW
closed. Keep a copy of the current file first.

A complete restore replaces **all** saved ChatWarden data: filters, signed imports,
captures, reports, recorded history, personal notes and recording choice. Normal
consent and Olympus access checks still apply at next launch.

## Useful details

- Keep backups outside the addon folder so updates cannot replace them.
- Keep another copy away from the PC you may format.
- The adjacent `.lua.bak` may be an extra older recovery copy.
- A crash can leave the latest session unsaved. Exit normally before backing up.
- Backups contain private player history and notes. ZIP files are not encrypted.
- Checksums detect copying errors; they do not authenticate someone else's file.
- The addon cannot create arbitrary files or launch the external Windows tool.

## When to use text merging

Recording > Backup & Restore > History-only text merge combines history without
replacing settings. It needs every numbered part, keeps existing notes and leaves
recording off. For a large complete backup, use the saved file instead.
