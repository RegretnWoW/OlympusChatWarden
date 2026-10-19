# 1.1.3 release check

Back up with WoW closed, then replace the existing `OlympusChatWarden` addon folder. Do not reset history. The full release bundle includes the Windows backup tool.

1. Reopen the talent inspection from the supplied screenshot. Confirm the inline export bar, placeholder and instruction paragraph are gone and the lower rows can be scrolled fully into view.
2. Click + and −: icons, ranks, branch headings and connections should grow or shrink together. The percentage should move in exact 25-point steps between 75% and 200%.
3. Pan to another branch and a lower row, then Reset. It must show **100%** and return to the start every time. Repeat from different zoom levels.
4. Reopen the same build or let its view refresh; zoom/pan should remain stable. A different player, character or build should begin at 100%. Changing global UI scale should not change the displayed talent zoom percentage.
5. Use **Copy native export** where available. Confirm it opens the original text separately. A build with no export should disable that action, without a placeholder across the tree.
6. Retest exact-player Inspect navigation, historical gear tooltips, ID-only item-type labels, and the three optional shortcuts. They still start off on a fresh configuration and preserve existing choices.
7. Reload and open My Reports without submitting anything. Existing reports should appear. Check retained history, notes, equipment and previously consented recording using `/warden chronicle check`.

Offline checks do not establish actual native rendering or client API timing. The new zoom/overlay fixes need the in-game check above. Older ID-only gear cannot regain missing historical modifiers without another observation. Back up before rolling back to older readers that do not support the optional talent metadata.
