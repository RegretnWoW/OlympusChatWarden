# Olympus Warden 1.1

Olympus Warden is the overall addon. The main sidebar has five feature brands:

| Section | What belongs here |
| --- | --- |
| ChronicleWarden | Personal highlights, measured time, progression and shared adventures |
| IntelWarden | Recently met players, saved dossiers, Appearance & Gear and private notes/watchlist |
| ChatWarden | Messages, Capture, Rules, Packs and Reports |
| SignalWarden | Personal mentions, Wanted encounters and passive OlympusMute sharing observations |
| ShieldWarden | Contact protection, active shields and allowed players |

Warden Home shows recorded-data summaries and local suite search. Search includes
tools, activity, saved capture/bookmarks, personal rules/reports, pack descriptions,
saved player profiles and recorded-event metadata across retained characters.
Results are grouped by Warden module and use readable names, places and dates.
The UI does not index arbitrary equipment, spell, route or snapshot-body fields.

Appearance & Gear keeps dated equipment around a native model. The model needs
a currently visible GUID-matched unit; missing units never use a substitute.
Gear is historical even when the model is live. Older recorded loadout changes
can be browsed, and Original evidence opens the source observation. No offline
appearance reconstruction or inspection requests are added. Notes/watchlists
are private annotations that can be edited while recording is paused.
It checks 128 records per frame, pauses in combat and shows at most 30 results per
group. It never searches the network. Chat matches open the original view rather
than displaying hidden originals in a search snippet. A search is a snapshot;
run it again for newer records. Raw snapshot payloads and every spell/item field
are inspected through the original event browser, not indexed in this first pass.

Data & Backups keeps the full event browser, collection explanations and existing
backup flow. The new personal journal shows up to 200 recent highlights from the
existing indexes. Recent players includes local observations, roster history and GUID-linked PvP reports;
All profiles also includes public-source-only records. GUIDs remain separate even
when names match. Remote-roster association is not physical proximity or attendance.
Credits do not establish individual killing blows or confirmed killers.

The six new bitmap emblems use cobalt enamel, Greek meander rims and bronze/gold
metal. The main crest features the existing Zeus guardian character. The original
bottom-left guardian artwork and panel trim remain. Sources are in
`Marketing/Warden-1.1`; game-ready PNG/TGA exports are in `Media/Warden`.

This release keeps the installed folder `OlympusChatWarden`,
`OlympusChatWardenDB`, the Olympus application identity, recording schema/consent,
signed-pack keys and payloads, and saved-file/backup-tool contracts. Replace the
existing addon folder; do not install a second copy. Existing Olympus privacy
approval remains attached to that identity. `/warden` and `/ow` join `/ocw` and
`/chatwarden`; the old data commands with arguments remain available.

OlympusMute is passive: only a complete compatible message creates a signal,
once per sender per login. Shared lists are discarded. No sound/toast was added
for these observations. Disabling the existing OlympusMute observation setting
stops new observations; the suite alert switch controls their unread badge.
Signals use the existing bounded activity history, separate from permanent
Chronicle evidence. This adds no outgoing communication or continuous tracking.

Built-in image generation produced the artwork; image preparation only resized
and converted formats while preserving transparency. No private signing material
or personal recorded data belongs in the preview package.

IntelWarden derives three tiers from retained evidence. Tier 1 is Important:
group/raid relationships, GUID-bound friendship, manual inspection, watches,
direct Wanted encounters or supported personal native opponent credit. Tier 2
is Activity participant, such as a GUID-linked scoreboard row. Tier 3 is a direct
Casual observation. Reasons include source dates; repeated sightings alone do
not promote a player. An external Olympus source alone creates no local tier.
These classifications never schedule inspections. Current watch status can
promote a profile display; removing it retains any actual historical evidence.

PvP reports preserve observed zero versus unavailable fields. A recording run
and sequence identify a report, not a proven unique match. Repeated payloads
refresh that report's display; reports are not summed into lifetime totals, K/D
or unique match counts. Inspect honor and reputation remain unavailable.

The compact feed shares the 128-record-per-frame activity index. Meaningful
references are bounded to the newest 120 per module; full history is retained.
Player and activity links validate the original event and exact GUID, wait for
cooperative indexing, and fall back to original evidence if a projection is
unavailable. Leaving the page cancels pending navigation.

Readable inspected talents use the native INSPECT_TRAIT_CONFIG_ID only, during
the owned GUID-matched response. At most 256 nodes and 80 selected entries are
read per response; incomplete coverage is explicit. Each saved selection keeps
tree, node, entry, rank, definition and spell IDs. Current native labels/icons
describe those IDs; the original export is preserved under the existing 6 KB
snapshot limit. Old export-only records remain valid and can be re-inspected.
No full offline talent tree, tree connections or exact appearance is inferred.

Preview 6 keeps the same design and functionality. Its activity and Intel views
share an event lookup, with at most two warm character indexes. Hidden pages
drop rebuildable results and models; selected IDs and original saved evidence
are retained. A cold third character rebuilds its derived index. Unchanged rows
and dashboard counts are reused until history, annotations or query inputs change.

Cooperative jobs stop at the existing work cap or a 2 ms elapsed target where
the native timer is available. An individual record and Lua GC cannot be
preempted; login validation and logout serialization remain synchronous.
Chunked loading keeps recovery input untouched until full validation succeeds.
The spelling dictionary remains lazy and its membership/suggestion behavior is
unchanged. Developer profiling is voluntary, session-only and off by default.
