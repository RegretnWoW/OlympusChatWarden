# Olympus Warden 1.1.0

Olympus ChatWarden has grown into Olympus Warden: one Greek-themed workspace for
your personal history, remembered players, chat, signals and contact protection.

## Highlights since the published 1.0.3 release

- **Warden** brings system status, milestones and search across the suite together.
- **ChronicleWarden** surfaces meaningful recorded events, measured time, progress,
  shared activities and supported dungeon, raid and boss evidence. Original
  records remain accessible; missing attendance or results are not invented.
- **IntelWarden** brings recently met players, evidence-based relationships,
  historical dossiers, private notes and watchlists together. Identity, shared
  history and original sources stay connected without merging players by name.
- **Appearance & Gear** shows dated equipment, unique recorded configurations,
  item links/tooltips and a native model only when the exact player is available.
  Historical gear stays historical; unavailable gear is distinct from confirmed
  empty slots. Offline appearance is not reconstructed.
- **Historical talents** presents supported native choices, names, ranks and
  observation dates, retaining original exports. Export-only and partial readings
  remain explicit; specialization IDs never invent a talent tree.
- **Optional duel history** keeps individual encounters and supported before/after
  gear/talent evidence under separate consent. Identical configurations reuse
  saved content while encounters retain their dates, results and original sources.
  Received combat totals do not invent an attacker or complete damage attribution.
- **Native Statistics and PvP observations** preserve supported displayed values,
  scoreboard fields and objective data. Unavailable fields stay unknown; readable
  scoreboards are not automatically presented as fresh final scores.
- **ChatWarden** groups Messages, Capture, Rules, Packs and Reports.
  **SignalWarden** groups personal mentions, Wanted encounters and permitted
  OlympusMute observations. **ShieldWarden** retains contact protection and review.
- The compact Olympus panel has module filters, recent activity, exact source
  links and a target shortcut. Existing recent alerts mark read when opened.
- Large histories use cooperative loading/indexing, chunked saving, bounded
  caches and snapshot deduplication. Crowded-area work reuses unchanged facts
  while retaining timestamps, collection detail, GUID checks and personal routes.
- Your recording choice remains optional. Main and duel permissions stay separate.
  History has no automatic expiry; complete-file backups remain compatible.

## Final interface and bug fixes

- Sidebar order: Warden, ChronicleWarden, IntelWarden, ChatWarden, SignalWarden,
  ShieldWarden, Data & Backups, Updates & Help, Settings. Existing module IDs,
  commands, saved selections and deep links are retained.
- Sidebar buttons are taller with 50px crests; page headers use 56px crests with
  titles and tabs beside the artwork. The column is slightly wider to fit labels.
  Original Zeus artwork and Olympus styling are retained.
- Feature controls keep the same current logo when on or off. ON/OFF badges,
  paused dimming and explicit text replace the mixed legacy artwork. Hover cannot
  leave a paused control bright; ordinary headers restore full-color artwork.
- Recent activity titles and status lines align and fit. Home's identity banner
  is taller so character details clear the decorative trim.
- Talent rows give names and recorded ranks full line height; the last row can
  be fully reached by scrolling.
- Window-size edits wait for Apply or Enter. Fit to screen restores automatic
  sizing. Welcome and navigation preserve size; screen caps retain the preference.
- Welcome uses the current six-module suite tour. Complete documents wrap and
  scroll, selection differs from unread, and original evidence offers return
  navigation with private note drafts and scroll positions retained.
- Missing duel gear is summarized with Show all slots available. Recording state
  is immediate, and backup versus two-step deletion remains clearly separated.

## Installation and compatibility

The install folder remains **OlympusChatWarden** and the saved variable remains
**OlympusChatWardenDB**. Replace the existing addon folder; do not install a second
copy. Close WoW and back up SavedVariables before upgrading. The unchanged Windows
backup tool is supplied separately. `/warden`, `/ow`, `/ocw` and `/chatwarden` work.

No new sharing default, continuous other-player tracking, expiry, classification
vocabulary, schema or collector change was introduced in the final pass from RC5.
Native API availability varies; historical observations retain their limitations.
