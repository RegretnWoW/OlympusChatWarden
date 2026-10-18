# Olympus Warden 1.1.1 installation and backup

1. Close WoW and use the included Windows backup tool to create a complete backup ZIP of your account's `WTF/Account/<account>/SavedVariables/OlympusChatWarden.lua`. This includes history, Relay reports and pending startup recovery together. Keep the ZIP outside the game installation.
2. Install the `OlympusChatWarden` folder from `OlympusWarden-v1.1.1.zip` into the correct game's `Interface/AddOns` directory. Keep the folder name unchanged. Do not install test evidence or preview screenshots as addon data.
3. Keep Olympus installed and grant Warden its permitted access through Olympus. The optional dependency declaration lets missing-addon guidance load; it does not bypass Olympus access requirements.
4. Open `/warden`. CommandWarden contains Overview, Modules, Performance and shared Settings. New installations start with Chat selected; existing module choices and recording consent are retained. Selecting a module does not enable recording automatically. Chat Capture starts off on a new installation.
5. Choose recording separately through ChronicleWarden's Recording settings. Duels have a separate opt-in. Existing history remains available while recording is paused.
6. Your current character validates first; other archived characters load when you request them. Chat reports current-character progress at 25/50/75/100%. Leave WoW running and let validation finish; Warden itself may stay closed.
7. Open IntelWarden once to prepare its ready identity index. Player-menu shortcuts can then open exact saved dossiers, notes, watchlist entries and shared activities. Missing or ambiguous identities do not select another player, and opening a menu starts no inspection.
8. Report a bug through RelayWarden > Support. Submit Report is the sending action; View Details is optional. Technical Details starts off. Your report and native character name reach the developer; saved gameplay history and private notes are not silently attached. My Reports tracks automatic retries and validated delivery.

The backup tool runs while WoW is closed. It restores one complete file and preserves a safety copy before replacing an existing file. Text export remains available for smaller histories but waits for pending startup recovery and requested character archives.

Startup recovery covers eligible previously consented events, not every gameplay activity. Overflow is explicit. Movement, inspections, some PvP details and full duel sessions remain outside startup capture. Normal logout/reload saves the recovery journal; a crash can lose unsaved observations.

Before switching to an older build, finish pending recovery and back up the complete file. Older TOCs do not declare the new startup journal and may omit it on a subsequent save. Use separate data copies or isolated installations for rollback tests. The published 1.1.0 package remains independently available and unchanged.
