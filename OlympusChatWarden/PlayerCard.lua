-- One identity for local dossiers, self presentation and reviewed sharing.
-- Gamerzone is an optional declaration, never an inference or moderation rule.
local _,ns=...
local G={VERSION=1,LIMIT=16};ns.PlayerCard=G
G.order={'recreation','pro','family','underground'}
G.zones={recreation={title='Recreation',description='Relaxed adventures, consideration and playing for fun.'},
 pro={title='Pro',description='Competitive goals, fair play and respect for opponents.'},
 family={title='Family',description='A welcoming atmosphere and considerate language.'},
 underground={title='Underground',description='Intense competition and irreverent banter.'}}
function G.Valid(zone) return type(zone)=='string' and G.zones[zone]~=nil end
function G.Own() return (ns.Chronicle.Owner() or ''):match('/(Player%-.+)$') end
function G.Local(guid)
 if guid~=G.Own() then return end
 local rows=ns.DB and ns.DB.playerCardDeclarations;local row=type(rows)=='table' and rows[guid]
 if type(row)~='table' or row.gamerzone~=nil and not G.Valid(row.gamerzone) or not ns.Athena2.Number(row.revision,1,1000000000) then return end
 return {gamerzone=row.gamerzone,about=ns.AetherNet.Text(row.about or '',500) and row.about or '',revision=row.revision,declaredBy=guid,unpublished=true}
end
function G.Public() return nil,'UNPUBLISHED_DRAFT_ONLY' end
function G.Select(zone)
 if not ns.DB or not ns.Membership.Allowed() or zone~=nil and not G.Valid(zone) then return false,'Choose one of the four Gamerzones or leave it unset.' end
 local guid=G.Own();if not guid then return false,'Current character identity is unavailable.' end
 local rows=ns.DB.playerCardDeclarations
 if rows~=nil and (type(rows)~='table' or getmetatable(rows)) then return false,'Profile preferences are unavailable; existing data kept.' end
 rows=rows or {};local old=rows[guid]
 if not old and ns.Athena2.Count(rows)>=G.LIMIT then return false,'Profile preference capacity reached.' end
 local revision=0
 if old~=nil then revision=type(old)=='table' and ns.Athena2.Number(old.revision,0,999999999) or nil end
 if not revision then return false,'Profile revision unavailable; existing data kept.' end
 -- Keep an unset declaration revision locally. Remote copies are not silently
 -- revoked; a reviewed new publication is required and old claims expire.
 rows[guid]={gamerzone=zone,about=type(old)=='table' and old.about or '',revision=revision+1,unpublished=true};ns.DB.playerCardDeclarations=rows
 if ns.UI2Models then ns.UI2Models.Clear() end
 return true
end
function G.FromClaims() return nil,'LEGACY_PUBLIC_RETIRED' end
function G.SaveDraft(guid,about,zone)
 if guid~=G.Own() or not ns.AetherNet.Text(about,500) or zone~=nil and not G.Valid(zone) then return false,'Use your exact character and plain owner-authored text.' end
 local ok,why=G.Select(zone);if not ok then return false,why end
 ns.DB.playerCardDeclarations[guid].about=about;return true,'Not published. No network action was taken.'
end
function G.Voting(guid)
 local N=ns.AetherNet
 return N and N.Voting and N.Voting(guid) or {enabled=false,reason='Aether Net is OFF. Live service is blocked.'}
end
function G.Vote(guid,stars) return ns.AetherNet.Vote('CHARACTER',guid,stars) end
