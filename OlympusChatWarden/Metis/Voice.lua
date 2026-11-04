-- Compatibility surface for narration preferences; Metis owns composition.
local _,ns=...
local N={VERSION='metis-1.3.0',FAMILIES=17};ns.AthenaChronicler=N
N.Voice=ns.Metis.Voice;N.Lore=ns.Metis.Lore
function N.Family(s) return s.storyKind end
function N.Compose(s,length) return ns.Metis.Compose(s,length) end
function N.RenderThread(plan,length) return ns.Metis.Render(plan,length) end
ns.Metis.Register('Voice',N)
