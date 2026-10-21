# RelayWarden — 1.1.1

Relay has three primary areas: Support, Data & Backups, and Help & Updates.
Support contains Report a Bug, My Reports and Advanced Tools. Developer Inbox
appears only for the configured native developer identity.

## Report a Bug

Choose the module, enter a title and describe what happened. Reproduction steps
are optional. Choose **Submit Report** once. Warden saves the exact submission,
opens it in My Reports and handles delivery while you are online. The report
window can be closed. Nothing unfinished is sent.

**Include Technical Details** defaults off. It includes Warden version and the
small approved diagnostic snapshot, including initialization/module status and
bounded Warden Lua error file/line counts. **View Details** shows exactly the text
and optional snapshot that will be submitted; viewing it is not a prerequisite.
Changing a form invalidates displayed details without disabling a valid Submit.
Every new, copied or recovered form clears attachment consent.

Your report and native character name are shared with the Warden developer.
No chat, locations, history, player dossiers, private notes, guild records, GUIDs
or SavedVariables are silently attached. Descriptions contain whatever you type.
The randomized report identifier is not an anonymity guarantee.

Unfinished forms save locally. **Advanced Tools > Recover unfinished report**
recovers existing text, including older preview drafts. Explicitly discarding the
current unfinished form requires confirmation. Existing records are not purged.

## My Reports

Submitted reports show their title, module, submission date and original text.
Sending means an attempt is in progress. Waiting to Deliver means Warden will
automatically try again while online. Delivered requires a validated receiver
acknowledgment. Needs Attention includes explicit pauses and permanent failures.
Advanced Details retains original failure messages, identifiers, retry timing,
technical attachments, Retry Now, pause/resume, copying and two-click deletion.
Changing filters clears a selection that is no longer in the displayed list.

The unchanged transport retries after 1, 5, 15, then 30 minutes, remaining capped
at 30 minutes. It tries both designated characters without separate presence
probes. WoW must be running and connected. Paused choices and retry schedules
survive reload. Older manual-only submissions remain manual until explicitly
resumed. Acknowledgment stops retries; deduplication prevents another Inbox copy.

Only Olympus Wardn and Rune Escape on Classic Beta PvP receive reports. Both
peers need compatible Relay builds and Olympus access. Home-realm whisper targets
use native First Surname routing; receipt checks retain full realm identity.
Actual native send results enforce refusals; a validated receipt confirms delivery.
Self-delivery was confirmed during beta. Two-client/offline retry acceptance is
listed separately in the release checklist; it is not established by offline fixtures.

An acknowledgment means the receiver has a validated in-memory copy. Normal
logout/reload persists it; a crash before a save can lose an unflushed copy.
Delivered does not imply developer review, a promised fix or a cloud backup.
Local ChatWarden filter feedback is separate and is never auto-forwarded.

## Advanced Tools and Developer Inbox

Diagnostics is generated on deliberate access; it does not start profiling.
Last native send retains the real result/step/byte count without report payloads.
The error hook delegates to the previous handler, retains at most 20 unique
session Warden file/line locations and excludes original messages/stacks/locals.

Inbox access requires the native configured character and realm, not a saved
developer flag. Search, module/version/status filters, original descriptions,
attachments, copied exports and local review labels remain available. The labels
New, Reviewing, Confirmed, Fixed and Closed send no reply. Incoming report text
is never executed. The same WoW account shares its local inbox; separate accounts
do not synchronize their inboxes.

On a developer character, Advanced Tools > Create self-test prepares a labeled
report addressed only to that character. Choose Submit Report, confirm Delivered
and exactly one Inbox entry, then reload and verify both. This uses the real native
transport and acknowledgment path, not simulated success. Self-delivery tests
one client; it does not establish delivery between two accounts.

## Storage and backups

Relay uses `OlympusWardenRelayDB`, schema 1. Chronicle's schema 6 and its recording
consent remain unchanged. Both saved variables belong to the installed addon
`OlympusChatWarden`, so WoW stores them together in the existing account file:

`WTF/Account/<account>/SavedVariables/OlympusChatWarden.lua`

The unchanged Windows backup tool copies that entire file, including Relay.
History-only text merges cover Chronicle history and do **not** include Relay
drafts, inbox or receipts. Close WoW normally before complete-file backup/restore.
Copies are private. Deleting history does not delete Relay reports, and deleting
a Relay report does not delete Chronicle history. Complete-file restore replaces
both saved variables with the chosen file's contents.

Relay retains up to 200 local reports and 500 inbox reports. It never silently
expires or evicts reports; at capacity it refuses new records and asks you to copy
or back up before explicit two-click deletion. The pending queue is limited to 20.
Unsupported or malformed Relay saved data is retained and blocked for recovery.
Reload interrupts sends into Pending; previously enabled automatic delivery resumes
with the saved schedule after a short login grace period. Paused and older
manual-only reports remain paused. Drafts never transmit on login.

Before rolling back to public 1.1.0, save a complete 1.1.1 file backup too. The older
TOC does not declare Relay's new saved variable; do not rely on the old build to
retain Relay reports when it next rewrites the account file. Keep the 1.1.1 backup
separately so Relay reports can be restored when you return to this preview.

## Transport limits

The independent protocol uses the registered `OWRelay1` native addon prefix and
WHISPER only. It never uses Olympus's private queues or adds a new Olympus API.
Reports use a strict length-prefixed field allowlist; received data is never Lua
code. Raw report size is at most 8,192 bytes, sent in chunks of 80 bytes encoded
as hexadecimal. Messages are at most 240 bytes, with at most 103 chunks.

Each client sends at most one Relay message every 350 ms, with no catch-up burst.
One outgoing transfer and four incomplete incoming transfers are allowed. One
incomplete transfer per sender, two new transfers per sender per minute and a
bounded control-message queue protect the receiver. Incomplete transfers expire
after 120 seconds. Duplicate IDs with identical checksums receive receipts without
another inbox copy. Conflicting IDs, corrupt payloads, invalid fields, wrong peers,
unexpected channels and unsupported protocol versions are not accepted.

Adler-32 is a corruption check, not a digital signature. Native message acceptance
is never treated as proof of delivery. Delivery between two accounts still needs a native
Forever test. Offline fixtures do not establish live delivery or native throttling.

## Scope

No announcements, chat conversations, remote settings commands, moderation,
gameplay synchronization, aggregated reputation/mutes, external service, GitHub
issue creation or automatic private-data upload is implemented.
