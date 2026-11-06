-- Proven retired scenery and exact-byte tile sharing. No artwork encoding,
-- dimensions, masks, layer order, scene layout or saved data changes.
-- Dependency and SHA256 equivalence receipts accompany the release candidate.
local _,ns=...
local W=ns.WardenWorldArt
for _,id in ipairs({"cloud-far42@dawn","cloud-far42@day","cloud-far42@dusk","cloud-far42@night","cloud-near42@dawn","cloud-near42@day","cloud-near42@dusk","cloud-near42@night","fields-city49@dawn","fields-city49@day","fields-city49@dusk","fields-city49@night","flagpost","ground42@dawn","ground42@day","ground42@dusk","ground42@night","ground49@dawn","ground49@day","ground49@dusk","ground49@night","hall-ground@dawn","hall-ground@day","hall-ground@dusk","hall-ground@night","hall-tree@dawn","hall-tree@day","hall-tree@dusk","hall-tree@night","home-city49@dawn","home-city49@day","home-city49@dusk","home-city49@night","home-shell49@dawn","home-shell49@day","home-shell49@dusk","home-shell49@night","sky42@dawn","sky42@day","sky42@dusk","sky42@night","study-shell@dawn","study-shell@day","study-shell@dusk","study-shell@night","terrain49@dawn","terrain49@day","terrain49@dusk","terrain49@night"})do W.assets[id]=nil end
local aliases={
 ["Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-day-1-0.tga"]="Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dawn-1-0.tga",
 ["Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dusk-1-0.tga"]="Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dawn-1-0.tga",
 ["Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-night-1-0.tga"]="Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dawn-1-0.tga",
 ["Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-river-dawn-1-0.tga"]="Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dawn-1-0.tga",
 ["Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-river-day-1-0.tga"]="Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dawn-1-0.tga",
 ["Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-river-dusk-1-0.tga"]="Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dawn-1-0.tga",
 ["Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-river-night-1-0.tga"]="Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dawn-1-0.tga",
 ["Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\home51-backing-dawn-1-0.tga"]="Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dawn-1-0.tga",
 ["Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\home51-backing-day-1-0.tga"]="Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dawn-1-0.tga",
 ["Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\home51-backing-dusk-1-0.tga"]="Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dawn-1-0.tga",
 ["Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\home51-backing-night-1-0.tga"]="Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dawn-1-0.tga",
 ["Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\home51-bridge-quays-dawn-1-0.tga"]="Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dawn-1-0.tga",
 ["Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\home51-bridge-quays-day-1-0.tga"]="Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dawn-1-0.tga",
 ["Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\home51-bridge-quays-dusk-1-0.tga"]="Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dawn-1-0.tga",
 ["Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\home51-bridge-quays-night-1-0.tga"]="Interface\\AddOns\\OlympusChatWarden\\Media\\World52\\a2-bank-bridge-dawn-1-0.tga",
}
for _,asset in pairs(W.assets)do
 for _,tile in ipairs(asset.tiles or{asset})do if aliases[tile.path]then tile.path=aliases[tile.path]end end
end
