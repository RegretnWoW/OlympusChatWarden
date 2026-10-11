# Olympus ChatWarden 0.9.0-rc41

Release candidate with a temporary Olympus guild check and final launch cleanup.

## Guild access

- Requires Olympus as a separate word in the current character's guild name,
  ignoring case. Olympus and Olympus XI Reborn qualify.
- Uses the official Olympus membership API automatically when available.
  A negative or failed official check disables access.
- Outside a qualifying guild, the entire addon is disabled: filtering, Shield,
  capture, report caching, exports, pack actions, player menus and feature windows.
- Open tools close, settings lock and slash commands explain the restriction.
  Saved data and preferences are preserved.
- Guild changes refresh access. Previously enabled capture resumes after the
  character qualifies. Saved imports go through normal signature verification.
  Pending verification stops if guild access ends.

The temporary name check does not establish official guild affiliation.

## Floating-name reveal

Added a fallback for visible nameplate labels without an engine mouseover unit.
It uses the covered span's position, rejects overlapping candidates, unrelated
UI windows, different mouseover units and restricted unit information, and
preserves native targeting. Protected combat changes still wait.

Floating-name Ctrl-left-click remains experimental and needs in-game confirmation
on the affected client. Originals remain available in Messages for guild members.

## Release pass

- Updated in-game access guidance, locked settings and active/disabled status.
- Retained the simplified language settings, hidden-message notifications,
  missed reports, Shield profiles, chat capture and privacy export previews.
- Fresh-install defaults checked: Broad filtering and Normal Shield on; language
  filtering, capture and experimental name surfaces off.
- Only Olympus Protection and King Protection vocabulary categories are bundled.
  Built-in body-label replacements remain available.
- Signed imports, download links and installed-pack update functionality remain
  available to qualifying characters. No optional vocabulary or private signing
  material is included.

## Validation

570 automated assertions passed. All 47 Lua modules parsed under Lua 5.1 and
loaded together in TOC order. Checks include fresh member/nonmember startup,
whole-addon guild gating, guild changes, preserved data, actual signed-pack
import and verification suspension/restoration, filtering, reports, exports,
notifications, Shield, capture, UI input and the floating-name fallback.

The archive was checked against an explicit file list, its contents compared
with the source, and older release archives preserved. Live WoW validation and
CurseForge approval have not been performed.
