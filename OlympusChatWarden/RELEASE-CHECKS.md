# Olympus Warden 1.1.4-rc3 — current native release gate

Use this exact main-only candidate and a complete SavedVariables backup made with WoW closed. Do not clear history to resolve a loading or UI error. Native results are NOT_RUN until observed on this candidate.

- Login and `/reload`: no Lua error; retained history validates and reading views become ready. Open/close Command, Chronicle and Intel.
- Reopen Intel with a populated list, then click a player immediately, including during BG combat. The dossier opens when ready without changing tabs. Check that a draft note and watch choice remain intact.
- BG Intel: with a recorded player targeted, click My target before and during combat; verify safe deferred navigation to the clicked GUID. Change targets while waiting and confirm the first player's dossier opens. Check original-source navigation.
- Confirm normal module/recording/witness/duel choices remain respected. Pausing collection preserves old history; ordinary BG players remain light, while independent watches/friends/earned Important qualify future native-readable detail.
- Confirm routine spell phases are separate counts and an interruption does not invent its interrupter. Ordinary duel results remain without unsolicited deep Inspect.
- Observe a new accepted event, then normal logout, fully exit/restart and verify old and new history. Use `/warden chronicle check` for pending cast and recovery state. Pending observations must block an incomplete text export.
- Check ordinary BG responsiveness and native CPU/memory without confusing desktop benchmarks with game performance.
- No surprise Relay submission, background test workload or expanded chat permissions. Existing explicitly submitted report delivery remains unchanged.

Record client build, candidate ZIP hash, action and exact error/diagnostics for a failure. If all critical checks pass, freeze and publish. Unexercised native API sources remain native-unverified. This candidate is not publicly stability-certified yet.

