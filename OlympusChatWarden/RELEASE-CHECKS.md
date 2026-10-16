# 1.0.2 — release checks

Fully exit WoW, replace the OlympusChatWarden folder and keep WTF/SavedVariables. Use Olympus 1.2.4 and grant Yes for Olympus ChatWarden in `/oly privacy`. Current packs need no reimport. This package is prepared locally for release.

## Olympus panels

- Check the fixed stock panel at its normal size: a short padded header, one row of Filtering/Shield/Alerts/Capture icons, three complete recent entries and a pinned Open ChatWarden button. Only the recent list scrolls. The toggle row has tighter gaps above and below. Activity icons should stay centered for filtering, Shield and Wanted rows.
- New entries should preserve your place while reading older activity. Hover shows full action/channel/time; click opens the selected record in the full UI and marks that entry read across its categories. Other entries remain unread. Check the HD layout too.
- Right-click ChatWarden's Olympus tab for the full UI. The full UI's Olympus button opens and focuses Olympus.
- The full sidebar shows guild and actual guild rank without an added role. An empty title has no row. A selected title supplied by Olympus appears normally. Zeus's straight gold edges align with the panel's left and bottom trim. Guild/rank and any selected title stay clear. Check automatic screen fitting and dragging near screen edges. Connection status stays in the top bar.

## Updates

- Patch Notes shows six short highlights since 1.0.1, with no cut-off text or overlapping buttons. Previous update and Next update browse the original 1.0.1 and 1.0.0 pages, with disabled buttons at each end. Launch Tour and User Guide keep their own tabs.

## Alerts

- All alerts combines personal mentions and Wanted encounters. The other tabs show each type separately. Both also appear in Overview and the compact recent list.
- First or full character names trigger personal mentions without @. Own messages remain excluded from personal mentions. Names and nicknames are exact; watch phrase typo matching remains optional.
- Pause Alerts from the header or compact icon: both alert types pause while their individual settings are kept. Resume restores those settings. Capture can stay off.
- Selecting an entry reads that alert. Mark all read affects only the selected subtype, or both in All alerts. It must not read unrelated Messages or Shield activity.

## Wanted encounters and chat icons

- Target or mouse over an attackable player whose GUID appears on Olympus's Wanted board. Expect an encounter in Alerts > Wanted and Overview, with time, source, your zone and a saved bounty snapshot.
- Target and mouseover share a five-minute per-player cooldown. Encounter sound and toast are optional and start off. Test opting in, burst limiting, toast navigation after combat, and silent history restoration after reload.
- Say an exact full listed name, or whisper it to yourself, to test the chat icon. Hover for current listed bounty, kills and cycle. Your own visible chat and outgoing whispers work.
- Chat icons never create Wanted feed entries, unread badges, sounds or popups, even with encounter notifications enabled. Clicking an icon has no action. First names alone, ambiguous names, wrong realms, item/spell links, hidden messages and covered names do not match.
- Disable chat icons separately in Alerts > Wanted settings. Filtered originals, reports and saved capture stay intact; the icon decorates only visible chat.
- Permission loss clears live data and active hover/popups while retaining saved activity. Restoring permission resumes matching. Olympus list changes update hover details; saved encounters keep their historical bounty.

Olympus owns its board and bounties. ChatWarden reads the supported consented API and does not submit sightings or automatically shield/report Wanted players.

Offline verification uses production Lua 5.1 and the supplied Olympus API in a simulated host. Native WoW rendering, tooltip input, unit events and combat still need an in-game pass. Filtering policy, signed packs and artwork are unchanged.
