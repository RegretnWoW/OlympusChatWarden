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

Install the matching client RC ZIP into that client's `Interface/AddOns/` folder so that one `OlympusChatWarden` directory contains its TOC. Do not nest another release directory. Forever and Retail-Test have independently identified distributions and native test results. Retail-Test uses separate saved-variable roots and its existing test-mode unlocks; neither client proves the other works. Both require native qualification. Forever is launch-critical. Back up WTF data with WoW closed before updates. The private Lab, simulator, source projects and QA evidence are separate developer artifacts.

Open `/fireside`. The top tabs are Olympus Hall, Aether, Athenaeum, Olympian Oasis, Atlas, Logos, Aegis, Vigil and Settings. Gameplay history, reference lore, scenic representations and current peer data have different provenance. Recording and sharing remain separate opt-ins.

This candidate includes the existing physical Journal, shared doodle engine,92 activity badge identities, owner-earned mementos and shelf, point-and-click scenes, remembered visitors, long-form original music and authenticated-record implementation. Native enrollment/sender binding, actual two-client delivery, model/effect/audio behavior, combat and the new campfire cinematic remain release gates. Code presence is not a claim of native success. The public third-party SDK stays disabled.

Start with [Quickstart](QUICKSTART.md), then [User guide](USER-GUIDE.md), [Privacy](PRIVACY.md), [Reporting](REPORTING.md), [Backup](BACKUP-GUIDE.md) and [Troubleshooting](TROUBLESHOOTING.md). Help in Settings uses the same current-build topics. No mandatory Bridge, web backend or automatic upload is introduced.

Approved art and original music are preserved. Scene objects reference models installed in the client; Blizzard models are not redistributed. Required source/license notices remain included. Development backups/history are not deleted to reduce distribution size.
