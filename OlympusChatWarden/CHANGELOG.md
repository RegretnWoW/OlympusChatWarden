# 0.9.0-rc41

- Enabled a temporary current-character guild-name gate. Olympus must be a
  separate word, ignoring case. This does not verify official affiliation.
- Prefer the official Olympus membership API when available. Failed or negative
  official checks pause filtering. Guild changes refresh access automatically.
- Gate every feature outside a qualifying guild, including recording, reporting,
  exports, pack actions and player menus. Close open tools and lock settings;
  preserve saved data and resume normal pack verification after access returns.
- Added a floating-name reveal fallback for visible nameplates without a
  mouseover unit, retaining native clicks and rejecting ambiguous spans.
- Marked floating-name click support experimental and updated access guidance.
- Reviewed the release package, defaults, reporting, exports and import paths.

# 0.9.0-rc40

- Rebuilt language options around one master switch, Low/High action dropdowns,
  optional name filtering, chat coverage and the reading list. Confidence always
  runs with a fixed four-letter minimum. Name filtering starts off.
- Mostly non-preferred text uses the High action even when only the writing
  system is recognized. Reports retain honest confidence and explain that rule.
- Removed sender-name hiding. Names no longer alter message decisions; English
  replies stay visible. Name filtering follows Redact/Label/Leave choices.
- Updated in-game help, tooltips and release documentation.

# 0.9.0-rc39

- Simplified language settings: one reading list for names and messages; removed
  setup, separate script choices and advanced overrides. Defaults migrate once
  to four letters, lower-confidence redaction and high-confidence hide conditions.
- Personal/category rules now cover native chat names, including emote sender
  links. Name results appear in Messages and saved reports. Ctrl-left-click
  reveals covered chat names while ordinary clicks and menus keep native identity.
- Name display reports retain matches and privacy exports recognize reported
  names even after reload. Only hidden messages receive unread badges.
- Text panes explicitly copy the regular WoW label font with empty outline flags.
- Updated language guide, examples and tooltips.

# Changelog

## 0.9.0-rc38

- Added combined name + message hiding: matching names with fully non-allowed
  messages are hidden; English, allowed-language and mixed messages do not trigger
  this rule. Short script-based messages are supported.
- Added a one-click name + message setup that covers names, keeps English replies
  and sets other non-allowed text to Cover. Every message remains configurable.
- Reorganized language settings with examples and separate advanced overrides.
- Preserved combined decisions, sender mode and name-script diagnostics in reports.
  Added explicit wording and combined prediction fields to avoid ambiguity.
- Standardized addon text panes, editors and measurements on Blizzard UI fonts.
- Shortened Review details, separated sections and moved diagnostics behind Why
  filtered. Updated the language guide and capture instructions.

## 0.9.0-rc37

- Added optional strict script filtering for short text, including single letters,
  with Cover or Hide any matching incoming message actions.
- Added separate script-based player-name masking and incoming sender hiding.
- Preserved native link payloads, right-click identities and targeting.
- Applied language decisions to accessible player bubbles with known speakers.
- Kept hidden-message originals, notifications and real-time badge dismissal in
  the existing Messages view. Added Allow script for explicit script rules.
- Added captured language settings and predicted decisions to missed reports and
  privacy exports; pasted examples clearly use current settings.
- Updated language settings, tooltips and help. New strict/name options start off.

## 0.9.0-rc36

- Added optional language filtering with its own confidence levels, allowed
  languages, shared writing-system choices, actions and chat-type coverage.
- Preserved readable portions in mixed messages and links/formatting in redactions.
- Added language explanations and an Allow language shortcut to Messages.
- Retained language explanations in saved feedback and privacy exports.
- Added language settings, `/ocw languages` and an in-game language guide.
- Kept word scores, stock/signed packs, Shield and capture behavior independent.

## 0.9.0-rc35

- Added independent repeated-whisper detection to Normal Harassment and Streamer
  Shield profiles, with a separate setting enabled by default.
- Added repetition-counter reset on outgoing replies; allowed players are exempt.
- Included the shield reason in retained messages and exports.
- Rewrote the guide as six concise topics, including dedicated Chat capture help.
- Updated capture instructions and Shield tooltips.
- Cleaned bundled documentation for end users; retained signed-pack functionality
  and download links. No optional vocabulary packs are bundled.

## 0.9.0-rc34

- Added persistent, optional player-chat capture with separate private-chat scopes.
- Added incident bookmarks, search and bounded local storage.
- Added player right-click actions for Shield management and chat capture.
- Added Shield-list exports and selectable privacy previews for personal exports.

