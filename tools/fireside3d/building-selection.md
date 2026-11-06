# Forest tent selection

New single candidate: **Furbolg forest tent, FileDataID 202016**.

Exact native M2 reference: `world/kalimdor/kalidar/passivedoodads/furbolgtent/furbolgtent.m2`.

Source: existing public wowdev verified listfile, https://github.com/wowdev/wow-listfile . This is an older Kalidar/Teldrassil forest-creature shelter reference rather than a Night Elf architectural tent. A listfile resolves the model identity, not its actual entrance geometry or installed/native rendering availability.

[Style-reference image search](https://www.google.com/search?tbm=isch&q=WoW+Teldrassil+furbolg+tent) is provided for review; it is not a verified render of this exact FileDataID. No generated image or unverified viewer URL is presented as proof.

User-confirmed control: Night Elf tent 328178, `world/generic/nightelf/passive doodads/tent/nightelfsingletent01.m2`, rendered successfully in the user's client. It stays in the asset list with a reported-working label. The new model remains unverified.

Use Add forest tent in the existing editor for the one manual test. Check a visible opening, roof/enclosure and whether its forest style suits the scene. Decoration collision is off for inspection, so movement through a wall does not establish an entrance. Keep the layout unsaved until it is accepted. The native M2 loading method and startup scene are unchanged; no WMO, converted MDX, new renderer or automatic retries are involved in this new test.
