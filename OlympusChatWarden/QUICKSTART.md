# Olympus ChatWarden quickstart

Olympus 1.2.4 has a compact ChatWarden panel with four feature icons and a scrolling Recent Activity list. Right-click its ChatWarden tab or use Open ChatWarden for the full UI. Guild and guild rank sit above Zeus in the sidebar; a selected title appears only when available. Connection status is in the top bar.

**Alerts** replaces the old Mentions page. Personal mentions and Wanted encounters have separate tabs and settings. Encounters also appear in Overview and the compact recent list. **Alerts > Wanted settings** controls encounter sounds, popups, badges and cooldowns. Exact full listed names in visible chat get only an icon with hover details, including in your own chat and outgoing whispers. Chat icons never send Wanted notifications. Olympus remains the source of the Wanted board.

Replace the addon folder and retain SavedVariables. Open `/ocw` or use the Olympus launcher; both start on Overview. Explicit feature shortcuts still open their requested pages. ChatWarden has one main window: use the sidebar for pages and the horizontal tabs for views. Drag the header to move it; it scales to fit the viewport by default. Use **Settings > Window size** for a saved 50–150% size. Drag the slider, or type a percentage and press Enter/Apply. **Fit to screen** restores automatic sizing.

Lists use the mouse wheel or bronze scrollbar. Scrolling back preserves your place as new entries arrive; search/filter changes return to the top.

Click the Overview feature icons to enable or pause Filtering, Shield, Capture and Alerts. Header Filtering and Shield icons toggle too; Olympus opens or focuses its launcher. Dim icons with a minus badge indicate an inactive feature. WoW’s AddOns settings has one master switch and a button to open workspace settings.

Open **Updates** for patch highlights. Previous update and Next update browse older release pages; Launch Tour and User Guide have separate tabs. Blue buttons perform primary actions or select a view; gray buttons navigate or offer utilities; red buttons remove data or protection. Details and Actions are separate framed boxes, and inactive list/document scrollbars stay visible.

Detailed **Settings** use six tabs: Filtering, Languages, Shield, Spam, Notifications and Spelling. Filtering has direct dropdowns for installed pack sensitivity. Mention preferences live at **Alerts > Mention settings**. Spelling has a scrolling personal dictionary. **Updates > User guide** has a topic list and a wide reader.

## Messages, rules and reports

**Messages** is the filtering feed across all channels, including whispers: warnings, replacements, redactions and hidden messages. Ordinary chat stays out. Warnings/replacements appear quietly; the badge counts unread redactions and hides under your notification preferences. Selecting an entry reads it and updates its badge everywhere. The saved original appears automatically in **Messages**; **Why filtered?** explains the match. **Overview** combines activity and keeps safe previews until **Show original** is chosen. **Shield** holds contact/spam/advertising activity; **Alerts** holds personal mentions and Wanted encounters.

**Rules** contains personal phrase actions, exceptions and replacements. Changes apply to new matching chat; earlier chat lines are not rewritten. **Reports** contains saved filter feedback and its privacy preview. Reports do not change rules. **Report player** opens the native reporting flow for supported player-chat entries; you choose the reason and submit it yourself.

The report form puts the original and note beside the issue/action/source controls. Export headings identify the data you are sharing, including **Shield exports**, **Chat Capture exports** and **Bookmark exports**. Entry and privacy choices rebuild the final text; make manual edits last.

## Mention alerts

Open **Alerts > Mention settings**. Your first or full character name is watched automatically; no @ is needed. Add nicknames and literal watch phrases, enable or disable them, and choose their channels. Global channel switches apply to all phrases.

Mention badges start on. Sound and toast start off; both are optional and share an adjustable cooldown. Hidden chat, shielded contacts, your own messages and duplicate deliveries do not create mention alerts. Redacted message previews stay redacted. Multiple matching phrases in one message create one entry.

Reading a mention clears its unread state. **Mark all read** clears the selected alert type, or both types in All alerts. Overview and the Olympus launcher share the same counts. Messages, Alerts, contact activity and read states survive reloads and logins per character, restoring silently. The shared activity stream holds at most 300 entries or 1 MB in memory. **Settings > Activity history** lets you turn remembering off or use confirmed **Clear all history for this character**; rules, reports, captures, bookmarks and protection lists are kept.

## Capture and conversations

Recording remains opt-in. Open **Capture > Capture settings**, choose whisper and guild/officer coverage, then enable recording. Recent, Bookmarks and Conversations use existing locally captured records. Conversations group incoming and outgoing whispers; they cannot recover chat from before recording began.

Select a line or conversation to bookmark, copy or export it. Bookmarks preserve up to 10 already captured lines on each side; future lines are not added. Delete from capture asks for a second click and preserves saved bookmarks. Limits remain 5,000 captured lines or 4 MB and 50 bookmarks or 1 MB. Battle.net, NPC and addon traffic are excluded.

## Protection, spelling and packs

**Settings** contains filtering, language, Shield, spam, notification and spelling controls. **Settings > Shield** offers Balanced protection, Previous defaults or Custom limits for each contact check; Apply saves count/window/timeout together, and Reset defaults restores Balanced without restarting active timers. **Shield** manages contact alerts, timed shields and allowed players. Allowed players bypass Shield; normal word filters still apply. Spam, ads and hidden-language notifications have separate switches and stay quiet by default.

Spelling highlights and typing auto-correction remain optional. Right-click a highlighted word to choose a suggestion, add a personal word or ignore it for the session. No correction sends your text.

**Typo-aware incoming filtering** is enabled in Balanced mode once for this private build. Use **Settings > Spelling** to select Balanced/Aggressive or turn it off; later choices survive reload. Balanced protects known words/names and skips ambiguous different guesses. Originals and the selected mode remain in Why filtered? and reports. Typing assistance stays separate.

**Alerts > Mention settings > Match close typos in watch phrases** is an optional extra and starts off. It requires the global typo engine and uses a unique one-edit match. Character names and nicknames stay literal.

**Packs** shows stock and installed signed categories, their phrase/mask/replacement counts, enabled state and sensitivity. Optional packs still require **Paste import > Verify pack > Install pack**. Existing rc60 signed packs remain valid. The packs link is available from Packs; nothing downloads or installs automatically.

Shield actions follow the selected player: **Remove shield** ends a stored shield, **End chat pause** ends a brief pause, and **Stop allowing** removes an allowed player. A removed contact can still have historical alerts in Recent alerts; its status reflects the current protection. Adding an already shielded player leaves the existing shield unchanged and explains why.

## Copying and sharing

Export previews let you choose entries, hide known names, omit notes and add other names to hide. Review and edit the final text, select it, then Ctrl+C. Changing selection or privacy choices rebuilds the text, so make manual edits last. Plain message copies also open a privacy preview. Signed pack copies preserve the author-signed bytes.

## Guild access and testing

With Olympus 1.2.4 or later, choose Yes for Olympus ChatWarden in /oly privacy. Its membership answer takes priority; pending or declined permission keeps protection disabled. Fully restart WoW after updating Olympus. Older Olympus versions use the local guild-name check. Missing access pauses protection and closes full-workspace tools while keeping saved data; the native page stays available for connection help.

This build has automated checks and static previews. Test native font wrapping, scrollbars, input focus, viewport scaling and player right-click actions in WoW before publishing the release. The old experimental body-cover/camera system remains removed; ordinary name redaction is retained.

**Page controls:** Capture has Start/Pause Capture; Shield and Alerts have Enable/Pause buttons. Their page icons perform the same action. Shield settings show each Balanced default count/window/timeout while Custom limits are edited. Covered names in lists and selected headers can be clicked to reveal or cover them without revealing message content. Pack installation has Back to Packs; the prior search/selection/scroll position and unfinished import draft are kept.
