# ChatWarden project rules

- Optional category vocabulary belongs in author-signed rule packs. Edit the
  readable pack models, increment the pack version, sign with the existing
  author key, and validate the normal import/update flow.
- Do not add client-side vocabulary overrides, post-verification substitutions,
  or signature bypasses to achieve a pack-content change. If signing is blocked,
  report the blocker and prepare the pack source changes.
- Olympus Protection and King Protection remain the two stock categories under
  the existing design; other categories are optional signed imports.
- Keep signing kits and private keys out of Git and all distributable archives.
