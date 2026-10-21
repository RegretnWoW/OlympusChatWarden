# Alpha4 local matching measurements

Three trials of 1,200 unique synthetic messages per mode in Lua 5.1, with indexes prepared. Measured `ns.Find` plus contextual ad/recruitment checks; excludes recording, rendering and native WoW runtime cost.

| Mode | Median ms/message |
| --- | ---: |
| Off | 0.206 |
| Balanced | 0.379 |
| Aggressive | 0.382 |

2,021 sampled dictionary-word/nonword pairs passed. The full typing-suggestion index was not loaded for these lookups. Text/token/candidate/state/index/cache bounds remain in place. This is a local comparison, not an FPS prediction; confirm performance in game.

# Alpha6 history measurement

A local Lua 5.1 snapshot of a full 300-row activity stream averaged 3.342 ms over 20 flushes. History writes are debounced for two seconds and flushed synchronously at logout; restoration does not run the matcher or replay notifications. Stored records are bounded per character and across the account. This is a synthetic local timing, not a live WoW frame-time measurement. The incoming typo engine is unchanged in this pass.
