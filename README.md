![Olympus ChatWarden](Marketing/CurseForge/olympus-chatwarden-banner-v1.png)

# Olympus ChatWarden 1.0.2

**[Download 1.0.2](https://github.com/RegretnWoW/OlympusChatWarden/releases/tag/v1.0.2)** · **[Optional signed packs](rule-packs/README.md)** · **[User guide](OlympusChatWarden/README.md)** · **[Release notes](OlympusChatWarden-v1.0.2-Release-Notes.md)**

Built for Olympus, ChatWarden brings chat filtering, contact protection, personal mentions and Wanted encounter alerts into one Olympus-themed workspace. Review what was filtered, see why an action happened, and choose how much of the conversation you want to see.

Open ChatWarden through the Olympus launcher or type /ocw.

# Inside Olympus

Olympus 1.2.4 includes a native ChatWarden page with quick controls for Filtering, Shield, Alerts and Capture, plus a scrolling recent activity list. Click a recent entry to open it in ChatWarden and mark it read. Right-click the ChatWarden tab to open the full workspace.

The full workspace shows your Olympus connection status, guild and guild rank. Its Olympus button opens and focuses the Olympus window.

# Wanted encounters and quiet chat icons

Targeting or mousing over an attackable player on the consented Olympus Wanted list can create a local encounter alert. Optional sounds, popups and a per-player cooldown keep these adjustable. Encounters appear in Alerts, Overview and the compact recent activity list.

Exact full Wanted names in visible chat get a small icon with the listed bounty information on hover. These chat mentions do not create Wanted alerts, unread badges, sounds or popups.

Olympus owns the Wanted board. ChatWarden does not scan the surrounding area, submit sightings or automatically Shield or report listed players.

# Filtering that looks beyond a keyword

A topic being mentioned does not automatically mean it should be filtered. ChatWarden examines nearby wording to distinguish direct criticism, stronger attacks, supportive statements, questions and quoted discussion.

# Choose your filtering strength:

Mild: Leaves mild opinions visible, warns on stronger expressions, and hides recognized explicit threats.

Balanced: Warns on mild unwanted opinions, redacts stronger expressions, and hides recognized explicit threats.

Strict: Applies stronger actions to the same covered topics, including redacting mild eligible opinions and hiding stronger expressions.

Olympus Protection and King Protection are included. Optional author-signed rule packs add other categories and wording preferences.

# ChatWarden Shield

Keep unwanted contact from taking over your session.

Shield can respond to repeated trade requests, duel challenges, group invitations and whispers. It also includes checks for repeated messages, rapid chat, gold/service advertising and guild recruitment.

Use timed protection, manage shielded players, or allow trusted players to bypass Shield checks. Topic preferences and Gommage masks do not automatically shield someone.

# Catch your mentions

Your first name or full character name can trigger personal mention alerts across supported chat channels. No @ is needed, and Capture can stay off. Add custom nicknames or watch phrases for anything else you want to follow.

Mention alerts include unread badges, optional sound and optional toast notifications. Close typo matching is available for watch phrases; names and nicknames match exactly.

# Review everything in one place

The Olympus-themed workspace keeps each kind of activity easy to find:

Overview: Your combined recent activity.
Messages: Filtering activity, including warnings, replacements, redactions and hidden messages.
Alerts: Personal mentions and Wanted encounters, with separate views and settings.
Shield: Contact protection and spam incidents.
Capture: Optional local chat recording and bookmarks.
Reports: Saved filtering feedback you can review and export.

Filtered originals and read states survive reloads and logins. Why filtered? explains the matching evidence, and supported covered text can be revealed with Ctrl + left-click.

Hidden-message alerts start on. Redaction alerts start off. Both can be adjusted independently.

# Install or update

Exit WoW, extract **OlympusChatWarden-v1.0.2.zip** from the release into `Interface/AddOns`, and keep `WTF/SavedVariables`. Use the addon download rather than GitHub’s automatic Source code ZIP.

# Requirements and access

With Olympus 1.2.4, grant ChatWarden access in `/oly privacy` so Olympus can confirm membership. Protection pauses while permission is pending or declined, or membership is not confirmed. Older Olympus versions retain the local guild-name fallback. The native panel and Wanted features require Olympus 1.2.4. Saved data is retained when access pauses.

Optional rule packs must be imported separately through ChatWarden’s signature verification screen. Updating the addon does not update saved imports. Start with the clearly named files in [Import These Packs](rule-packs/Import%20These%20Packs), or download the pack ZIP from the release. Updates preserve your enabled choices and pack sensitivity.

# Update history

Updates keeps short release highlights with Previous update and Next update controls. The Launch Tour and User Guide have their own tabs.

# Help improve ChatWarden

Found a false positive or something the filter missed? Save a report with the original wording and the action you expected. Review exported text before sharing it.

ChatWarden is the foundation for the broader Olympus Warden direction: an Olympus-centered workspace for clearer activity, explainable decisions and useful protection. Additional intelligence and reporting features are planned; they are not part of this release.

Copyright (c) 2026 Regretn. See [LICENSE.txt](OlympusChatWarden/LICENSE.txt) for usage and distribution terms.
