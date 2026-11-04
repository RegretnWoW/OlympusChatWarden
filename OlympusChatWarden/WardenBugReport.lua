-- Offline-first support facade over the existing bounded Relay draft store.
-- Saving/exporting never submits, changes consent, queries dossiers or copies logs.
local _,ns=...
local B={MAX_TEXT=7600};ns.WardenBugReport=B
local S=ns.RelayStore
local function text(v,max,required)
 if type(v)~='string'or not ns.CanRead(v)or #v>max or v:find('[%z\1-\8\11\12\14-\31]')or required and not v:find('%S')then return end
 return v
end
function B.Client()
 local version,build,_,interface
 if type(GetBuildInfo)=='function'then local ok,a,b,c,d=pcall(GetBuildInfo);if ok then version,build,interface=a,b,d end end
 local function safe(v)if ns.SafeNumber(v)then return tostring(v)end;return text(v,80)or'unknown'end
 return 'Flavor: '..safe(ns.ClientBuild and ns.ClientBuild.target)..'\nClient version: '..safe(version)..'\nClient build: '..safe(build)..'\nInterface: '..safe(interface)
end
function B.Create(v)
 if type(v)~='table'or getmetatable(v)then return nil,'Invalid report fields'end
 local keys={title=true,happened=true,expected=true,steps=true,notes=true,severity=true,module=true,diagnostics=true}
 for k in pairs(v)do if not keys[k]then return nil,'Unsupported report field'end end
 if v.diagnostics~=nil and type(v.diagnostics)~='boolean'then return nil,'Choose whether to include technical details'end
 local title=text(v.title,96,true);local happened=text(v.happened,1300,true);local expected=text(v.expected,850,true);local steps=text(v.steps or'',1600);local notes=text(v.notes or'',350)
 local severity=({P0=true,P1=true,P2=true,unsure=true})[v.severity]and v.severity
 local module=false;for _,r in ipairs(S.modules)do if r[1]==v.module then module=true;break end end
 if not(title and happened and expected and steps and notes and severity and module)then return nil,'Enter what happened, what you expected and a valid module/severity within the limits'end
 local description='What happened?\n'..happened..'\n\nWhat did you expect?\n'..expected..'\n\nSeverity (reporter): '..severity..'\nNotes: '..notes..'\n\n'..B.Client()
 if #description>3000 then return nil,'The combined report is too long'end
 S.Initialize();if not S.db then return nil,S.blocked or'Local support storage unavailable; saved originals are preserved'end
 local fields={module=v.module,category='bug',title=title,description=description,steps=steps}
 -- Repeated save clicks reuse identical local drafts; never suppress a receipt.
 local r;for _,old in ipairs(S.db.reports)do if old.state=='draft'and old.fields then local same=true;for k,val in pairs(fields)do if old.fields[k]~=val then same=false;break end end;if same then r=old;break end end end
 if not r then local why;r,why=S.New();if not r then return nil,why end;local ok;ok,why=S.Save(r.id,fields);if not ok then return nil,why end end
 local diagnostics=v.diagnostics==true and ns.RelayDiagnostics.Prepare()or''
 -- Store only the same aggregate allowlist used by Relay, never free-form errors.
 r.supportDiagnostics=diagnostics;r.supportLocalOnly=true
 local payload=S.Payload(r,diagnostics);local wire,why=S.Encode(payload);if not wire then return nil,why end
 local body='Fireside — LOCAL BUG REPORT (not submitted)\nReport ID: '..r.id..'\nBuild: '..ns.VERSION..'\nCreated: '..tostring(r.created)..'\nModule: '..fields.module..'\nTitle: '..title..'\n\n'..description..'\n\nSteps to reproduce:\n'..(steps~=''and steps or'Not supplied')..'\n\nOptional technical details:\n'..(diagnostics~=''and diagnostics or'Not included')..'\n\nScreenshots: attach manually. Review/redact before sharing. This action sent nothing.'
 if #body>B.MAX_TEXT then return nil,'Report exceeds the bounded export size'end
 S.Changed();return r,body
end
function B.Open()
 local F=ns.UI2Forms
 return F.Form({privacy=true,draftKey='release-support',title='Report a Bug · save and preview',help='Works offline. Saving sends nothing.\nOptional technical details are aggregate status, never private history.\nReview and redact the local copy before sharing it with support.',fields={
  {key='module',label='Affected module',value='suite',choices=S.modules},
  {key='severity',label='Severity (your estimate)',value='unsure',choices={{'unsure','Not sure'},{'P0','P0 · crash, data loss or privacy risk'},{'P1','P1 · significant broken behavior'},{'P2','P2 · cosmetic or minor'}}},
  {key='title',label='Short title',limit=96},
  {key='happened',label='What happened?',multiline=true,height=90,limit=1300},
  {key='expected',label='What did you expect?',multiline=true,height=70,limit=850},
  {key='steps',label='Steps to reproduce',multiline=true,height=85,limit=1600},
  {key='notes',label='Optional notes (avoid identifying/private information)',limit=350},
  {key='diagnostics',label='Optional technical details',value=false,choices={{false,'Omit technical details'},{true,'Include previewable aggregate diagnostics'}}}},submitLabel='Save & preview locally',submit=function(v,form)
   local r,body=B.Create(v);if not r then return false,body end
   form.completed=true;form:Hide();F.drafts['release-support']=nil
   -- Use an editable export, not F.Copy's readOnly selection control.
   F.Form({privacy=true,title='Review / redact local report '..r.id,help='Edit or remove any details here, then Ctrl+A / Ctrl+C and paste into a local .txt file or approved support destination. No submission or upload has occurred.',fields={{key='report',label='Editable local report',value=body,limit=B.MAX_TEXT,multiline=true,height=380,code=true}},cancelLabel='Done'})
   return false,'Report saved locally; preview opened'
  end})
end
