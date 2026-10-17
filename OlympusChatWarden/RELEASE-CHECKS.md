# 1.0.3 release-candidate live checks

This is the clean 1.0.3 package. Nothing has been published automatically.
Back up the full SavedVariables file with WoW closed before testing.

- Review current 1.0.3 notes: the cards cover all changes since 1.0.2. Previous
  continues to1.0.2/1.0.1/1.0.0. Check header wrapping and every Recording tab.
- Start/decline recording, reload and verify that the saved choice is respected.
  Browsing with recording off must not enable collection.
- Open Intelligence. Check measured time, UTC periods, recording segments,
  players/relationships, PvP visits, scoreboard observations and progression.
  Search, target history, paging and original-source navigation must work.
- Record AFK/non-AFK periods, zones, combat, groups, loading and logout/reload.
  Check that overlapping dimensions are labelled and gaps remain unmeasured.
  Compacted/unplaceable records stay inspectable as unallocated reported time.
- Group, change rosters and run/leave/re-enter a dungeon or PvP instance.
  Verify partial segments and unknown individual attendance/outcomes remain.
  Repeated local target/mouseover checks must not manufacture new rivalries.
- Test native completion/scoreboard availability. Reports and observations must
  stay separate when unique match identity is missing; no guessed win/loss.
- Verify original history, notes and packed-file/text restore remain intact.
  Check an imported record's backup warning. Clear must cancel derived work.
- Check normal filtering, Olympus access, Alerts, Shield, spelling and Capture.

The remaining historical checklists below are retained as research/test context;
preview version labels there describe earlier internal builds.

# 1.0.3 preview 10 live checks

- Back up the complete saved file with WoW closed before testing.
- Open Recorded Events: Events should hide background observations. Check All
  recorded data, custom type selection, search and return to Events. Recording
  and retained totals must remain unchanged.
- With recording enabled, target/mouse over a listed visible player. Confirm a
  Wanted encounter event and its dated source. A remote board update, nonvisible
  focus or chat name mention must not produce a local encounter event.
- Test Native actions, Native background summaries and Native activity (all),
  including adding an observation to the quiet preset.
- Open a large history, change filters while loading and search for absent text.
  Confirm responsive progress, combat deferral and source selection after loading.
  Check Collection Status for full measured-time/storage figures.
- Enable recording inside a dungeon, /reload inside a raid and leave/re-enter
  the same map. Each startup pair should share one partial segment; separate
  recording boundaries and real re-entry should remain distinct.
- Select an activity, then exclude it using search, type, player and page changes.
  Confirm details and player/source controls clear. Open a source record hidden by
  Events and confirm it is deliberately shown in All recorded data.
- Verify current version1.0.3-preview10 and published update history1.0.2/1.0.1/1.0.0.

# Shared-activity live checks

- Keep a complete saved-file backup with WoW closed before testing.
- Open Recording > Activities with recording off and browse earlier history.
- Start an opted-in dungeon/group session; verify its observed roster and boss
  result records appear when the client supplies those events. Test with the
  native meter unavailable; activities must still work.
- Change rosters, reload, leave/re-enter the same instance and pause recording.
  Verify partial segments and unknown outcomes are visible, with no guessed run
  completion or player attendance. Check two characters and repeated runs.
- Select an activity/player, scroll details, page activities/source records and
  open a source record. Check narrow/full scaling and text wrapping.
- Confirm original history and notes survive normal reload and backup/restore.
- Confirm Olympus access, filtering, Alerts, Shield, spelling and Capture.

Offline fixtures are not a live-client compatibility claim. This build adds no
new native API reads or communication. DPS/HPS/interrupt and individual attendance
matching remain unimplemented rather than guessed.

# 1.0.3 release validation

Offline tests use a synthetic WoW host. Keep a complete saved-file backup before
upgrading. Native Forever behavior still needs a live pass.

- Verify first-login opt-in, saved scope5 consent, pause/clear and Olympus permission loss.
- Click Collection Status entries and scroll their explanations. Click recording
  metrics and settings statistics; no hover should be required.
- Check your routes and encounter positions, with missing values kept unknown.
  Repeated target/mouseover events must not become continuous movement sampling.
- Backup & Restore opens File backup first. Use the Windows tool with WoW closed.
  Confirm a full restored file retains all addon settings/history.
- Check history-only text merging, including reverse and idempotent imports.
- Verify old tracks, notes, profiles and linked snapshots survive reload.
- Check filtering, Shield, spelling, capture, Alerts and Olympus controls.

The Windows tool is tested on synthetic files under PowerShell5.1 and7: byte-exact
restore, safety copies, corrupt/truncated archives, new-PC destinations, locks,
running-game guards and concurrent-file changes. No personal files are opened,
and no game is launched.
