# Quickstart

## Guild access

Filtering requires **Olympus** as a separate word in your current character's
guild name. This temporary local check is not proof of official affiliation.
The official Olympus check takes priority when available. Guild changes refresh
access automatically. Outside a qualifying guild, all ChatWarden features are
disabled, including recording, reports, exports and pack actions. Open tools
close and settings lock. `/ocw` explains the restriction. Saved data is kept;
access and previously enabled recording resume after the character qualifies.

## Review filtered chat

Open `/ocw inbox`. Select a message to read its original and clear its unread
badge. Spam and ad notifications start off. Hidden originals still appear here.
**Settings > ChatWarden > Notifications** controls badges and Shield chat notices.
**Why filtered?** shows the matched rules. **Report a problem** saves
feedback; a personal phrase rule changes filtering.

## Set contact protection

Open `/ocw shieldoptions`. Shield starts on with one set of contact protections.
Each protection can be switched off separately.
Repeated-whisper protection works
without a word-filter match or chat recording. Replying resets that sender's
repetition counter.

Use `/ocw shield` to review alerts, add or remove shields and allow players.
Supported player right-click menus provide the same shortcuts. Allowed players
bypass Shield; ordinary word filters still apply.

## Record and bookmark chat

1. Open `/ocw capture` and check the whisper and guild/officer recording switches.
2. Select **Start capture**. Recording continues across reloads until paused.
3. Select a captured line, enter a title or note, then **Save bookmark**.
4. Use **Show > Bookmarks** to review saved incidents.

Bookmarks include up to 10 already captured lines on each side. Future lines are
not added. Clearing the rolling capture keeps bookmarks. Limits: 5,000 captured
lines or 4 MB; 50 bookmarks or 1 MB. Battle.net, NPC and addon traffic are excluded.

Chat-name right-click menus can start or pause capture, open a player's captured
chat or bookmark the clicked message when that line is in the current capture.

## Export selected records

Use **Export shown**, **Export shields** or `/ocw export`. Select entries, choose
name and note settings, then review the final text. Make manual text edits last:
changing a selection or privacy option rebuilds the preview. Copy with Ctrl+C.
Nothing is sent automatically.

## Set language preferences

Open `/ocw languages`, turn on the master switch and check the languages you read.

- Low defaults to Redact detected text.
- High defaults to Hide message.
- Filter player names too starts off.
- Confidence always runs with a fixed four-letter minimum.

Both dropdowns also offer Label only and Leave visible. Hide removes the whole
qualifying line, including mixed messages. At least 85% non-preferred readable
letters uses the High action, even when only the writing system is known.

Enable name filtering to cover matching names alongside redacted text. English
and preferred-language replies stay visible with matching names covered. A name
alone never hides a reply. Label-only and Leave visible results keep names
readable. Choose Public, Whispers, Group and Guild coverage separately.

Covered names appear in Messages. Ctrl + left-click reveals or covers them;
right-click keeps native player actions. Only hidden messages in enabled
notification categories get unread badges.
Review and reports explain the detected language/script and selected action rule.
Exports provide a privacy preview. Protected labels may remain visible.

## Install signed imports

Open `/ocw packs`, use **Paste import**, then **Verify pack**. Review the result
and enabled state before **Install pack**. **Get packs link** provides the
download location. Updates apply to installed packs only and use the catalog
included with this addon build.

`/ocw help` opens the complete in-game guide. Floating-name Ctrl-click is
experimental and still needs in-game confirmation. Read originals in Messages
if a covered floating label does not respond.

## Spam protection

Open **Shield > Spam protection** in settings. Choose the checks and chat types to use.

- Rapid chat: 5 messages in 10 seconds. First burst pauses chat for 10 seconds; another new burst within a minute applies the timeout.
- Repeated messages: 3 similar messages in 30 seconds. Applies the timeout immediately.
- Gold/service ads: hides the ad and applies the timeout.
- Guild recruitment: hides the ad; Olympus guild names are exempt.

Counts and windows are fixed. Automatic timeout starts at 15 minutes and can be changed. All chat types start checked; existing channel choices are retained on upgrade. Use **Remove shield** to end a pause or timeout, or **Allow player** to bypass these checks.

Spam and ads stay quiet by default. **Notifications** has separate controls for repeated/rapid spam, contact protection, sales ads and recruitment ads. Filtering still runs when notifications are off.

In Review & Protection, **Help** and **Settings** stay in the same bottom-right positions across all tabs. Export is at the right of each toolbar. Saved reports and their export preview use newest-first order and matching report numbers.
