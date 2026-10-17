# Olympus ChatWarden

**Version 1.0.3** adds optional recording for Chronicle and Player Intelligence.
Recording starts off until you choose to enable it. Reopen the explanation with
`/ocw chronicle prompt`, or use Settings > Chronicle & Intel. History stays on this
computer; ChatWarden does not upload it.

Recording preserves your own routes, progress, equipment, supported native activity,
important player encounters and permitted Olympus records. Other players are not
continuously tracked. Unknown information stays unknown.

- **Recording > Recorded Events:** Milestones and meaningful changes first. Use
  All recorded data and multiple filters for background observations and routes.
- **Recording > Activities:** Dungeon, raid, group and PvP visit segments with
  supported boss evidence and original source navigation.
- **Recording > Intelligence:** Measured time and UTC periods, player encounter/
  roster histories, native credit evidence, PvP visits, scoreboard observations,
  progression, deaths and observed zone entries. These are read-only projections.
- **Recording > Collection Status:** Click an item for what it saves and its limits.
- **Recording > Backup & Restore:** Keep a complete-file backup for a new PC.

Roster association does not prove individual boss attendance, native credit is not
necessarily a solo victory, and scoreboard identity may not establish a unique
match. Matched performance and the polished Chronicle/dossier UI remain future work.
See [INTELLIGENCE.md](INTELLIGENCE.md) and [ACTIVITIES.md](ACTIVITIES.md).

For a complete backup, fully exit WoW and copy
WTF/Account/<account>/SavedVariables/OlympusChatWarden.lua to a safe location
outside WoW. The separate optional **ChatWarden Backup Tool for Windows**
creates one verified ZIP and keeps a before-restore safety copy. File restore
replaces all saved addon choices and history. History-only text merging remains
available for combining records without replacing settings.

History has no automatic expiry. Schema6 preserves earlier schemas1-5; scope5
consent remains valid from the later previews. Earlier scopes require a fresh
choice. Read [CHRONICLE-INTEL.md](CHRONICLE-INTEL.md) and
[BACKUP-GUIDE.md](BACKUP-GUIDE.md) for details.

Personal local filtering, contact protection, mentions, saved review and optional chat capture for World of Warcraft. Olympus 1.2.4's membership decision takes priority and requires its per-addon data permission. Older Olympus versions retain the local guild-name check. Missing permission or membership pauses protection and keeps saved data. The native page stays available for connection help.

The native page supports old and HD Olympus layouts. Its header, icon row and bottom Open ChatWarden button stay fixed while Recent Activity scrolls. Click a feature icon to enable or pause it; hover for its name and state. Capture remains off until you start it. The full workspace remains available through `/ocw`.

Mentions is now **Alerts**, with All alerts, Mentions and Wanted views. Wanted encounters require an attackable target or mouseover matching a listed GUID. Encounters appear in Alerts, Overview and the compact recent list. Alerts > Wanted settings controls encounter sound, toast, badges and a five-minute default cooldown. Sound and toast start off. Visible chat gets only an icon beside exact full listed names, with current bounty details on hover; it never sends Wanted notifications. Your own visible chat and outgoing whispers support solo icon testing. Olympus continues to manage the board and bounties.

Filtering logic, spelling vocabulary and signed pack contents are unchanged from 1.0.1. Existing v11 terminology packs, USA v6 and Labels v7 need no reimport. See RELEASE-CHECKS.md for the native checks to perform in WoW.

## Contextual filtering

Choose Mild, Balanced or Strict in Settings > Filtering. Stock protection uses the same covered subjects in every preset. Balanced tolerates familiar creator roasts, warns on mild guild hostility, redacts direct guild-group insults and hides severe directed abuse. Specific criticism of leadership, strategy or an argument remains visible. Uncertain target or context stays visible. Covered explicit real-world harm and targeted self-harm encouragement have a separate severity class.

The new stock parser separates target attribution from expression strength and action. Quotes require a clearly attached endorsement; reports, negation, questions and gameplay do not automatically establish an attack. Affectionate banter has a narrow exception and cannot cancel an independent severe attack. Redactions cover the offending expression, with separate subject offsets retained in evidence.

Compatible signed terminology packs leave neutral references, questions, criticism and uncertainty visible. Mild support, including explicit first-person preference, is Unchanged / Warning / Redacted across Mild / Balanced / Strict. Clear calls for adoption or requirements are Warning / Redacted / Hidden. Gender and Inclusive Language also cover deliberate own terminology practice, including “our standard” and “the way we speak here.” This usage capability comes from the signed pack and does not extend to other packs. Gender covers explicit pronoun declarations regardless of the pronouns used. Communism & Democratic Party covers explicit own affiliation/voting only for communism and the Democratic Party. These matches express a selected local viewing preference, not a judgment about beliefs or misconduct.

USA Protection uses the same covered subjects in every preset: mild country/group insults are Unchanged / Warning / Redacted. Specific policy criticism and praise stay visible. Stock protection recognizes direct terrorist allegations as Warning / Redacted / Hidden and covered explicit IRL threats as Hidden in all presets. Bare combat wording stays visible when real-world intent is unclear. Classification remains bounded and deterministic; evidence tiers are not probabilities of intent.

Topics joined by “and” can share an explicit statement within a bounded authored object list, while each pack keeps its own sensitivity. Independent clauses, negation, reports, quote boundaries and native hyperlinks do not acquire inherited context. An immediately attached rejection of the same terminology cancels an own-usage match; independently qualifying promotion, declarations, other packs and Gommage keep their separate behavior.

Gommage starts off and is a separate meme toggle. Its original curated masks deliberately cover selected terms regardless of stance, including questions and criticism. It does not increase confidence or automatically Shield players. Body-label replacements retain their independent wording switch.

Barber & body-type wording controls both the built-in Body Type 1/2 replacements and imported label variants. Disabling the optional Labels pack stops its extra variants; built-in patterns remain until the master wording switch is off.

Olympus Protection and King Protection are included, at stock revisions 10 and 9. Other categories require author-signed imports. Older optional policy packs show Update Required and contribute no filtering or Gommage until updated. Their signed imports, enabled choices and sensitivities remain saved. Body-label replacements v7 stays compatible. No optional pack installs automatically.

## Workspace and data

Messages is the filtering feed for warnings, replacements, redactions and hides across channels, including whispers. Ordinary chat stays out. Warnings/replacements are quiet; hidden-message alerts start on and redaction alerts start off, with separate controls in Notifications. Alerts contains personal mentions and Wanted encounters; Shield contains contact/spam activity; Overview combines the feeds.

History/read states persist per character with bounded storage and silent restoration. Settings > Activity history > Clear all clears character activity while keeping packs, settings, reports, captures and bookmarks. Covered names require Ctrl + left-click; originals are retained. Previous masked-icon, badge and multilingual-name fixes remain.

Why filtered? and reports retain topic/target, stance, expression strength, evidence certainty and actual action. Original text and offsets remain intact. User reports require Save Report; exports send nothing automatically. Player Intelligence browsing, event correlation, Relay and the Olympus Warden rebrand remain future work; optional history collection is available now.

Incoming spelling/evasion matching is independent of optional typing assistance. Capture is opt-in. Shield combines configured request/repetition/spam limits with eligible strong directed wording; topic preferences and literal masks cannot trigger it. See SPELLING-LICENSE.txt and RELEASE-NOTES.md.

The unchanged English base is supplemented by 1,078 curated WoW/Olympus tokens and your existing personal dictionary. Valid game terms avoid spelling marks, automatic correction and mistaken Balanced typo guesses. Exact rules and evasion matching still apply. See SPELLING-VOCABULARY.md for scope and inventory guidance.

Visible local Wanted encounters appear in Events. Custom types separate native
actions from background summaries. Large event histories load in small steps and
reuse an in-memory index. Full statistics are in Collection Status. These views
preserve the original ledger and add no collection or sharing.

## Install

Fully exit WoW, replace the OlympusChatWarden folder from the ZIP, then reopen. Keep WTF/SavedVariables. Import wanted updated packs using Packs > Import signed pack > Verify pack > Install pack. Follow INTERNAL-TESTING.md. Native in-game login/rendering/events still require testing.

## Local phrase tester

Use `/ocw test <phrase>`, for example `/ocw test Olympus is trash`. The command prints the wording action, preview and reasons using your enabled packs, per-pack sensitivity, personal rules, Gommage and incoming typo setting. It sends nothing and creates no feed entry, report, capture or Shield event. It tests wording policy; it does not simulate language detection, spam, contact limits or actual chat rendering.

## Launch defaults

Filtering, Shield, Alerts and Spam protection start on. Balanced is the main filtering preset and contact profile. Gommage and Chat Capture start off.

Player chat, chat bubbles, barber/body-type wording, review history, OlympusMute signal tooltips and Balanced incoming typo matching start on. NPC chat, dialogue, vendor labels, talking-head captions, name/nameplate/unit-frame filtering, tooltips, language filtering and typing assistance start off.

Mention detection watches your first name or full character name in all supported channels; no @ is required. Names/nicknames remain exact whole-name matches, with close typo matching for custom watch phrases on. Sound and toast start off with a 10-second cooldown. Capture includes whispers and guild/officer chat when recording is enabled.

Hidden-message alerts start on; redaction alerts start off. Word filtering and contact protection notifications start on. Language-only, spam and advertising notifications start quiet. These switches change alerts, not filtering or saved originals.

Existing explicit feature choices, captures, watch phrases, dictionaries, imports and history are preserved. The retired context opt-out is the exception: context handling is always active.
