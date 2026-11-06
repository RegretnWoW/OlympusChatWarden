-- Elwynn-only building candidates plus existing Classic/Forever furniture.
local _,ns=...
local C={};ns.Fireside3D.Catalog=C
function C.Compatible(r)
 return type(r)=='table'and r.format=='M2'and(r.era=='CLASSIC'or r.era=='FOREVER_REFERENCE')
end
function C.IsCandidate(r)
 local elwynn={[106851]=true,[106965]=true,[106848]=true,[107232]=true}
 return type(r)=='table'and r.format=='WMO'and r.zone=='Elwynn Forest'
  and elwynn[r.fileID]and r.status=='ELWYNN_WMO_RENDER_UNVERIFIED'or false
end
function C.Load()
 if C.rows then return C.rows end
 local load=C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
 if type(load)~='function'then return nil,'Addon loading unavailable'end
 local ok,why=load('Fireside3DAssets');if not ok then return nil,why end
 local rows=rawget(_G,'Fireside3DAssetIndex')
 if type(rows)~='table'or #rows>512 then return nil,'Invalid candidate index'end
 local compatible={};for _,r in ipairs(rows)do if C.Compatible(r)or C.IsCandidate(r)then compatible[#compatible+1]=r end end
 C.rows=compatible;return compatible
end
function C.Label(r)
 if r.preferredTest then return r.label..' (small home test; unverified)'end
 if C.IsCandidate(r)then return r.label..' (Elwynn WMO; unverified)'end
 return r.label..(r.era=='CLASSIC'and' (Classic M2)'or' (existing Forever reference)')
end
function C.Merge(editor)
 local rows,why=C.Load();if not rows then return false,why end
 editor.ObjectCatalogue=editor.ObjectCatalogue or{};local seen={}
 for _,r in ipairs(editor.ObjectCatalogue)do seen[r[1]]=true end
 for _,r in ipairs(rows)do if not seen[r.fileID]then
  editor.ObjectCatalogue[#editor.ObjectCatalogue+1]={r.fileID,C.Label(r),r.height or 3,0,r.category,r.path};seen[r.fileID]=true
 end end
 return true
end
function C.Search(query,category)
 local rows,why=C.Load();if not rows then return nil,why end
 local out={};query=tostring(query or''):lower():sub(1,100)
 for _,r in ipairs(rows)do
  local text=(r.label..' '..r.category..' '..tostring(r.fileID or'')..' '..r.path..' '..(r.zone or'')..' '..(r.requestedLayout or'')):lower()
  if(not category or category=='all'or r.category==category)and(query==''or text:find(query,1,true))then out[#out+1]=r;if #out==100 then break end end
 end
 return out
end
function C.SpawnPreferred(v)
 local F=ns.Fireside3D;local editor=ns.WardenSceneEditor
 if not v or not F.EditorCamera or not F.EditorCamera.Active(v)or not editor.AddObject then return false,'Open the existing scene editor first'end
 if ns.MainStorageBlocked or(ns.UI2 and ns.UI2.locked)or(type(InCombatLockdown)=='function'and InCombatLockdown())then return false,'Scene editing is unavailable'end
 local target=F.preferredBuilding
 -- Existing editor guards, placement and native loader remain authoritative.
 -- Decoration collision permits interior inspection without a solid bounds box.
 return editor.AddObject(target.fileID,target.label,target.height,false,0)
end
function C.BindExistingEditor()
 local E=ns.WardenSceneEditor;if not E or E.fireside3DAssetBound or not E.AddObjectForm then return false end
 E.fireside3DAssetBound=true
 local form,filter=E.AddObjectForm,E.FilterObjects
 E.AddObjectForm=function(...)
  local ok,why=C.Merge(E);if not ok then ns.Print('Classic/Forever catalog: '..tostring(why));return false,why end
  return form(...)
 end
 E.FilterObjects=function(category,query)
  local result=filter and filter(category,query)or{};local seen={}
  for _,r in ipairs(result)do seen[r[1]]=true end
  local rows=C.Search(query,category=='all'and nil or category)or{}
  for _,r in ipairs(rows)do if r.fileID and not seen[r.fileID]then
   result[#result+1]={r.fileID,C.Label(r),r.height or 3,0,r.category,r.path};seen[r.fileID]=true
  end end
  return result
 end
 return true
end
