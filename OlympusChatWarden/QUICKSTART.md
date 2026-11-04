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

## Fields and Olympian Oasis

Click clear ground in a wide scene to move your reconstructed current character. Click a chair or campfire to approach and sit when the installed model supports it; click elsewhere to stand and move. Obstacles and other people affect paths.
The gatehouse leads to Olympian Oasis. The home's lower-left exit returns to Olympus Fields. Door hover text names the destination. Content tabs do not teleport you out. Closing/reopening preserves the canonical scenic location; orderly logout saves it separately from gameplay evidence.
Saved people in Fields are private scenic recollections, not online remote players. Unknown face/hair remain generic; available race/body/gear are source-qualified. A recent Aether state is only current when genuinely received.
Scene placement, lights, shadows, rotated hitboxes and portal boxes can be edited/exported in the private Hephaestus Lab companion. This editor is not part of the public addon alone. Undo/reset affect layout, not recorded history.

See [User guide](USER-GUIDE.md) and [Release notes](RELEASE-NOTES.md).
