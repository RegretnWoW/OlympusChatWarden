# Olympus ChatWarden 1.0.2 — release

- Zeus artwork meets the full panel's bottom-left trim. Compact activity icons are centered, with less space around the toggles. Clicking a compact entry marks it read.
- Olympus 1.2.4 gets a compact ChatWarden page with quick controls and more scrolling recent activity. Right-click its tab for the full UI.
- Updates keeps older release notes. Use Previous update and Next update to browse 1.0.1 and 1.0.0.
- Mentions is now Alerts. Personal mentions and Wanted encounters have separate views and settings, and both remain in Overview.
- Exact full Wanted names in visible chat get an icon with current bounty details on hover. Chat mentions never create Wanted notifications; your own visible chat works for testing.
- Guild rank appears beside Zeus without the extra role label. The Title row appears only when Olympus supplies a selected title. Connection status stays in the top bar.
- With Olympus 1.2.4, grant access in `/oly privacy` so Olympus can confirm membership. Older Olympus versions keep the guild-name fallback.

Filtering rules and signed packs are unchanged. Keep your SavedVariables when replacing the addon folder. Sound and toast start off. See RELEASE-CHECKS.md for the remaining live checks.

---

# Olympus ChatWarden 1.0.1

## Filtering and packs

- Context-aware stock protection separates the covered subject, wording severity
  and chosen action. Mild, Balanced and Strict share the same covered scope.
- Optional signed topic packs distinguish recognized support/promotion from
  questions, neutral discussion, criticism and uncertain interpretations.
- Clear requests and endorsements are recognized more consistently, including
  “Please vote,” “We should all” and “I endorse” when an enabled pack covers the topic.
- Joined authored topics keep independent pack sensitivities, including bounded
  qualifiers such as “at school” and “for everyone.” Immediately attached rejection
  of the same terminology handles ordinary punctuation, including “, personally.”
- Gommage remains a separate literal meme option, off by default. Preference
  matches and masks do not count as strong harassment evidence for Shield.
- The pack download has an **Import These Packs** folder with readable filenames
  matching the current signed titles. Settings labels and tooltips follow verified
  titles. Stable category IDs and signatures are preserved.

## Mentions and spelling

- Your first name or full character name triggers Mentions without an @. A surname
  alone and name fragments do not match automatically. Capture can remain off.
- One message creates one mention entry, with persistent read state and support
  for all 100 custom watches plus the two automatic name forms.
- The offline spelling dictionary includes 1,078 curated WoW/Olympus terms.
  Ambiguous corrections remain manual suggestions. Typing assistance is opt-in.

## Updates

- Patch Notes shows the installed version and short highlights, with full notes
  on GitHub. The Launch Tour is available in its own separate tab.
- User Guide shares those tabs and uses shorter, simpler instructions. Patch
  Notes has a clearer header and one link for the full notes.

## Updating

Exit WoW and replace the OlympusChatWarden folder. Keep WTF/SavedVariables.
The addon includes Olympus Protection and King Protection; other packs are
separate, optional signed imports.

Updating the addon does not update saved imported packs. Import the wanted v11
terminology files to get the new titles using Packs > Import signed pack >
Verify pack > Install pack. Existing enablement and sensitivity are preserved.
Older incompatible policy packs pause, including Gommage, until updated. Labels
v7 stays compatible. Current v11 terminology packs, USA v6 and Labels v7 are
unchanged from Preview3–5; those imports do not need replacing.

Filtering, Shield, Mentions and Spam start on. Balanced is the default. Gommage,
Capture, language filtering, spelling highlights and autocorrection start off.
Existing explicit saved choices are retained. Sound/toast for Mentions start off.

Classification uses bounded local rules; difficult or uncertain language can stay
unclassified. Reports preserve evidence and do not automatically train the engine.
