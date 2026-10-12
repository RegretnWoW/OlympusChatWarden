# Olympus ChatWarden

Version 0.9.0-rc49 — public beta. See [RELEASE-NOTES.md](RELEASE-NOTES.md).

Personal text filtering, contact protection and local chat review for World of
Warcraft. Open **Review & Protection** from Olympus or type `/ocw inbox`.

## Guild access

Until Olympus provides its membership API, filtering uses the current character's
guild name. **Olympus must appear as a separate word**, ignoring case: `Olympus`
and `Olympus XI Reborn` qualify; `NotOlympus` and `OlympusAlt` do not. This local
check does not verify official affiliation.

The official API takes priority whenever available. A negative or failed official
check pauses filtering. Guild changes are checked automatically; no successful
check is saved between characters or sessions.

The entire addon is unavailable outside a qualifying guild: filtering, Shield,
capture, reports, exports, pack actions, player-menu additions and feature windows.
Settings show a locked page; slash commands explain the restriction. Existing
saved data and preferences are preserved. Leaving a guild stops recording and
queued pack verification; qualifying again restores access and verifies saved
packs normally.

## Features

- **Messages:** review filtered originals, see matched rules, save feedback and
  manage personal phrase rules. Unread badges count enabled hidden-message categories;
  selecting a message clears its badge everywhere.
- **Notifications:** choose badges, Shield chat notices and which hidden messages
  notify you. Repeated-message spam, rapid chat, gold/service ads and guild recruitment ads start quiet; originals stay
  in Messages. Opening a message clears its indicators immediately.
- **ChatWarden Shield:** one set of contact protections for repeated
  whispers, strong-wording whispers, trades, duels and group invites. Manage
  shielded and allowed players from Review or supported player right-click menus.
- **Language filtering:** optional, separate confidence system for incoming player
  chat. English stays allowed; additional languages and shared writing systems can
  be allowed individually. Low confidence covers detected portions. High
  confidence and mostly non-preferred text use the High action, retaining hidden
  originals in Messages. Review provides the estimate and an Allow language shortcut.
- **Chat capture:** optional recording of supported player chat across reloads,
  search, incident bookmarks and exports. Recording is independent of filtering.
- **Export previews:** select records, hide known names, omit notes and edit the
  final text before copying reports, shields, captured chat or bookmarks.
- **Display controls:** word redaction, wording replacements and coverage
  switches. Ctrl + left-click supported covered phrases to reveal them.
- **Built-in wording:** one option controls Body Type 1 → Male and Body Type 2 →
  Female, including supported barber labels.
- **OlympusMute signal notes:** compatible observed sharing adds a ChatWarden
  note to player tooltips. Observations persist without an age limit, up to
  10,000 players. A missing note does not indicate whether someone uses the addon.
- **Signed rule packs:** verification, imports, per-category controls, exports,
  download links and installed-pack update notices remain available. Olympus
  Protection and King Protection are included; no optional vocabulary packs are
  bundled. Update checks use the catalog shipped with the addon, with no automatic
  downloads or installations.

## Repeated-whisper protection

Identical or slightly changed incoming whispers count toward a temporary local
shield even without a word-filter match. Case, punctuation and spacing changes
are normalized. Short text uses conservative comparisons; long text requires an
exact normalized match.

| Threshold | Shield duration |
| --- | --- |
| 6 similar whispers in 30 seconds | 10 minutes |

Replying to the sender resets their repetition counter. Allowed players are
exempt. Further messages do not extend an existing shield. The feature has its
own switch under Shield settings and does not require chat capture.

## Language preferences

Open `/ocw languages`. The page contains the master switch, Low and High action
dropdowns, **Filter player names too**, incoming chat switches, and languages you
read. The master starts **off**. English stays allowed.

When enabled, defaults are **Low: redact**, **High: hide message**, and **player
names: off**. Confidence always runs with a fixed four-letter minimum per portion.
Both action dropdowns offer Redact detected text, Hide message, Label only and
Leave visible. Hide removes the whole qualifying line, including mixed text.

When at least **85% of readable letters** are detected as non-preferred, the
**High action** applies even if the exact language is uncertain. Thus a wholly
Cyrillic message is hidden by default without claiming a confident Russian or
Ukrainian identification. Review and reports distinguish this coverage rule from
language confidence. Visible native link labels count toward the readable-letter
total while native link payloads remain untouched.

| Message result | Name filtering off | Name filtering on |
| --- | --- | --- |
| Redact | Cover detected text | Also cover a matching name |
| Hide | Hide whole line and name | Hide whole line and name |
| Label only / Leave visible | Keep name readable | Keep name readable |
| English / preferred text | Keep normally | Cover matching name; keep text |

Names never hide an otherwise readable reply or increase confidence. One reading
list controls text and names. Cyrillic names cannot distinguish Russian from
Ukrainian; allowing either keeps Cyrillic names. Han uses its shared entry.
Latin names cannot reliably identify a language; use a personal rule for a
specific name. Personal/category rules continue to apply independently.

Estimates support Spanish, French, German, Portuguese, Italian, Russian,
Ukrainian, Japanese with kana and Korean with Hangul. Shared writing systems are
labeled separately. Four letters is eligibility, not proof. Unsupported scripts
and uncertain Latin text remain visible. Public, whisper, group and guild/officer
chat have separate switches; your own messages, NPC text, emotes and Battle.net
are excluded from language message rules.

Covered names appear in Messages as **Player name** entries. **Ctrl + left-click**
reveals or covers names in supported chat frames; ordinary clicks and menus keep
native player identities. Name-only covering does not generate hidden-message
badges. Hidden originals remain in Messages; enabled notification categories
receive unread badges. Selecting one clears its indicators immediately. Received
reports keep message-time settings,
detection evidence and the chosen action rule through privacy exports. Chat-name
reports also keep the recorded chat-filter outcome and spam diagnostics.
Event-only captures have no confirmed actual action.

The simpler defaults migrate once while keeping the master state, reading list
and chat coverage. Name filtering resets off; removed sender/strict overrides no
longer affect messages. Later dropdown and name choices persist.

Supported player bubbles follow attributed language decisions. Protected,
inaccessible and third-party labels may remain visible. Review and chat capture
retain originals. Wording rules, Shield, signed imports and exports remain
independent. Review and saved reports put names and originals in separate text regions so native multilingual font fallback does not restyle English explanations. Original text is retained in saved records and exports.

## Installation and defaults

Extract the ZIP so `Interface/AddOns/OlympusChatWarden/OlympusChatWarden.toc`
exists. Replace the previous addon folder; retain your SavedVariables to keep
saved preferences and records.

Fresh installs use Broad sensitivity. Player chat, accessible bubbles, built-in
barber wording, context, review history, hidden-message badges and OlympusMute
signal detection start on. NPC chat, quest/dialogue text, vendor labels, talking
heads, names, nameplates and general tooltip filtering start off.

Shield and all individual protections start on. The Streamer profile has been removed; existing users move to the normal contact thresholds. Existing shields and allowed players are retained.

Spam protection starts on for public chat, whispers, party/raid and guild/officer chat. Rapid chat uses a fixed 5 messages in 10 seconds: a 10-second first pause, then a full timeout after another new burst within a minute. Repetition uses a fixed 3 matches in 30 seconds and applies the timeout immediately. Automatic timeout starts at 15 minutes and remains adjustable. Upgrades apply the fixed limits while preserving existing channel switches and timeout duration.

Hidden word/language badges, contact-protection notifications and chat notices start on. Repeated-message spam, rapid chat, gold/service ads and guild recruitment ads start quiet. Settings > ChatWarden > Notifications has separate category controls; enabling spam notifications also applies to existing unread spam entries. Reading an entry dismisses it everywhere.

Chat capture starts off. Its whisper and guild/officer switches start checked and only record after capture is started. Existing recording choices are retained.

Captured chat is limited to 5,000 lines or 4 MB; the oldest lines roll off when
full. Bookmarks are stored separately, up to 50 or 1 MB. Each saves up to 10
already captured lines before and after the selected line. Battle.net, NPC and
addon traffic are excluded.

## Commands

| Command | Opens |
| --- | --- |
| `/ocw` | Settings |
| `/ocw inbox` | Message review |
| `/ocw shield` | Shield alerts and players |
| `/ocw shieldoptions` | Shield settings |
| `/ocw capture` | Chat capture and bookmarks |
| `/ocw export` | Report export preview |
| `/ocw packs` | Signed rule packs |
| `/ocw languages` | Language preferences and coverage |
| `/ocw help` | In-game guide |

Records and exports stay local until you copy and share them. Name removal does
not guarantee anonymity; review the final text before sharing. Review messages
and Shield alerts clear on reload. Saved rules, reports, non-session shields,
capture and bookmarks persist.

## Release status

The temporary local guild check is enabled. Floating-name Ctrl-click is
experimental: a physical mouse-button fallback supports native plates that consume global mouse events, but
the previously reported click failure still needs in-game confirmation. Originals
remain in Messages. Native UI, protected-frame behavior and real game events
still require in-game testing.

See [Quickstart](QUICKSTART.md) and [Release notes](RELEASE-NOTES.md).
Report issues at <https://github.com/RegretnWoW/OlympusChatWarden/issues>.
