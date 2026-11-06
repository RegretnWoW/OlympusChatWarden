# Fireside — release-candidate guide

## Integrated76 accepted-ID compatibility

Exact membership also preserves older schema-valid zero-padded event IDs. No accepted identity is renamed or replaced by its numeric spelling.

## Integrated75 protected-save completion

Already-decoded large roots remain losslessly encoded at logout even when data protection is active. Invalid pending-journal states cannot advance verified checkpoints. Healthy behavior and approved artwork are unchanged.

## Integrated74 explicit recovery completion

A checksum-damaged current primary no longer prevents a deliberate restore of a verified checkpoint. Its original envelope must be retained first; a failed retention still blocks the operation. Damaged bytes are flagged in undo rather than presented as a valid recoverable generation.

## Integrated73 recovery correction

Normal addon folder replacement no longer falsely flags valid startup observations that fill reserved event-ID ranges. Every previously committed identity remains checked. The primary save is admitted without restoring an older checkpoint. Pending v2 recovery evidence is qualified through an isolated replay, saved reading pages are checked by their actual cleaner and seal, and history rollback preserves the current sharing identity/counters. Original data and development media remain intact. Native Forever/Retail qualification is pending; this is a test candidate, not a public-release GO.

## Integrated63 native scene corrections

The reader camera now stays above the complete opening book and uses a wider
view over 2.6 seconds. An off-centre placement cannot force the camera into the
book. The 2D pages and all their children are stacked above the native viewports.
Journal text increases slightly from .48 to .54, keeping accessibility scaling.

The live logo flame draws above the outer border. The bottom-right Open Menu /
Close Menu button is the only menu toggle; the old top button is removed.
The display shelf has a native backing pass and a badge pass below characters.
Its badges sit .06 model units lower. Both Olympus flags draw behind characters.

Campfire Replay retains one small grounded native book and no temporary table.
The wider 1.65 framing moves over 4.5 seconds. Its two exact welcome lines use
readable scene captions; the camera stays focused on the player and firepit.

The editor shows directional-vector, point-source and lighting/effect locators
with correct window scaling. The owner's home and Fields exports are retained
as new private layout revisions; prior saved layouts remain untouched. Unverified
effect placements stay private Lab candidates, without production promotion.
Native model depth, camera, animation and lighting still require client checks.

## Integrated62 reading and motion correction

Journal body text and headings use a .48 base scale, one third smaller than
Integrated61, while retaining the owner's accessibility multiplier. The extra
top Close and navigation controls are removed from the reading view; page-edge
interaction and normal keyboard navigation remain.

The reading camera now targets the placed native book, pitches toward a near
overhead view and fits within the real rotated desk surface. The existing 2D
reader has one contact shadow. Closing restores the authored room camera;
the furniture, reading history, notes, drawings and saved layouts are preserved.
Native framing requires separate Forever and Retail client inspection.

The logo flame regains its natural 36 by 40 proportions and extends above the
window. Campfire welcome owns its camera and consumes opening/skip mouse clicks,
preventing the same click from reaching Journal or Hearth actions behind it.
The real Settings Replay control, click consumption and camera exclusivity have
focused regressions. Simulator execution cannot certify native cinematic motion.

## Integrated61 Fireside branding

Fireside is the visible product name, with Olympus beneath its new gold
wordmark. The wreath is removed. The sapphire torch has a separate fixed bowl
and live flame; the wordmark keeps uniform proportions. Menus, native settings,
launchers, help, guides and the public addon-list title use Fireside. /fireside
opens the normal menu; /warden, /ocw, /ow and /chatwarden remain compatibility
aliases. Folder names, SavedVariables, API identifiers, trust anchors, signatures,
rule packs, music IDs and actual Warcraft reference names remain unchanged.
Integrated60's menu, Hearth, Replay, asset cleanup and RAM changes are retained.

## Integrated60 menu, Hearth and cinematic repair

X closes the whole Fireside window. Close Menu leaves the living world visible.
Olympian Oasis performs the installed client-timed Hearthstone sequence and then
travels home with the menu closed. Repeated clicks reuse the existing cast.
Walking transitions preserve menu visibility. Other content tabs do not travel.
Settings > Advanced & help > Replay campfire welcome starts the cinematic in
Olympus Fields. Success no longer refreshes/cancels it, and same-route background
refreshes no longer count as navigation. A missing model or other blocked start
now displays a clear Close-able explanation. Native playback remains unverified.
The welcome accepts Chronicle's actual realm/character owner identity; previous
bare-GUID welcome keys and incompatible saved roots remain preserved.

The minimap and native micro-menu use a new small flaming Fireside torch and open
Olympus Hall. The native inspection shortcut uses the Aether emblem. Existing
launcher settings and permissions are unchanged.

The scene rig reuses its node and quad scratch tables rather than allocating
them on every redraw. A dependency audit excludes 798 unused legacy animation
files from distribution and releases 177 unreachable legacy metadata entries.
Original artwork remains in the source and previous complete build; current
badges, mementos, reader art, music, scene sources and Lab backdrops are retained.
Measured Lua fixture results and the exact file proof accompany this build.
These measurements do not certify whole-addon native RAM or texture memory.

## Integrated59 soundtrack update

The approved Keeper of the Flame menu loop, latest layered Fields and Home masters,
and a short action cue for the campfire book sequence are included. Music is on by
default; turn it off on the first setup page or in Settings > Sound & Ambience.
Explicit global Fireside sound and WoW mute/volume choices remain effective.

Menu, Fields and Home keep independent saved playback bookmarks. Returning uses a
nearby resume point, up to two seconds earlier, with a short crossfade. Time away
does not advance a track. The cinematic starts fresh on replay. Closing the entire
Fireside window releases music to WoW; closing only the menu keeps world music going.
Clients without stoppable sound handles fall back to full tracks without seeking
or crossfades. Native audio timing, cache behavior and audible joins require
separate Forever and Retail testing. No game volume setting is changed.

The welcome uses the live edited firepit, collision-checked staging, and the actual
book projection for its camera. Moving the firepit before replay moves the staging;
removing it or leaving no reachable clear space fails safely. Editing its transform
mid-cinematic cancels and restores the character. Clicking your own scenic character
does not open your profile; other remembered-player profile clicks remain available.

No scene artwork, route/history evidence, earned decorations, sharing permission or
public SDK behavior changed. The release-readiness candidate remains the rollback.

Build `1.1.4-unified-2.11.8-integrated63-scenefix1`; November2,2026; Integrated59 soundtrack candidate. Native release qualification is pending; no public release is authorized.

## Changes under review

- Whole-product source/entry-point/size audit and shared P0/P1/P2 register.
- Current-build help and public guides; truthful local/pending/network and snapshot/live distinctions.
- Offline-first Settings bug composer: expected behavior, reproduction, client context, optional aggregate diagnostics, editable/redactable local preview and duplicate draft reuse. No automatic submission.
- Contained once-per-character campfire/book welcome using existing models and scene controller; immediate skip/replay and exact-state restoration are native acceptance gates.
- Positive runtime allowlist, deterministic package manifest and reference checks; developer files and proven superseded duplicate assets remain archived outside the installable ZIP. Unknown dependencies are retained.

This candidate has a new version; native release qualification remains pending. Use the final source commit and package SHA256 to identify this candidate. Integrated58 and its originals remain the rollback baseline. See GO_NO_GO.md and TEST_RESULTS.md outside the installable addon for actual results. No public publication or release tag has occurred.
