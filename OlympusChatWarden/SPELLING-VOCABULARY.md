# Offline spelling vocabulary

The existing 90,987-entry English spelling data is unchanged. It is supplemented
by 1,078 unique curated tokens: 1,068 WoW/game-chat terms and 10 established
Olympus/project names. This is a curated foundation, not every NPC or spell.
Multiword names are recognized through their component tokens.

SpellingVocabulary.lua groups locations/cities, lore, classes/professions,
abilities/resources, instances/battlegrounds and gameplay/chat shorthand.
Examples include Durotar, Ashenvale, Stranglethorn, Orgrimmar, Teldrassil,
Thrall, Arthas, Sylvanas, Jaina, Illidan, Rejuvenation, Moonfire, Innervate,
Shadowmeld, Deadmines, Scholomance, aggro, respec, proc, transmog and parse.
Mixed-case and digit abbreviations such as BiS, HoT, AoE and LF1M stay recognized.

The separate community set is restricted to established names already present
in this project: Olympus, Asmongold, Asmon, Zackrawrr, AsmonTV, Asmonfresh,
Asmongler, ChatWarden, OlympusChatWarden and OlympusMute.
No arbitrary guild-member names, political vocabulary or inferred memes were added.

Your existing personal dictionary remains the user-controlled layer (512 words).
Add/remove words in Settings > Spelling. Saved words and explicit feature choices
survive reloads. Ignored words remain session-only. Typing highlights and automatic
correction still start off; Balanced incoming typo matching remains separate.

Known spellings avoid typing marks and automatic changes. They also prevent
Balanced incoming typo matching from guessing that a legitimate game term is a
different filter word. Aggressive prototype matching retains its existing rules.
Exact signed/personal rules and evasion matches are not exempted by this dictionary.
The vocabulary adds no filtering targets or confidence scores, and does not modify
signed packs, message text, reports or player identities.

The English suggestion index remains lazy and batched. The small supplement is
available offline before that index loads, and participates in bounded manual
suggestions. Original English attribution is retained in SPELLING-LICENSE.txt.
