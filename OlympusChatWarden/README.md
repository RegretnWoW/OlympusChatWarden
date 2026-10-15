# Olympus ChatWarden

Version **1.0.0**. Open from Olympus or `/ocw`; Overview is the default page.

Personal local filtering, contact protection, mentions, saved review and optional chat capture for World of Warcraft. The current character's guild must contain Olympus as a separate word until the official membership API is available. Access pauses outside a qualifying guild; saved data is retained.

## Contextual filtering

Choose Mild, Balanced or Broad in Settings > Filtering. Balanced follows the author's display preferences: mild unwanted support/criticism warns, stronger promotion/attacks redact. Broad hides eligible expressions and recognizes wider topics. Context handling keeps neutral references, questions and merely quoted/reported statements visible. Recognized explicit threats use separate protection.

Protected subjects such as USA permit praise and filter recognized attacks. Selected terminology packs permit criticism and filter support/promotion. Topic recognition alone has no action. Classification is bounded and deterministic; evidence tiers are not probabilities of intent.

Gommage starts off and is a separate meme toggle. Its original curated masks deliberately cover selected terms regardless of stance, including questions and criticism. It does not increase confidence or automatically Shield players. Body-label replacements retain their independent wording switch.

Olympus Protection and King Protection are included. Other categories require author-signed imports. **Install this addon, then verify/import the new schema-4 pack versions you use. The addon ZIP alone does not replace imports.** Body-label replacements v7 is unchanged. Existing older signed packs keep their original model until updated.

## Workspace and data

Messages is the filtering feed for warnings, replacements, redactions and hides across channels, including whispers. Ordinary chat stays out. Warnings/replacements are quiet; hidden-message alerts start on and redaction alerts start off, with separate controls in Notifications. Mentions contains mention activity; Shield contains contact/spam activity; Overview combines the feeds.

History/read states persist per character with bounded storage and silent restoration. Settings > Activity history > Clear all clears character activity while keeping packs, settings, reports, captures and bookmarks. Covered names require Ctrl + left-click; originals are retained. Previous masked-icon, badge and multilingual-name fixes remain.

Why filtered? and reports retain topic/target, stance, expression strength, evidence certainty and actual action. Original text and offsets remain intact. User reports require Save Report; exports send nothing automatically. Player Intelligence collection, Relay and the Olympus Warden rebrand remain future work.

Incoming spelling/evasion matching is independent of optional typing assistance. Capture is opt-in. Shield combines configured request/repetition/spam limits with eligible strong directed wording; topic preferences and literal masks cannot trigger it. See SPELLING-LICENSE.txt and RELEASE-NOTES.md.

## Install

Fully exit WoW, replace the OlympusChatWarden folder from the ZIP, then reopen. Keep WTF/SavedVariables. Update optional packs using Packs > Import signed pack > Verify pack > Install pack. Native in-game login/rendering/events still require testing. See RELEASE-NOTES.md and the separate signed rule-pack archive for update details.

## Launch defaults

Filtering, Shield, Mentions and Spam protection start on. Balanced is the main filtering preset and contact profile. Gommage and Chat Capture start off.

Player chat, chat bubbles, barber/body-type wording, review history, OlympusMute signal tooltips and Balanced incoming typo matching start on. NPC chat, dialogue, vendor labels, talking-head captions, name/nameplate/unit-frame filtering, tooltips, language filtering and typing assistance start off.

Mention detection watches the full character name and all supported channels, with close typo matching for custom watch phrases on. Names/nicknames remain exact. Sound and toast start off with a 10-second cooldown. Capture includes whispers and guild/officer chat when recording is enabled.

Hidden-message alerts start on; redaction alerts start off. Word filtering and contact protection notifications start on. Language-only, spam and advertising notifications start quiet. These switches change alerts, not filtering or saved originals.

Existing explicit feature choices, captures, watch phrases, dictionaries, imports and history are preserved. The retired context opt-out is the exception: context handling is always active.
