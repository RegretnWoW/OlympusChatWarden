# Olympus ChatWarden 1.0.0

The first 1.0 release combines contextual personal filtering, local contact/spam protection, mention alerts and persistent review. Open from Olympus or `/ocw`; Overview is the default page.

## Changes since alpha12

- Match the supplied launch defaults, including Gommage and Capture off.
- Separate Hidden and Redacted unread notifications. Hidden starts on; Redacted starts off.
- Make context handling part of the engine. Remove the checkbox and retire `/ocw logic off`; old saved opt-outs cannot bypass questions, quotations or reporting safeguards.
- Treat “America is dumb” as mild criticism: visible in Mild, warning in Balanced, hidden in Broad. Signed USA Protection v5 updates its authored statement scores. Stock Olympus/King protection uses the same severity distinction.
- Fix the reported false positive “If USA is so bad why does half the world want to live there?” by recognizing its conditional-question structure. A question mark alone is not an exemption, and separate direct assertions still receive their own decision.
- Cover redacted text/names with opaque bronze bars. Ctrl + left-click reveal behavior and original text are retained.
- Preserve the prior masked Olympus-icon, multilingual-name, badge/read-state and saved-history fixes. The eight main artwork atlases are unchanged from alpha12.

## Launch defaults

Filtering, Shield, Mentions and Spam protection start on. Balanced is the main filtering preset and contact profile. Gommage and Chat Capture start off.

Player chat, chat bubbles, barber/body-type wording, review history, OlympusMute signal tooltips and Balanced incoming typo matching start on. NPC chat, dialogue, vendor labels, talking-head captions, name/nameplate/unit-frame filtering, tooltips, language filtering and typing assistance start off.

Mention detection watches the full character name and all supported channels, with close typo matching for custom watch phrases on. Names/nicknames remain exact. Sound and toast start off with a 10-second cooldown. Capture includes whispers and guild/officer chat when recording is enabled.

Hidden-message alerts start on; redaction alerts start off. Word filtering and contact protection notifications start on. Language-only, spam and advertising notifications start quiet. These switches change alerts, not filtering or saved originals.

Existing explicit feature choices, captures, watch phrases, dictionaries, imports and history are preserved. The retired context opt-out is the exception: context handling is always active.

## Install and update packs

Fully exit WoW. Extract OlympusChatWarden-v1.0.0.zip into Interface/AddOns so OlympusChatWarden/OlympusChatWarden.toc is directly inside the addon folder. Keep WTF/SavedVariables. Reopen the game.

Optional packs are separate signed imports. If you use USA Protection, open america-v5.ocwpack.txt from the rule-pack archive and use Packs > Import signed pack > Verify pack > Install pack. Updates retain enablement and per-pack presets. The other seven optional pack versions are unchanged from alpha12 and need no reimport if current. Only Olympus Protection and King Protection ship in the addon.

All 215 curated Gommage masks and 46 replacement pairs remain intact. Gommage is a separate literal meme option. Topic preferences, masks and replacements do not automatically shield players.

## Validation

Production Lua checks cover the reported example, all preset contrasts, fresh defaults, existing preference migration, independent alerts, signed import/update verification, topic coverage, masked texture refresh, multilingual names, message feed and persistence. ZIP files are checked against source with CRC and signature validation. Signing keys/kits are excluded. Native login, fonts, texture rendering and live gameplay still need the final in-game check. Packaging does not install the addon or publish it online.
