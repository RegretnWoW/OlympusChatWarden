-- Optional public research metadata; no private editor implementation is bundled.
local _,ns=...
local C={};ns.Fireside3D.Catalog=C
function C.Load()
 if C.rows then return C.rows end
 local load=C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
 if type(load)~='function'then return nil,'Addon loading unavailable'end
 local ok,why=load('Fireside3DAssets');if not ok then return nil,why end
 local rows=rawget(_G,'Fireside3DAssetIndex')
 if type(rows)~='table'or #rows>512 then return nil,'Invalid candidate index'end
 C.rows=rows;return rows
end
function C.Search(query,category)
 local rows,why=C.Load();if not rows then return nil,why end
 local out={};query=tostring(query or''):lower():sub(1,100)
 for _,r in ipairs(rows)do
  local text=(r.label..' '..r.category..' '..tostring(r.fileID or'')..' '..r.path):lower()
  if(not category or category=='all'or r.category==category)and(query==''or text:find(query,1,true))then out[#out+1]=r;if #out==100 then break end end
 end
 return out
end
function C.BindExistingEditor()
 local E=ns.WardenSceneEditor;if not E or E.fireside3DAssetBound or not E.AddObjectForm then return false end
 E.fireside3DAssetBound=true
 local form,filter=E.AddObjectForm,E.FilterObjects
 E.AddObjectForm=function(...)
  local rows,why=C.Load();if not rows then ns.Print('Candidate catalog: '..tostring(why));return false,why end
  return form(...)
 end
 E.FilterObjects=function(category,query)
  local result=filter(category,query);local seen={}
  for _,r in ipairs(result)do seen[r[1]]=true end
  local rows=C.Search(query,category=='all'and nil or category)or{}
  for _,r in ipairs(rows)do if r.fileID and not seen[r.fileID]then
   result[#result+1]={r.fileID,r.label..(r.status=='CANDIDATE_NOT_RENDER_TESTED'and' (candidate, not tested)'or' (prototype report)'),3,0,r.category,r.path};seen[r.fileID]=true
  end end
  return result
 end
 return true
end
