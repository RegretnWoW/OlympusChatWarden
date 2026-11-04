-- Shared references to the same installed Forever catalogue used by the Lab.
-- No Blizzard assets are extracted or distributed.
local _,ns=...;local C=ns.WardenRoomCatalogue
local rows={
 {'elwynn-fir',189923,'Elwynn fir tree',4.8,.3},{'elwynn-pine',189924,'Elwynn pine',3.5,.25},{'elwynn-bush',189692,'Elwynn bush',.55,0},{'elwynn-stump',189939,'Elwynn stump',.65,.4},
 {'bunk-bed',198001,'Bunk bed',1.7,0},{'human-bed',198002,'Human bed',1.2,0},{'stormwind-crate',198168,'Stormwind crate',.8,0},{'inn-table',198603,'Inn table',.9,0},{'small-inn-table',198604,'Small inn table',.8,0},
 {'human-chair',198114,'Human chair',1.55,0,'chair'},{'writing-desk',198175,'Writing desk',.95,0},{'empty-bookshelf',242995,'Empty bookshelf',2.3,0},{'bookshelf',198047,'Bookshelf',2.3,0},
 {'street-lamp',198316,'Stormwind street lamp',3.5,.15},{'candle',198076,'Candle',.38,0},{'flag-pole',198199,'Flag pole',3.2,.15},{'animated-book',200912,'Animated brown book',.2,0},
 {'campfire',189705,'Elwynn campfire',1.5,0,'fire'},
}
for _,r in ipairs(rows)do assert(C.RegisterItem(r[1],{fileID=r[2],label=r[3],height=r[4],collisionRadius=r[5],interaction=r[6],catalogue=true}))end
