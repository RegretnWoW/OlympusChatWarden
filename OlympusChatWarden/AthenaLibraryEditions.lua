-- Immutable private reading editions in the existing Journal SavedVariables.
-- Automatic reading caches remain disposable; explicitly saved books do not.
local _,ns=...
local E={VERSION=1,MAX_EDITIONS=32,MAX_BLOCKS=600,MAX_REFS=2048};ns.AthenaLibraryEditions=E
local R=ns.AthenaReadingSnapshots
local function plain(t) return type(t)=='table' and not getmetatable(t) end
local function text(s,n) return type(s)=='string' and #s<=n and not s:find('[%z\1-\8\11\12\14-\31]') end
local function copy(t) return ns.Athena.Copy(t) end
local function metadata(t,limit)
 if not plain(t) then return false end;local count=0
 for key,value in pairs(t) do count=count+1
  if count>limit or not text(key,48) or not (type(value)=='boolean' or type(value)=='number' and value==value and value>-1e12 and value<1e12 or text(value,512)) then return false end
 end
 return true
end
local function seal(blocks)
 local parts={};for _,b in ipairs(blocks) do parts[#parts+1]=(b.id or '')..'\030'..b.kind..'\030'..b.text end
 local wire=table.concat(parts,'\031');return ns.PackCrypto.Hex(ns.PackCrypto.SHA256(wire))
end
local function cleanBlocks(input)
 if not plain(input) or #input==0 or #input>E.MAX_BLOCKS then return nil,'This reading copy exceeds the book limit.' end
 local blocks,bytes={},0
 for _,b in ipairs(input) do
  if not plain(b) or not text(b.text or '',32768) or b.ownerPrivate and b.literal and not b.recollection then return nil,'Conceal revealed conversation excerpts before saving a reading copy.' end
  local kind=b.kind or 'body';if not ({body=true,title=true,heading=true,meta=true,quote=true})[kind] then return nil,'Unsupported manuscript paragraph.' end
  local row={id=text(b.id,4096) and b.id or nil,kind=kind,text=b.text or '',pageBreak=b.pageBreak==true or nil,spans={}}
  for _,span in ipairs(b.spans or {}) do local ref=span.ref
   if #row.spans<24 and plain(ref) and ref.type=='WIKI' and ns.AthenaLivingWiki.ValidKey(ref.key) and type(span.first)=='number' and type(span.last)=='number' and span.first>=1 and span.last<=#row.text and span.last>=span.first then row.spans[#row.spans+1]={first=span.first,last=span.last,ref={type='WIKI',key=ref.key}} end
  end
  bytes=bytes+#row.text+#(row.id or '')+96+#row.spans*192;if bytes>R.PAGE_BYTES then return nil,'This edition exceeds the existing 256 KiB reading-copy limit.' end
  blocks[#blocks+1]=row
 end
 return blocks,bytes
end
E.CleanBlocks=cleanBlocks
function E.Validate(root)
 if root==nil then return true,0 end
 if not plain(root) or root.version~=E.VERSION or not plain(root.byID) then return false end
 local count,bytes=0,0
 for id,row in pairs(root.byID) do
  count=count+1
  if count>E.MAX_EDITIONS or not text(id,512) or not plain(row) or row.id~=id or not text(row.owner,256) or not text(row.title,160) or not text(row.note or '',2000) or not text(row.token,512) or type(row.savedAt)~='number' or not metadata(row.window,12) or not metadata(row.versions,16) or not plain(row.refs) or #row.refs>E.MAX_REFS then return false end
  local blocks,b=cleanBlocks(row.blocks);if not blocks or seal(blocks)~=row.seal or row.bytes~=b then return false end
  for _,ref in ipairs(row.refs) do if not text(ref,1024) then return false end end
  bytes=bytes+b+#row.title+#(row.note or '')+#row.refs*1024+512
 end
 return bytes<=R.MAX_BYTES,bytes
end
function E.ReservedBytes()
 local root=ns.Storage.OlympusWardenJournalDB;local ok,bytes=E.Validate(root and root.editions)
 if not ok then return nil,'Saved editions need recovery; originals were retained.' end
 return bytes
end
local function permitted(provider,owner)
 return provider and provider:Allowed() and type(owner)=='string' and (provider.demo or owner==ns.Chronicle.Owner() or ns.ChronicleStore.Character(owner,false)~=nil)
end
local function root(provider,owner,create)
 if not permitted(provider,owner) then return nil,'This private character library is unavailable.' end
 local r
 if provider.demo then
  if create and not provider.JournalStore then provider.JournalStore={version=1,pages={},clock=0} end;r=provider.JournalStore
 else
  if create and ns.Storage.OlympusWardenJournalDB==nil then ns.Storage.OlympusWardenJournalDB={version=1,pages={},clock=0} end;r=ns.Storage.OlympusWardenJournalDB
 end
 if r==nil then return nil,'No saved editions yet.' end
 if not plain(r) or r.version~=1 or not plain(r.pages) or type(r.clock)~='number' or not E.Validate(r.editions) then return nil,'Saved editions need recovery; originals were retained.' end
 if create and r.editions==nil then r.editions={version=1,byID={}} end
 return r
end
function E.NewToken(provider,owner)
 local r,why=root(provider,owner,true);if not r then return nil,why end
 r.clock=r.clock+1;return 'edition/'..owner..'/'..r.clock
end
function E.List(provider,owner)
 local r,why=root(provider,owner,false);local out={}
 for _,row in pairs(r and r.editions and r.editions.byID or {}) do if row.owner==owner then out[#out+1]={id=row.id,title=row.title,savedAt=row.savedAt,window=copy(row.window)} end end
 table.sort(out,function(a,b) return a.savedAt==b.savedAt and a.id>b.id or a.savedAt>b.savedAt end)
 return out,why
end
function E.Get(provider,owner,id)
 local r,why=root(provider,owner,false);local row=r and r.editions and r.editions.byID[id]
 return row and row.owner==owner and copy(row) or nil,why
end
function E.Save(provider,owner,draft)
 local r,why=root(provider,owner,true);if not r then return nil,why end
 if not plain(draft) or not text(draft.token,512) or not text(draft.title,160) or not draft.title:find('%S') or not text(draft.note or '',2000) or not metadata(draft.window,12) or not metadata(draft.versions,16) then return nil,'Write a title (160 bytes maximum) and an optional private note (2,000 bytes).' end
 for _,row in pairs(r.editions.byID) do if row.owner==owner and row.token==draft.token then return row.id,'This save was already accepted; no duplicate was created.' end end
 local blocks,bytes=cleanBlocks(draft.blocks);if not blocks then return nil,bytes end
 local refs,seen={},{}
 for _,ref in ipairs(draft.refs or {}) do if text(ref,1024) and not seen[ref] then seen[ref]=true;refs[#refs+1]=ref end end
 if #refs>E.MAX_REFS then return nil,'The source-reference limit was reached. Nothing was saved.' end
 local id=draft.token;local candidate=copy(r.editions)
 candidate.byID[id]={id=id,token=draft.token,owner=owner,title=draft.title,note=draft.note or '',savedAt=ns.SafeCall(time) or 0,window=copy(draft.window),versions=copy(draft.versions),refs=refs,blocks=blocks,seal=seal(blocks),bytes=bytes,privacy='OWNER_PRIVATE',immutableText=true}
 local valid,reserved=E.Validate(candidate);if not valid then return nil,'The private library is full or this edition is invalid. Existing books were retained.' end
 -- Evict only disposable automatic caches. Never silently evict saved editions.
 local pages=copy(r.pages);local total=reserved
 for _,row in pairs(pages) do if not plain(row) or type(row.bytes)~='number' then return nil,'Reading caches need recovery; no books were changed.' end;total=total+row.bytes end
 while total>R.MAX_BYTES do local oldest,used
  for key,row in pairs(pages) do if not used or (row.used or 0)<used then oldest=key;used=row.used or 0 end end
  if not oldest then return nil,'The private library is full.' end;total=total-pages[oldest].bytes;pages[oldest]=nil
 end
 r.pages=pages;r.editions=candidate
 return id,provider.demo and 'Saved in this isolated simulator library only.' or 'Private edition accepted. WoW writes it to SavedVariables on a normal reload/logout; a crash before then can lose this save.'
end
function E.Edit(provider,owner,id,title,note)
 local r,why=root(provider,owner,false);local row=r and r.editions and r.editions.byID[id]
 if not row or row.owner~=owner then return false,why or 'This edition is unavailable.' end
 if not text(title,160) or not title:find('%S') or not text(note or '',2000) then return false,'Use a title within 160 bytes and note within 2,000 bytes.' end
 local candidate=copy(r.editions);candidate.byID[id].title=title;candidate.byID[id].note=note or ''
 local valid,total=E.Validate(candidate)
 if not valid then return false,'The library limit was reached; existing edition retained.' end
 for _,cached in pairs(r.pages) do
  if not plain(cached) or type(cached.bytes)~='number' then return false,'Reading caches need recovery; existing edition retained.' end
  total=total+cached.bytes
 end
 if total>R.MAX_BYTES then return false,'The library limit was reached; existing edition retained.' end
 r.editions=candidate;return true,'Title and user-authored note changed. The saved manuscript is unchanged.'
end
function E.Delete(provider,owner,id,confirmed)
 if confirmed~=true then return false,'Deliberate deletion confirmation required.' end
 local r,why=root(provider,owner,false);local row=r and r.editions and r.editions.byID[id]
 if not row or row.owner~=owner then return false,why or 'This edition is unavailable.' end
 r.editions.byID[id]=nil;return true
end
