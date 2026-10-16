# 1.0.1: release testing

Keep a copy of the installed addon for rollback. Exit WoW, replace the
OlympusChatWarden folder from the addon ZIP, and keep WTF/SavedVariables.
Offline tests passed; native WoW behavior still needs testing.

## Import wanted packs

Signed packs from preview2 stay compatible. Import the six v11 title updates to
see the new names; their vocabulary and policy are unchanged. USA v6 and Labels
v7 are unchanged and need no update.
For new imports, the separate pack ZIP contains current signed files. Copy a wanted
`.ocwpack.txt` in full, then Packs > Import signed pack > Verify pack >
Install pack. Enable only wanted categories. Addon installation adds no packs.

Preview3's v11 terminology packs, USA v6 and Labels v7 are unchanged. If already
imported, no pack update is required for this build.

Old optional policy packs show Update Required and pause, including Gommage.
Previous choices remain saved. Labels v7 stays compatible. A normal verified
update resumes the prior enabled choice and per-pack sensitivity.

## Quick wording checks

Start with Balanced and Gommage off. `/ocw test <phrase>` prints the current
wording-policy result locally. It creates no feed, report, capture or Shield
activity and does not simulate language, spam or contact detection.

| Phrase | Pack needed | Balanced |
| --- | --- | --- |
| Olympus has terrible raid leadership | Olympus | Unchanged |
| Olympus is trash | Olympus | Warning |
| Olympus members are all idiots | Olympus | Redacted |
| Fuck Olympus | Olympus | Hidden |
| Asmon is bald lol | King | Unchanged |
| Asmon is a terrorist | King | Redacted |
| I'm going to attack Olympus members IRL | Olympus | Hidden |
| I want to kill Asmongold | King | Unchanged: gameplay ambiguity |
| I want to kill Asmongold IRL | King | Hidden |
| DEI is useful | DEI & Institutional Programs v11 | Warning |
| We should require DEI hiring policies | DEI & Institutional Programs v11 | Redacted |
| DEI is stupid | DEI & Institutional Programs v11 | Unchanged |
| Definition of inclusive language | Inclusive Language v11 | Unchanged |
| Our guild uses person-first language | Inclusive Language v11 | Warning |
| I prefer person-first language | Inclusive Language v11 | Warning |
| Person-first language is our standard | Inclusive Language v11 | Warning |
| Person-first language is our standard, but I hate it | Inclusive Language v11 | Unchanged |
| I prefer person-first language, but I hate it | Inclusive Language v11 | Unchanged |
| Person-first language is our standard, but I hate it for that reason | Inclusive Language v11 | Unchanged |
| Person-first language is our standard; however I hate it | Inclusive Language v11 | Unchanged |
| Person-first language is our standard, but I hate it personally | Inclusive Language v11 | Unchanged |
| Person-first language is our standard, but I hate it, personally | Inclusive Language v11 | Unchanged |
| Inclusive language is the way we speak here | Inclusive Language v11 | Warning |
| Person-first language is their standard | Inclusive Language v11 | Unchanged |
| DEI is our standard | DEI & Institutional Programs v11 | Unchanged |
| My pronouns are he/him | Pronoun & Gender Language v11 | Warning |
| Please vote Democrat | Communism & Democratic Party v11 | Redacted |
| I encourage everyone to vote Democrat | Communism & Democratic Party v11 | Redacted |
| We should all vote Democrat | Communism & Democratic Party v11 | Redacted |
| I endorse the Democratic Party | Communism & Democratic Party v11 | Warning |
| Please do not vote Democrat | Communism & Democratic Party v11 | Unchanged |
| Safe spaces are stupid | Social Concepts & Advocacy v11 | Unchanged |
| America is dumb | USA v6 | Warning |
| Why does USA suck? | USA v6 | Unchanged |

Repeat with Mild/Strict, then disable the relevant pack: its contribution must
disappear. Other enabled systems and personal rules can independently act.
Gommage is separate: its curated terms cover regardless of stance when on.

For the reported overlap: set DEI & Institutional Programs to Mild and Communism
& Democratic Party to Strict. “I support DEI and communism” should redact.
Reverse their settings and the topic order; the result should still redact.
Check negation, reports, hyperlinks and separately stated criticism as controls.
Repeat with “I support DEI and communism at school” (Redacted) and
“We should require DEI and communism for everyone” (Hidden) under the same
DEI Mild / Political Strict settings. Unsupported modifiers stay conservative.

## Mentions

Keep Capture off and Mentions on. With a two-part name such as Rune Escape,
ask another player to send “Rune, ready?” and “Rune Escape, ready?” in a
monitored channel or whisper. Both should create one Mentions entry per message
without an @. “Escape”, “Runes” and “Runescape” should not match automatically.
The matched name should highlight, badges should update, and entries/read states
should survive reload. Sound/toast stay off by default. Hidden messages and
Shielded senders stay quiet. Turning off automatic name detection stops both
forms while leaving custom nicknames independent. The phrase tester only checks
wording policy; it does not simulate incoming mention delivery.

Temporarily enable spelling highlights and test Durotar, Orgrimmar, Teldrassil,
Thrall, Sylvanas, Rejuvenation, Moonfire, Innervate, Scholomance, proc, BiS,
Asmongold and Olympus. Valid terms should have no spelling marks or automatic
corrections. Genuine English typos should still offer corrections. Personal
dictionary additions and explicit spelling settings must survive reload.

Disabling Labels only removes its extra variants. The Barber & body-type wording
master switch also controls the built-in Body Type 1/2 replacements.

## Native client checks

1. Login, open each page through Olympus and `/ocw`, and repeat in combat.
   Check texture/mask errors, inaccessible controls and missing icons.
   Updates should show Patch Notes for 1.0.1. Switch to Launch Tour and back;
   first-run welcome should open the tour, while installed updates open notes.
   User Guide should keep the same three tabs. Check every topic, return to both
   other tabs, and confirm the patch header stays inside the border. Patch Notes
   should have only the GitHub link beneath its highlights.
2. Exercise trusted chat inputs in Say, Guild and Whisper. Check one record per
   filtered line, bronze expression covers, intact links and Ctrl + left-click
   reveal where supported. Ordinary chat stays out of Messages.
3. Read entries and Mark All Read. Hidden alerts default on, redaction alerts
   off, and warnings/replacements quiet. Badges should stay cleared after reload.
   Verify Mentions and Shield remain separate feeds.
4. Save a report, reload/relog, and inspect original text, timestamps, actions,
   evidence and read states. Restoration should produce no new alerts.
5. Update an old signed pack, including an old disabled pack. Confirm saved
   choices, no old Gommage while paused, and no repeated update advisory.
6. Check Shield separately. Roasts and preference matches must not count as
   strong abuse. Exact eligible severe abuse can count at configured whisper
   limits even when Mild only warns. Confirm gold ads, guild ads, repetitions and
   contact limits still behave as before.

Complex sarcasm, indirect paraphrases, nested quotations and distant pronoun
references may remain unclassified. Reports do not train the engine.

Do not publish final 1.0.1 until owner client testing is complete and compatible
signed pack downloads are available before or alongside the public addon.
