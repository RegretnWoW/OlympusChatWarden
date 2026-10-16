# Olympus ChatWarden

Version **1.0.1**. Open from Olympus or `/ocw`; Overview is the default page. Includes context-aware signed packs, curated WoW/Olympus spellings and automatic first/full-name Mentions. Current v11 terminology packs, USA v6 and Labels v7 remain compatible. Updating the addon does not replace older imported packs; use the clearly named files in the separate pack download to update their signed titles.

Personal local filtering, contact protection, mentions, saved review and optional chat capture for World of Warcraft. The current character's guild must contain Olympus as a separate word until the official membership API is available. Access pauses outside a qualifying guild; saved data is retained.

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

Messages is the filtering feed for warnings, replacements, redactions and hides across channels, including whispers. Ordinary chat stays out. Warnings/replacements are quiet; hidden-message alerts start on and redaction alerts start off, with separate controls in Notifications. Mentions contains mention activity; Shield contains contact/spam activity; Overview combines the feeds.

History/read states persist per character with bounded storage and silent restoration. Settings > Activity history > Clear all clears character activity while keeping packs, settings, reports, captures and bookmarks. Covered names require Ctrl + left-click; originals are retained. Previous masked-icon, badge and multilingual-name fixes remain.

Why filtered? and reports retain topic/target, stance, expression strength, evidence certainty and actual action. Original text and offsets remain intact. User reports require Save Report; exports send nothing automatically. Player Intelligence collection, Relay and the Olympus Warden rebrand remain future work.

Incoming spelling/evasion matching is independent of optional typing assistance. Capture is opt-in. Shield combines configured request/repetition/spam limits with eligible strong directed wording; topic preferences and literal masks cannot trigger it. See SPELLING-LICENSE.txt and RELEASE-NOTES.md.

The unchanged English base is supplemented by 1,078 curated WoW/Olympus tokens and your existing personal dictionary. Valid game terms avoid spelling marks, automatic correction and mistaken Balanced typo guesses. Exact rules and evasion matching still apply. See SPELLING-VOCABULARY.md for scope and inventory guidance.

## Install

Fully exit WoW, replace the OlympusChatWarden folder from the ZIP, then reopen. Keep WTF/SavedVariables. Import wanted updated packs using Packs > Import signed pack > Verify pack > Install pack. Follow INTERNAL-TESTING.md. Native in-game login/rendering/events still require testing.

## Local phrase tester

Use `/ocw test <phrase>`, for example `/ocw test Olympus is trash`. The command prints the wording action, preview and reasons using your enabled packs, per-pack sensitivity, personal rules, Gommage and incoming typo setting. It sends nothing and creates no feed entry, report, capture or Shield event. It tests wording policy; it does not simulate language detection, spam, contact limits or actual chat rendering.

## Launch defaults

Filtering, Shield, Mentions and Spam protection start on. Balanced is the main filtering preset and contact profile. Gommage and Chat Capture start off.

Player chat, chat bubbles, barber/body-type wording, review history, OlympusMute signal tooltips and Balanced incoming typo matching start on. NPC chat, dialogue, vendor labels, talking-head captions, name/nameplate/unit-frame filtering, tooltips, language filtering and typing assistance start off.

Mention detection watches your first name or full character name in all supported channels; no @ is required. Names/nicknames remain exact whole-name matches, with close typo matching for custom watch phrases on. Sound and toast start off with a 10-second cooldown. Capture includes whispers and guild/officer chat when recording is enabled.

Hidden-message alerts start on; redaction alerts start off. Word filtering and contact protection notifications start on. Language-only, spam and advertising notifications start quiet. These switches change alerts, not filtering or saved originals.

Existing explicit feature choices, captures, watch phrases, dictionaries, imports and history are preserved. The retired context opt-out is the exception: context handling is always active.
