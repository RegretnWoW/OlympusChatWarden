# Olympus Warden 1.1.1

CommandWarden brings feature choices and performance controls together. RelayWarden adds in-game bug reporting, while current-character-first loading makes retained history available with less unnecessary startup work.

## CommandWarden and optional modules

- Choose Chat Only, Full Suite or individual features in CommandWarden > Modules. New installations start with Chat selected; existing selections are retained.
- Disable optional work without deleting history, dossiers, notes, watchlists or recording choices. Chat, Shield, Signal alerts and historical consumers have independent runtime gates.
- Overview, Modules, Performance and shared Settings sit in one control center. Module selection does not grant recording consent.
- Performance status separates Warden's client-attributed memory from the whole UI Lua heap. Profiling is optional and stays local to the current session.

## RelayWarden support

- Report a bug directly in game. Choose a module, enter a title and description, then Submit Report once. View Details is optional.
- My Reports shows Sending, Waiting to Deliver, Delivered and Needs Attention. Submitted reports retry automatically while you are online; Delivered requires a validated acknowledgment.
- Unfinished forms remain local across navigation and reload. Advanced Tools includes recovery of older unfinished text, diagnostics and developer self-tests.
- Optional Technical Details starts off for every new or switched form. Your report and native character name are shared with the developer. Chat, history, dossiers, locations and private notes are not silently attached.
- Support, Data & Backups and Help & Updates provide clear routes. Advanced delivery controls remain available when needed.

## Faster readiness and safer retained history

- Validate the current character first. Other packed archives remain intact until explicitly requested by a history view, search, backup or restore.
- Keep unopened character archives unchanged when saving. Invalid, duplicate, oversized or unsupported saved records fail explicitly instead of disappearing silently.
- Previously consented eligible startup observations use a separate local recovery journal. Normal logout/reload preserves accepted observations and retries recovery without duplicating committed records.
- Startup capture is bounded at 1,024 observations or 512 KiB of structural capture data. Recovery IDs add bounded metadata. Overflow is reported in chat and a saved coverage gap.
- Startup coverage remains partial: movement, inspection, scoreboard snapshots and complete duel sessions are not fully captured during validation. Missing events are not reconstructed. WoW must save normally; a crash can lose unsaved observations.
- Loading reports 25/50/75/100% for the current character without needing Warden open. Unloaded history is shown as unavailable rather than confirmed zero.

## Dossiers and interface polish

- Player menus can open exact retained Intel dossiers and shared Chronicle history using a ready identity index. Saved personal notes and watchlist entries now qualify for Intel shortcuts even without historical encounter events.
- Ambiguous names and different realms do not substitute another player. Menu opening starts no inspection, history scan or disabled module.
- Larger module crests, consistent activity artwork, explicit ON/OFF badges, adaptive Olympus navigation and clearer settings improve the suite's readability.
- Search uses CommandWarden wording and includes its module choices and performance controls. Chat Capture defaults off; existing preferences are preserved.

## Back up your history

The supplied Windows backup tool creates or restores one complete backup ZIP while WoW is closed. It includes main history, Relay reports and pending startup recovery in the existing account SavedVariables file. Text export waits for pending recovery and all requested archives.

The addon folder remains `OlympusChatWarden`; main history schema and consent stay compatible. Before switching to an older build, finish pending recovery and make a complete backup. Older TOCs do not declare the new startup journal and may omit it on a later save. Use isolated copies for rollback testing.

Olympus remains required for permitted gameplay access. It is an optional load dependency intentionally, allowing Warden to show missing-Olympus/access guidance instead of being disabled silently by the client.
