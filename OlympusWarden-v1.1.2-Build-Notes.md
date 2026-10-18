# 1.1.2 hotfix scope and evidence

The affected live build showed “Recording enabled; waiting for a supported character identity and world entry” after history finished loading. Running `/warden chronicle on` restored recording, as confirmed by the user.

The 1.1.1 release archive reproduces this status in a native-shaped event-dispatch fixture: recipients are selected before callbacks run; Olympus access resolves in Core's world-entry callback; the newly attached history frame misses that in-flight event. The loaded archive remains readable but the recorder never starts.

The always-on module lifecycle observer now forwards world readiness to Chronicle independently of the gated collector frame. Existing validation, access, module and consent checks remain authoritative. Pending native login/reload flags survive deferred startup. Leaving-world/logout clears readiness. No polling loop or continuous collector is added.

Thirteen focused offline suites pass, including 28 login/gate scenarios, all 32 module combinations, native Inspect-shaped gear capture, readable inspection fields, closed-window loading, startup recovery, archive preservation, activities, intelligence, Relay transport and Windows backup/restore. The hotfix fixture explicitly checks new manual inspections in Recent and All profiles, gear retention after reload, both mention-delivery paths and no duplicate session from the fallback. All 118 Lua modules compile as Lua 5.1.

Only the startup handoff, compact diagnostics, version and release material change. Store/archives/backup formats, startup journal, inspection capture, Signal/Mentions implementation, Relay transport, signed packs, trust keys and artwork match 1.1.1 byte for byte. Saved history schema remains 6 and consent remains 5; all three SavedVariables roots stay declared. No user data is included in the install or evidence.

Native evidence is limited to the user's symptoms and successful current-session workaround. The patched automatic login path still requires live verification. A separate mention defect was not reproduced; mention handlers are unchanged. Missing historical observations are not fabricated or backfilled. No GitHub publication or installed-addon replacement was performed.
