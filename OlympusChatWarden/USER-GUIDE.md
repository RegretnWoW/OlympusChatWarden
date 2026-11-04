# Fireside — release-candidate guide

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

## Start here

Open /fireside. Choose modules in Settings > Modules; opening a tab does not grant recording or sharing permission.
Olympus Hall is the overview. Aether contains community rooms, local people/profiles and support reports. Athenaeum searches reference articles. Olympian Oasis is your scenic hearth/home entry. Atlas contains Chronicle history and Journey Replay. Logos contains chat/review. Aegis contains Shield protections. Vigil contains Signal alerts. Settings controls preferences and privacy.
Content tabs preserve your scene and character position. The Oasis/Hearth tab closes the menu and focuses your current world without teleporting or resetting your character. Walk through scene entrances/exits to travel. These actions move only Fireside's representation, never your real WoW character.
Close Menu exposes the living world; Open Menu at the bottom right always returns to Olympus Hall. Escape closes an open menu; in the world, WoW keeps normal Escape behavior. No gameplay, collectors, communication or animation is paused. Fullscreen preserves proportions. The bell opens notifications. Native models, sound and secure controls require independent Forever and Retail verification; neither client is release-cleared.

## Athena and Chronicle

Recording begins only after its explicit consent in Settings > Atlas & recording. Pause keeps accepted history. Different conversation channels, first-contact inspection and public sharing have separate controls.
Atlas shows recorded events, activities, time and linked captures. A dated observation is not necessarily current. Source totals are not invented individual encounters; missing participants, rewards, dialogue and outcomes remain unknown.
The Journal assembles your retained evidence into reading pages. Reference lore and narrative wording are distinct from observed accomplishments. Inspect original sources when accuracy matters. No new location collector is introduced by this release.

## Journal, sketches and keepsakes

In Olympian Oasis, click the native desk book to open the reading view. Use page corners/navigation, chapters and source links. Close the book to return to the room. Opening a source or changing a view must retain reading position.
Personal notes and drawings stay private. A sketch is not verified historical evidence. Public drawings require a deliberate owner-approved Agora publication; ordinary text filtering cannot establish whether a drawing is suitable.
Click the display shelf for seven earned badge positions, then Edit showcase to add, move, swap, remove and save. Mementos require actual owner evidence. Glass, metal rim, contents and backing are separate materials. Native shelf fit and camera motion remain pending client inspection.

## Fields and Olympian Oasis

Click clear ground in a wide scene to move your reconstructed current character. Click a chair or campfire to approach and sit when the installed model supports it; click elsewhere to stand and move. Obstacles and other people affect paths.
The gatehouse leads to Olympian Oasis. The home's lower-left exit returns to Olympus Fields. Door hover text names the destination. Content tabs do not teleport you out. Closing/reopening preserves the canonical scenic location; orderly logout saves it separately from gameplay evidence.
Saved people in Fields are private scenic recollections, not online remote players. Unknown face/hair remain generic; available race/body/gear are source-qualified. A recent Aether state is only current when genuinely received.
Scene placement, lights, shadows, rotated hitboxes and portal boxes can be edited/exported in the private Hephaestus Lab companion. This editor is not part of the public addon alone. Undo/reset affect layout, not recorded history.

## People and saved appearances

An observed profile belongs to its recorded GUID/owner context. Inspect capture dates and source labels. A first-contact or equipment observation can be partial, delayed or unavailable under client restrictions.
Important/watched/friend captures are preferred scenic visitors. Ordinary eligible saved observations may be used when no preferred candidate is available. At most two remembered visitors plus your canonical character are intended. They do not prove a real meeting, live presence, friendship acceptance or a connected peer.
Appearance reconstruction uses installed generic race/sex bodies with available captured equipment. Missing customization and body clothing are not exact likeness. Consenting supported data sharing can improve available information; it does not grant access to private dossiers.

## Journey Replay and screenshots

Open Atlas > Journey Replay, choose a zone with saved travel and use Play/Pause or Restart. The actual Blizzard map is used. Thin trails connect valid recorded samples; gaps, teleports, disconnected sessions and missing coordinates remain breaks.
The marker reads recorded facing, not travel direction. Unknown facing is neutral. Between observations, motion/shortest-arc rotation is only a visual approximation. Historical route points are never rewritten by replay.
Athena's Moments requests supported screenshot bursts and records source/request status. A requested screenshot is not proof that a file was written. Check WoW's Screenshots folder yourself. Screenshots are manually attached to support reports; no automatic upload is provided.

## Aether, Agora and Direct Share

Aether participation is opt-in in Settings > Aether community. Posts, replies, upvotes and private drafts can be committed locally before enrollment. Local/pending records are distinct from authenticated network-eligible records and actual peer delivery.
Agora rooms replace Community Walls. Publish only your authorized content. Private Athena evidence, conversation text and precise routes are not automatically public. Review the limited activity summary or addressed Direct Share before authorizing it; the recipient must explicitly accept supported private history shares.
The pinned Fireside Authority is the enrollment root; an operator character is transport, not the permanent authority. Native enrollment, Blizzard sender/GUID binding and A→B→C disconnected forwarding acceptance remain unverified. Do not interpret a simulator ACK or enqueued addon message as native delivery.
No mandatory Olympus Bridge/server dependency is added. Olympus guild integration is separate. Public third-party SDK access remains disabled; private developer examples do not authorize third-party publishing.

## Athenaeum and sources

Search Athenaeum for a quest, item, creature, place, dungeon/raid or battleground. Open typed articles and their source/deep links. Reference catalogue entries are not proof that your character visited or completed them.
Partial articles, unresolved aliases and client-specific placements stay qualified. Source links can open a copyable external URL; Fireside does not fetch the web automatically. No new coordinates are invented, and paused community location collection remains paused.

## Logos / ChatWarden

Choose Mild, Balanced or Strict in Settings > Logos & chat; review a match in Logos. Warning, redaction, replacement and hiding are distinct display actions. Inspect the captured reason/source before changing a preference.
Olympus Protection and King Protection are the stock categories. Optional vocabulary comes from author-signed rule packs imported through the normal verifier. No client vocabulary override or signature bypass is part of this release.
Review feedback is saved feedback, not automatic learning or a new shared rule. Capture originals and private conversation retention have their own choices. Dedicated names, slang, language and channel/context rules can affect classification; a match is not proof of misconduct.

## Aegis / ShieldWarden

Aegis manages unwanted contact, active protection and allowed players. Settings > Aegis & contacts and Spam protection control thresholds and durations. An addon display filter, a game ignore/mute and an observed sharing signal are different actions.
Inspect the original supported evidence, expiry and reason before reporting a person. Counters are local observations, not global reputation or proof that another player muted you. Never bypass native combat restrictions; retry after combat if a protected action is unavailable.

## Vigil and notifications

Vigil shows supported mentions and alerts. The header bell opens notifications, including earned keepsake notices. Mark read and clear are distinct controls; consult each feed's scope.
Sound depends on Fireside preferences and the game's enabled channels. Muted audio is not a failed saved alert. Observed OlympusMute sharing does not prove who muted you. Fireside does not manufacture allegations or official achievements from a counter.

## Sound, music and accessibility

Settings > Sound & Ambience controls Fireside gain, physical sounds, ambience, home music and the Fields score. The installed long-form masters are Fields8:13 and home4:27, not the short demos.
Fields music is eligible with hidden menu OR fullscreen. Home music is opt-in. Leaving its scope releases native music control to Blizzard. Native music has no seek/pause API: reentry restarts; Fireside does not recreate the game's playlist or change global volume CVars.
Reduced motion suppresses decorative motion and reduces transitions. Reading/navigation/Skip remain available; scenic walking currently also requires motion enabled. For a static welcome, approach the fire before enabling reduced motion. Whole-window scaling preserves proportions. Check text contrast and keyboard/mouse access at your intended UI scale. Actual sound loops, particles, glyphs and GPU behavior need real-client checks.

## Backup, recovery and rollback

Before updating, exit WoW normally and copy the complete Fireside SavedVariables files and .bak files from the correct client's WTF/Account account folder to a separate safe folder. Include the complete account file and any matching per-character files. Never test recovery using the only copy.
Settings > Data & backups history parts contain selected history/profile data, not every setting, consent, signed pack, chat store, Relay record or recovery journal. They are not a substitute for the full file backup.
Use copied files for fresh/upgrade/corruption tests. Do not overwrite a corrupt or newer-format original to obtain a clean launch. Incompatible signed records and future schemas must be retained for recovery. Reinstalling an addon ZIP should not erase WTF data. Restore backups only with WoW closed and after preserving the current files too.

## Report a Bug

Settings > Advanced & help > Report a Bug opens an offline-first composer. Enter what happened, what you expected and reproduction steps; choose the affected module and optional severity. Version/client build and local report time are included.
Technical details are optional and previewable aggregate diagnostics. Full chat, whispers, dossiers, coordinates, routes, credentials and SavedVariables are never automatically attached. Edit/redact the copy before sharing; omit technical details whenever you prefer.
Save & preview creates a local report with an ID. Copy the text into your own local .txt file or an owner-approved support destination. WoW addons cannot write arbitrary desktop files or upload screenshots. Copy/export works without peers or Aether permission.
Existing Relay submission is a separate explicit network action to its configured recipient. A saved/queued report is not a receipt. Verify the destination and delivery status; no web backend or mandatory Bridge is implied.

## Troubleshooting and native checks

First record the build, client flavor/build, module and reproduction steps. Check Settings > Modules and the relevant consent/mute preference. Missing or inaccessible API fields remain unknown; do not enable invasive recording to diagnose them.
If scene controls are stuck, close the book/showcase/editor, return to a wide view and try a clear ground spot. Avoid editing during transitions/combat. A native model can fail to load even when the simulator layout passes. Report the exact status using optional diagnostics, not a full private dump.
For missing sound, check game channel mute and Fireside gain. For missing screenshots, inspect the game's folder. For Aether, distinguish local pending, participation/enrollment and actual received delivery. Back up before recovery. Do not clear history to hide an error.
Independently on Forever and Retail, native fresh install, upgrade, combat,30+ transitions, long session, two-peer authentication, audio loop and cinematic skip/replay are release gates. Forever is launch-critical; safely isolated Retail limitations do not remove working Forever features. This candidate does not claim either client's gates passed.

## Credits and campfire welcome

The Realm keeps the approved Warcraft/Olympus art, original music and client-installed Warcraft models. No Blizzard models or proprietary sample libraries are redistributed. Source and license notices ship with the addon.
The contained campfire welcome uses your actual reconstructed character and a nearby grounded physical book. Skip must be available immediately; Help replay is non-destructive. Missing native models/animations cancel safely. The two printed lines are the owner's thank-you and vision, not gameplay evidence.
This sequence must pass native playback and skip/restored-state checks before release acceptance. Your Journal pages, reading position, layouts and history must be unchanged.
