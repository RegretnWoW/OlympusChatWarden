# Olympus ChatWarden

**CHUDS WITHOUT BORDERS**

A customizable text-filtering and personal protection addon for World of Warcraft: Forever, built for the Olympus community.

ChatWarden gives players control over their own viewing experience. It doesn't label words or opinions as harmful, judge other players, or decide what anyone should be allowed to say.


## Features

- Four filtering presets: **Selective, Balanced, Broad, and Gommage**.
- Context-aware phrase matching and selected spelling-variation detection.
- Warnings, redaction, replacements, and message hiding.
- Ctrl-click reveal for supported covered text.
- Optional filtering for chat, quests, dialogue, tooltips, and names.
- Built-in Olympus Protection and King Protection categories.
- Signed optional rule packs with independent sensitivity settings.
- Personal phrase rules and exceptions.
- Built-in barber and body-type wording replacements.
- Message Review with reporting and individual unread notifications.
- Native Olympus integration with guild membership verification.

**Gommage** uses a separate display list to cover selected terminology without increasing filtering confidence or automatically hiding entire messages.

<img width="850" height="582" alt="ChatWarden-Message-Review" src="https://github.com/user-attachments/assets/89fa8a3a-dce2-42b2-875a-e8f0b8c5c176" />

<img width="850" height="640" alt="ChatWarden-Personal-Rules" src="https://github.com/user-attachments/assets/8fcec8d2-62bb-4b15-9aba-6d523b623930" />


## ChatWarden Shield

Shield provides optional local protection against repeated contact.

- **Normal Harassment** and **Streamer** profiles.
- Configurable protection for qualifying whispers, trade requests, duel requests, and group invites.
- Automatic or manual player shields.
- Timed, session-based, and indefinite manual protection.
- An Allowed list for players you trust.
- Recent alerts and player management in **Review > Shield**.

An optional OlympusMute signal feature records compatible list-sharing activity actually received by your client. It does not determine whether someone is muting you.

<img width="1448" height="1086" alt="Olympus ChatWarden Interface Panel" src="https://github.com/user-attachments/assets/c2b0f4c8-e1ca-4f42-8844-e05e2f55e1a5" />

## Chat capture

Record, search and export player chat from a new tab in Review & protection. Recordings stay saved across reloads until cleared or the storage limit is reached.

 - Incident bookmarks: Save a message with up to 10 surrounding lines on either side, plus an optional title and note.
 - Right-click capture controls: Start or pause recording, view a player’s captured chat, or bookmark the clicked message.
 - Export privacy controls: Preview exports, choose entries, hide known player names, omit notes and edit the final text before copying.
 - Private-chat recording options: Choose whether to include whispers and guild/officer chat.

<img width="850" height="597" alt="download" src="https://github.com/user-attachments/assets/acd522c0-9883-4bed-9a7b-d15fd86004e7" />

## Language Confidence Filtering

Keep shared-server chat focused on languages you can read. ChatWarden can cover detected text or hide qualifying messages while keeping originals available in Review.

- Optional language filtering, off by default, with English allowed.
- Choose additional supported languages and writing systems to allow.
- Default actions: uncertain text stays visible, medium confidence covers detected portions, and high confidence hides qualifying messages.
- Hidden originals remain available in Messages.
- Mixed messages preserve readable English where identified.
- Customize actions, minimum text length and chat coverage.
- Review shows the detected language or writing system, confidence and an Allow language shortcut.
- Language explanations are included in saved reports and exports.
- Works independently of word-filter scores, Shield and chat capture.

## Olympus Integration
 - ChatWarden opens directly through the Olympus addon. The Review window includes separate Messages and Shield tabs, keeping everything in one place.
 - An active Olympus guild membership is required.

<img width="488" height="850" alt="ChatWarden-Notification-Badge" src="https://github.com/user-attachments/assets/e1e8659b-0a5d-45e9-89a7-b4bbc81b8756" />


## Installation

1. Install the compatible Olympus addon.
2. Download the latest ChatWarden release.
3. Extract `OlympusChatWarden` into `Interface/AddOns`.
4. Open Olympus and select ChatWarden, or type `/ocw`.
5. Configure your filtering and Shield preferences.

An active, verified Olympus guild membership is required.


## Optional Rule Packs

Additional categories are distributed as author-signed rule packs.

Open `/ocw packs`, paste the complete signed pack text, verify it, then install and enable it.

The current optional packs use **version 6**. Updating the addon does not automatically update imported packs.


## Commands

| Command | Function |
|---|---|
| `/ocw` | Settings |
| `/ocw help` | In-game guide |
| `/ocw inbox` | Review messages |
| `/ocw shield` | Shield dashboard |
| `/ocw shieldoptions` | Shield settings |
| `/ocw packs` | Rule pack manager |
| `/ocw preview` | Test filtering |
| `/ocw report` | Report a mistake |
| `/ocw export` | Export reports |
| `/ocw status` | Addon status |


## Feedback

Bug reports, filtering mistakes, and suggestions are welcome.

[Open a GitHub Issue](https://github.com/RegretnWoW/OlympusChatWarden/issues)

Include your addon version and an exported report or reproduction steps when possible.

Everything is handled locally. Reports aren't automatically uploaded or shared.


## Disclaimer

ChatWarden is a personal viewing and contact-management tool, not a content moderation system. Its categories don't represent judgments about the content or people being filtered.
