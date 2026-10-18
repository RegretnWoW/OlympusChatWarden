# Installing and testing the 1.1.2 hotfix

Exit WoW normally, then use the included Windows backup tool to create a complete backup. Extract the addon ZIP's `OlympusChatWarden` folder into the client's `Interface/AddOns` folder. Keep the existing WTF/SavedVariables files; no reset or consent change is required. The addon keeps its original folder and saved-data identity.

On login, let history validation finish with Warden closed. Run `/warden chronicle check`. With existing consent, enabled history modules and Olympus access, the first line should say recording is active. The next lines show world/identity readiness and collector counters without flooding chat.

1. Inspect a new player normally. Verify they appear in IntelWarden's Recent players and All profiles, with readable gear where available.
2. Complete a quest or make another supported Chronicle event. Verify the new dated record appears.
3. Reload normally. Verify recording starts automatically, old notes/history remain, and the newly inspected player and gear return.
4. Check a personal mention sent by another player in an enabled channel. Own outgoing messages do not count as incoming mentions; Chat Capture can remain off.
5. Confirm pausing recording or disabling historical modules stops new collection while keeping old records.

The build environment reproduced the 1.1.1 failure and passed the patched scenarios using Lua fixtures. The user confirmed `/warden chronicle on` restores recording in the affected live session. Automatic login with this patched ZIP remains a live acceptance check; fixture results are not live-client verification.

If recording still waits after loading, paste the three lines from `/warden chronicle check`. Keep the original archive and backup; do not clear history to troubleshoot. Observations missed while recording was inactive cannot be recovered retroactively.
