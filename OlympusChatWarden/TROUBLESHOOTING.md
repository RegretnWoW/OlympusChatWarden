# Fireside — release-candidate guide

Build `1.1.4-unified-2.11.8-integrated63-scenefix1`; November2,2026; Integrated59 soundtrack candidate. Native release qualification is pending; no public release is authorized.

## Troubleshooting and native checks

First record the build, client flavor/build, module and reproduction steps. Check Settings > Modules and the relevant consent/mute preference. Missing or inaccessible API fields remain unknown; do not enable invasive recording to diagnose them.
If scene controls are stuck, close the book/showcase/editor, return to a wide view and try a clear ground spot. Avoid editing during transitions/combat. A native model can fail to load even when the simulator layout passes. Report the exact status using optional diagnostics, not a full private dump.
For missing sound, check game channel mute and Fireside gain. For missing screenshots, inspect the game's folder. For Aether, distinguish local pending, participation/enrollment and actual received delivery. Back up before recovery. Do not clear history to hide an error.
Independently on Forever and Retail, native fresh install, upgrade, combat,30+ transitions, long session, two-peer authentication, audio loop and cinematic skip/replay are release gates. Forever is launch-critical; safely isolated Retail limitations do not remove working Forever features. This candidate does not claim either client's gates passed.

## Backup, recovery and rollback

Before updating, exit WoW normally and copy the complete Fireside SavedVariables files and .bak files from the correct client's WTF/Account account folder to a separate safe folder. Include the complete account file and any matching per-character files. Never test recovery using the only copy.
Settings > Data & backups history parts contain selected history/profile data, not every setting, consent, signed pack, chat store, Relay record or recovery journal. They are not a substitute for the full file backup.
Use copied files for fresh/upgrade/corruption tests. Do not overwrite a corrupt or newer-format original to obtain a clean launch. Incompatible signed records and future schemas must be retained for recovery. Reinstalling an addon ZIP should not erase WTF data. Restore backups only with WoW closed and after preserving the current files too.

## Sound, music and accessibility

Settings > Sound & Ambience controls Fireside gain, physical sounds, ambience, home music and the Fields score. The installed long-form masters are Fields8:13 and home4:27, not the short demos.
Fields music is eligible with hidden menu OR fullscreen. Home music is opt-in. Leaving its scope releases native music control to Blizzard. Native music has no seek/pause API: reentry restarts; Fireside does not recreate the game's playlist or change global volume CVars.
Reduced motion suppresses decorative motion and reduces transitions. Reading/navigation/Skip remain available; scenic walking currently also requires motion enabled. For a static welcome, approach the fire before enabling reduced motion. Whole-window scaling preserves proportions. Check text contrast and keyboard/mouse access at your intended UI scale. Actual sound loops, particles, glyphs and GPU behavior need real-client checks.

## Report a Bug

Settings > Advanced & help > Report a Bug opens an offline-first composer. Enter what happened, what you expected and reproduction steps; choose the affected module and optional severity. Version/client build and local report time are included.
Technical details are optional and previewable aggregate diagnostics. Full chat, whispers, dossiers, coordinates, routes, credentials and SavedVariables are never automatically attached. Edit/redact the copy before sharing; omit technical details whenever you prefer.
Save & preview creates a local report with an ID. Copy the text into your own local .txt file or an owner-approved support destination. WoW addons cannot write arbitrary desktop files or upload screenshots. Copy/export works without peers or Aether permission.
Existing Relay submission is a separate explicit network action to its configured recipient. A saved/queued report is not a receipt. Verify the destination and delivery status; no web backend or mandatory Bridge is implied.

See [User guide](USER-GUIDE.md) and [Release notes](RELEASE-NOTES.md).
