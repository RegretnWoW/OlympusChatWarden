# Olympus ChatWarden

**CHUDS WITHOUT BORDERS**

A customizable text-filtering and personal protection addon for World of Warcraft: Forever, built for the Olympus community.

ChatWarden gives players control over their own viewing experience. It doesn't label words or opinions as harmful, judge other players, or decide what anyone should be allowed to say.


[Download rc49](https://github.com/RegretnWoW/OlympusChatWarden/releases/tag/v0.9.0-rc49) · [Optional signed packs](rule-packs/README.md)

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
- Native Olympus integration with guild access checks.

**Gommage** uses a separate display list to cover selected terminology without increasing filtering confidence or automatically hiding entire messages.

<img width="850" height="582" alt="ChatWarden-Message-Review" src="https://github.com/user-attachments/assets/89fa8a3a-dce2-42b2-875a-e8f0b8c5c176" />

<img width="850" height="640" alt="ChatWarden-Personal-Rules" src="https://github.com/user-attachments/assets/8fcec8d2-62bb-4b15-9aba-6d523b623930" />


## ChatWarden Shield

Shield provides optional local protection against repeated contact.

- One set of normal contact protections; existing Streamer settings move to normal thresholds.
- Configurable protection for qualifying whispers, trade requests, duel requests, and group invites.
- Automatic or manual player shields.
- Timed, session-based, and indefinite manual protection.
- An Allowed list for players you trust.
- Recent alerts and player management in **Review > Shield**.

An optional OlympusMute signal feature records compatible list-sharing activity actually received by your client. It does not determine whether someone is muting you.

<img width="1448" height="1086" alt="Olympus ChatWarden Interface Panel" src="https://github.com/user-attachments/assets/c2b0f4c8-e1ca-4f42-8844-e05e2f55e1a5" />

## Spam protection and notifications

- Hide gold-selling, paid-service and guild recruitment ads, with Olympus recruitment exceptions.
- Repeated-message detection and rapid-chat protection with a brief first-burst pause before a full timeout.
- Adjustable automatic timeout and separate chat-channel switches.
- Separate notification choices for wording/language filtering, contact protection, repeated/rapid chat and each advertising type.
- Spam and ads stay quiet by default. Hidden originals remain available in Messages.
- Consistent Help, Settings and Export placement across Review & Protection tabs.

## Chat capture

Record, search and export player chat from a new tab in Review & Protection. Recordings stay saved across reloads until cleared or the storage limit is reached.

 - Incident bookmarks: Save a message with up to 10 surrounding lines on either side, plus an optional title and note.
 - Right-click capture controls: Start or pause recording, view a player’s captured chat, or bookmark the clicked message.
 - Export privacy controls: Preview exports, choose entries, hide known player names, omit notes and edit the final text before copying.
 - Private-chat recording options: Choose whether to include whispers and guild/officer chat.

<img width="850" height="597" alt="download" src="https://github.com/user-attachments/assets/acd522c0-9883-4bed-9a7b-d15fd86004e7" />

## Language Confidence Filtering

Keep shared-server chat focused on languages you can read. ChatWarden can cover detected text or hide qualifying messages while keeping originals available in Review.

- Optional language filtering, off by default, with English allowed.
- Choose additional supported languages and writing systems to allow.
- Default actions: low confidence covers detected portions; high confidence or mostly non-preferred text hides the message. Optional name covering follows the same reading preferences.
- Hidden originals remain available in Messages.
- Mixed messages preserve readable English where identified.
- Choose Low and High actions and incoming chat channels. Confidence uses a fixed four-letter minimum.
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

An active Olympus guild name is required. Until the official membership API is available, the fallback checks for Olympus as a separate word. This does not verify official affiliation.


## Optional Rule Packs

Additional categories are distributed as author-signed rule packs.

Open `/ocw packs`, paste the complete signed pack text, verify it, then install and enable it.

Eight current packs are available separately: seven at **version 6**, plus **USA Protection v1**. See the [pack list and import instructions](rule-packs/README.md). Updating the addon does not automatically update imported packs.


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

