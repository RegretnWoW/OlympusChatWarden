# Contextual filtering in 1.0.0

Balanced represents the author's personal desired response to a message. Higher filtering strength means a stronger eligible unwanted expression, not an objective judgment of an ideology or a person.

The engine separates topic relevance, speaker stance, expression strength and interpretation evidence. Recognizing a term alone is insufficient. Context handling keeps neutral references, genuine questions, clear opposite stances and merely quoted/reported wording visible in every preset.

| Eligible expression | Mild | Balanced | Broad |
| --- | --- | --- | --- |
| Mild unwanted support or directed criticism | Visible | Warning | Hidden |
| Strong promotion or directed attack | Warning | Redacted | Hidden |
| Recognized explicit threat | Hidden | Hidden | Hidden |
| Neutral/question/opposite/unsupported stance | Visible | Visible | Visible |

Olympus, King and USA Protection protect their subjects: praise stays visible and recognized attacks can filter. The DEI-related terminology packs, including Social Terminology, take the author's selected direction: supportive statements can filter and criticism stays visible. Political Slogans uses the selected signed viewpoints and assertive slogans. Body-label replacements remain explicit substitutions.

Examples in Balanced, with the relevant pack enabled and Gommage off:

- USA is great -> visible.
- USA is bad -> warning.
- America is dumb -> warning.
- If USA is so bad why does half the world want to live there? -> visible.
- USA SUCKS! -> redact the matched wording.
- Why does USA suck? -> visible.
- DEI is useful -> warning.
- We should adopt DEI hiring policies -> redact the matched wording.
- DEI is stupid -> visible.
- What does DEI mean? -> visible.
- The article discusses inclusive language -> visible.
- Safe spaces are useful -> warning; Safe spaces are stupid -> visible.

Broader vocabulary coverage does not bypass context. Each bounded clause is interpreted separately; a question in one clause does not exempt an attack in another. A question mark alone is not an exemption. The engine is deterministic and bounded, so unclear sarcasm, unfamiliar grammar and missed concepts still need reports. It is not a general language model or a guarantee of recognizing every threat.

Gommage is the deliberately exaggerated meme option. All 215 original masks remain intact. When enabled, those terms can be covered even in neutral discussion, questions or criticism, in any preset. Its per-pack selections and exceptions still apply. Assess practical context matching with Gommage off.

Incoming spelling/evasion checks recognize eligible references and context words without rewriting originals. Spelling-assisted interpretations are distinguished from exact context evidence. Context handling is always active. The legacy switch and opt-out are retired; presets control action intensity.

Topic preferences, Gommage and replacements cannot automatically Shield someone. Eligible repeated strong directed attacks and recognized threats retain the existing configured whisper protection; request/repetition/spam checks remain separate.

Messages is the filtering feed across channels, including whispers. Warnings/replacements remain quiet; badges count eligible unread redactions and hides. Mentions and Shield retain their own feeds. Why filtered? and saved reports retain stance, strength, certainty, policy version and the actual historical action. Old records restore without re-analysis or repeated alerts.

## Updating the packs

Install 1.0.0 first, then verify/import the current optional pack versions listed below. USA Protection v5 is updated from alpha12. The other seven optional pack versions are unchanged; older pre-alpha12 imports may still require the schema-4 updates. Installing the addon alone does not update saved imports. Old schema-1/2/3 packs still verify under their original model until explicitly updated. Normal updates preserve enablement and per-pack presets.

Only Olympus Protection v9 and King Protection v8 are included. Optional vocabulary remains in the author-signed models; the trusted key and signature verification protocol are unchanged. No signing kit or private key is distributed.

| Pack | Version | Phrase/topic entries | Statements | Gommage masks | Replacements |
| --- | ---: | ---: | ---: | ---: | ---: |
| Gender & pronouns | 9 | 417 | 0 | 169 | 0 |
| Body-label replacements | 7 | 0 | 0 | 0 | 46 |
| Pregnancy & parenting terminology | 9 | 131 | 0 | 0 | 0 |
| Inclusive language terminology | 9 | 91 | 0 | 0 | 0 |
| Workplace & institutional terminology | 9 | 492 | 0 | 20 | 0 |
| Political slogans | 9 | 86 | 0 | 9 | 0 |
| Social terminology | 9 | 138 | 0 | 0 | 0 |
| USA Protection | 5 | 82 | 177 | 17 | 0 |

## Launch defaults

Filtering, Shield, Mentions and Spam protection start on. Balanced is the main filtering preset and contact profile. Gommage and Chat Capture start off.

Player chat, chat bubbles, barber/body-type wording, review history, OlympusMute signal tooltips and Balanced incoming typo matching start on. NPC chat, dialogue, vendor labels, talking-head captions, name/nameplate/unit-frame filtering, tooltips, language filtering and typing assistance start off.

Mention detection watches the full character name and all supported channels, with close typo matching for custom watch phrases on. Names/nicknames remain exact. Sound and toast start off with a 10-second cooldown. Capture includes whispers and guild/officer chat when recording is enabled.

Hidden-message alerts start on; redaction alerts start off. Word filtering and contact protection notifications start on. Language-only, spam and advertising notifications start quiet. These switches change alerts, not filtering or saved originals.

Existing explicit feature choices, captures, watch phrases, dictionaries, imports and history are preserved. The retired context opt-out is the exception: context handling is always active.
