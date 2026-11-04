-- Player-facing recovery controls. Restores are validated in full before a
-- deliberate reload; no partial merge or automatic privacy/sharing opt-in.
local _,ns=...
local P,F=ns.FiresideSavedData,ns.UI2Forms
function P.OpenRecovery()
 local status=P.Report();local choices={}
 for n,copy in ipairs(status.copies)do choices[#choices+1]={tostring(copy.index),n==1 and'Latest available recovery copy'or'Recovery copy '..copy.index}end
 if #choices==0 then ns.Print('No automatic recovery copy is available yet. Copies are made when WoW saves after a successful load.');return false end
 return F.Form({title='Athena’s Safeguard · recovery',help='Restore settings and recorded history from this computer. This replaces the current Fireside save when the interface reloads. It does not contact other players or change WoW itself.',fields={{key='copy',label='Recovery copy',value=choices[1][1],choices=choices},{key='confirm',label='Type RESTORE to confirm',value='',limit=16}},submitLabel='Restore & reload',submit=function(values)
  if values.confirm~='RESTORE'then return false,'Type RESTORE to confirm'end
  local reload=type(ReloadUI)=='function'and ReloadUI or C_UI and C_UI.Reload
  if type(reload)~='function'then return false,'This client does not expose interface reload; no saved data changed'end
  if ns.Checked(ns.SafeCall(InCombatLockdown))then return false,'Restore after combat'end
  local ok,why=P.ScheduleRestore(tonumber(values.copy));if not ok then return false,why end
  reload();return true
 end,cancelLabel='Cancel'})
end
local rows=ns.UI2Settings.Rows
function ns.UI2Settings.Rows(category,...)
 local out=rows(category,...)
 if category=='data'then
  table.insert(out,1,{id='DATA.SAFEGUARD.ALWAYS',title='Athena’s Safeguard · data protection',detail=P.Report().protected and'Protected mode · originals retained; review recovery copies'or'Always active · failed reads preserve originals and block replacement',height=60,wrap=true})
  table.insert(out,2,F.Row('DATA.RECOVERY.AUTO','Automatic snapshots',P.Enabled,P.SetEnabled,{boolean=true,help='Keep local recovery checkpoints in a separate save file. Availability does not mean full application validation. Turning snapshots off never disables data-loss protection. Existing copies remain until cleared.'}))
  table.insert(out,3,F.Row('DATA.RECOVERY.FREQUENCY','Snapshot frequency',P.Frequency,P.SetFrequency,{choices={{0,'Every WoW save'},{3600,'At most hourly'},{86400,'At most daily'}},help='WoW writes addon saves on logout or reload. Hourly and daily choices limit how often those saves create a new snapshot.'}))
  table.insert(out,4,F.Row('DATA.RECOVERY.RETENTION','Snapshot retention',P.Retention,P.SetRetention,{choices={{2,'Last 2 copies'},{5,'Last 5 copies'},{10,'Last 10 copies'}},help='More copies use more memory and disk space. Retention applies at the next successful save. Damaged originals are quarantined rather than silently removed; capacity limits can refuse recovery.'}))
  local copies=P.Report().recoveryCopies
  table.insert(out,5,{id='DATA.RECOVERY.RESTORE',title='Restore a recovery copy',detail=copies..' local copies · validates before reload',height=43,activate=P.OpenRecovery})
  table.insert(out,6,{id='DATA.RECOVERY.CLEAR',title='Clear recovery copies',detail='Current settings and history remain',height=43,activate=function()F.Confirm('Clear automatic recovery copies?','Removes local recovery checkpoints. Current Fireside history and settings remain. With automatic snapshots enabled, a new copy is made at the next eligible WoW save.',function()P.PurgeRecovery(false);return true end)end})
 end
 return out
end
local slash=SlashCmdList and SlashCmdList.OLYMPUSCHATWARDEN
if slash then SlashCmdList.OLYMPUSCHATWARDEN=function(text)
 if type(text)=='string'and text:lower():match('^%s*recovery%s*$')then return P.OpenRecovery()end
 return slash(text)
end end
local report=ns.WardenRealm and ns.WardenRealm.Attach
if report then ns.WardenRealm.Attach=function(...)
 local v=report(...);if not v.recoveryReportBound then v.recoveryReportBound=true;local previous=v.Report
  v.Report=function(self,...)local out=previous(self,...);out.savedData=P.Report();return out end
 end;return v
end end
