# Olympus ChatWarden 0.9.0-rc49

This public beta adds spam protection, quieter notifications and a more consistent Review & Protection window. It includes the improvements tested after rc41.

## Spam protection

- Hide gold-selling and paid-service ads, including common look-alike characters and website formatting.
- Hide guild recruitment ads, with exceptions for Olympus guild advertisements.
- Detect repeated or slightly altered messages: 3 similar messages in 30 seconds triggers a local timeout.
- Rapid chat uses 5 messages in 10 seconds. The first burst pauses that player's chat for 10 seconds; a second new burst within a minute applies the timeout.
- Automatic timeout starts at 15 minutes and remains adjustable. Choose which incoming chat channels to check.
- Ads are hidden quietly by default. Hidden originals remain in Messages; nothing is automatically reported to Blizzard.

## Notifications and Shield

- Separate controls for filtered messages, contact protection, repeated/rapid chat, gold/service ads and recruitment ads.
- Spam and advertising notifications start off. Filtering and review continue when notifications are disabled.
- Reading a hidden message clears its unread indicators immediately.
- One set of Shield protections replaces the Streamer profile. Existing shields, allowed players and channel preferences are retained.
- Player names with spaces are supported throughout spam checks and player management.

## Review and display

- Help and Settings stay in the same bottom-right positions across Messages, Shield and Chat capture. Export stays at the right of each toolbar.
- Improved panel alignment and removed redundant navigation buttons.
- Saved reports and export previews use the same newest-first order and report numbers.
- Separate multilingual originals from explanation text to reduce WoW font fallback affecting the whole report.
- Improved floating-nameplate Ctrl-click handling. This remains experimental and needs confirmation on the live client.
- Updated in-game guides and tooltips.

## Optional signed packs

All eight current packs are available separately: Gender and pronoun wording v6, Body-label replacements v6, Pregnancy and reproductive wording v6, Inclusive wording v6, DEI and institutional terminology v6, Social and political slogans v6, Broad contextual phrases v6, and USA Protection v1.

Download the rule-pack bundle or an individual `.ocwpack.txt` file. Open `/ocw packs`, paste the complete signed text, verify it, then install and enable the category. Updating the addon does not update imported packs automatically. Only Olympus Protection and King Protection are included in the addon ZIP.

## Install or update

Download **OlympusChatWarden-v0.9.0-rc49.zip** and replace the OlympusChatWarden folder in `Interface/AddOns`, then reload WoW. Keep SavedVariables to retain preferences, reports, captures and imported packs. GitHub's automatic source archives are not the ready-to-install addon ZIP.

An Olympus guild name is required. The current fallback checks for Olympus as a separate word; it does not prove official affiliation. The official membership API takes priority when available.

Validation: 588 automated startup, signed-import, spam, advertising, language, notification and UI checks passed across all 52 Lua modules. All eight signed packs are also checked through the normal verifier and install/restore flow. No live WoW session was available to confirm font rendering or floating-nameplate interaction.
