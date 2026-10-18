# Olympus Warden 1.1.1 release acceptance

The release package is based on the verified Preview 8 archive, with the personal-note/watchlist menu fix, CommandWarden search labels and consolidated release documentation. The main history store, archive loader, startup journal, collectors, consent, module lifecycle, signed packs and Relay transport remain byte-identical to Preview 8.

Preview 8's 70 offline suites and exact comparisons of 51,840 events / 225 profiles / four characters are baseline evidence. The release separately reruns focused menu, module, activity, intelligence, startup, archive and backup checks. These results are not a claim of native gameplay verification.

The supplied review reports improved native performance. Earlier conversation evidence confirms prior normal logout/reload and developer self-delivery. The build environment has not performed the following final native checks:

- [ ] Record an identifiable quest/event, log out and return; verify it appears exactly once.
- [ ] Capture an eligible event during startup validation, use `/reload`, and verify recovery with the original date/location and no duplicate.
- [ ] Switch between two characters; verify old/new history, notes and watchlists stay with the correct character.
- [ ] Explicitly open every saved character's history, then log out. Confirm no recurring hang or Lua error and that every archive remains available.
- [ ] With WoW closed, create and restore a complete backup containing main, Relay and startup-recovery SavedVariables.
- [ ] Send a Relay report between two actual clients. Verify exactly one Inbox report and a validated acknowledgment, including offline/retry behavior.
- [ ] Test Chat Only and Full Suite, including saved-note/watchlist Intel shortcuts, correct realms, ambiguous names and disabled-module links.

Any data-integrity failure, recurring Lua error, serious module regression or broken Relay delivery should stop publication. Synchronous logout packing of all expanded characters remains a native acceptance item; the review recommends testing rather than changing the working storage architecture without a reproduced defect.

No publication or GitHub update is performed as part of creating this release package. Release version naming does not imply the above native checks were performed. Keep results separated from synthetic fixtures.
