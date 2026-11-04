-- Consent-gated listener. Delayed exact matching consumes real Warden/Shield
-- display outcomes; missing native line IDs never justify a name-only match.
local _,ns=...
local C=ns.AthenaConversations;local frame=CreateFrame('Frame');local pending=0;local registered=false
local function text(v,n)return ns.SafeString(v,n or 8192)end
function C.DisplayState(input)
 local entry=ns.ChatReports.FindDisplay(input)
 local s=entry and entry.captureSnapshot
 if s and s.actionRecorded then return s.actualAction,entry end
 if not ns.Modules.Enabled('chat')and not ns.Modules.Enabled('shield')then return 'FILTER_MODULE_DISABLED'end
 return 'UNKNOWN'
end
function C.OnDisplayOutcome(entry)
 if entry and entry.captureSnapshot then C.DisplayChanged(entry.captureID,entry.captureSnapshot.actualAction)end
end
function C.RefreshCapture()
 local status=C.Status();local enabled=status.state=='RECORDING';local bits={tostring(enabled)};for _,key in ipairs({'partyRaid','guild','sayEmote','publicChannels','whispers','officer','instance','npcDialogue'})do bits[#bits+1]=tostring(status.policy.scopes[key]==true)end;local signature=table.concat(bits,'/')
 if signature~=registered then
  frame:UnregisterAllEvents();registered=signature
  if enabled then
   for _,event in ipairs(ns.ChatReports.Events)do if status.policy.scopes[C.EventScope(event)]then pcall(frame.RegisterEvent,frame,event)end end
   if status.policy.scopes.npcDialogue then for _,event in ipairs(ns.ChatReports.NPCEvents)do pcall(frame.RegisterEvent,frame,event)end end
  end
 end
end
local oldConsent=C.SetConsent
C.SetConsent=function(...)local a,b=oldConsent(...);C.RefreshCapture();if ns.AthenaTextSources then ns.AthenaTextSources.Refresh()end;if ns.AthenaJournalWindow then ns.AthenaJournalWindow.Invalidate()end;return a,b end
frame:SetScript('OnEvent',function(_,event,message,sender,...)
 local status=C.Status();if status.state~='RECORDING'or not status.policy.scopes[C.EventScope(event)]then return end
 message=text(message);if not message or not text(sender,128)then return end
 if pending>=32 then C.Store().warnings.native='DELIVERY_BACKLOG; NEW_LINE_NOT_STAGED';return end
 local context=ns.Chronicle.ConversationContext();local lineID=ns.SafeNumber(select(9,...));if lineID and lineID<=0 then lineID=nil end
 local input={event=event,text=message,observedAt=ns.SafeNumber(ns.SafeCall(GetServerTime))or ns.SafeNumber(ns.SafeCall(time)),sender=text(sender,128),senderGUID=text(select(10,...),128),lineID=lineID,
  receivedAt=ns.SessionTime(),fallbackKey=not lineID and ns.ChatFallbackKey(event,message,{sender=sender}),channel=text(select(7,...),128)or text(select(2,...),128),selfName=ns.Shield.UnitName('player')}
 for k,v in pairs(context)do input[k]=v end
 local observer=ns.Chronicle.Owner();local epoch=C.Store().epoch;local attempts=0;pending=pending+1
 local function accept()
  attempts=attempts+1
  if observer~=ns.Chronicle.Owner()or epoch~=C.Store().epoch or C.Status().state~='RECORDING'then pending=pending-1;return end
  local state,entry=C.DisplayState(input);local outcome=entry and entry.captureSnapshot
  local settled=state=='FILTER_MODULE_DISABLED'or outcome and outcome.outcomeAt and ns.SessionTime()-outcome.outcomeAt>=.12
  if (state=='UNKNOWN'or not settled)and attempts<8 and C_Timer and C_Timer.After then C_Timer.After(.2,accept);return end
  pending=pending-1
  input.displayState=state;input.deliveryUID=entry and entry.captureID or not lineID and input.fallbackKey
  if not settled then input.displayState='UNKNOWN'end
  local _,why=C.Observe(input)
  if why=='FILTERED_OR_DISPLAY_UNPROVEN'then C.Store().warnings.native='LATEST_LINE_FILTERED_OR_DISPLAY_UNPROVEN'end
 end
 if C_Timer and C_Timer.After then C_Timer.After(.15,accept)else accept()end
end)
local lifecycle=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_LEAVING_WORLD','PLAYER_LOGOUT'})do lifecycle:RegisterEvent(event)end
lifecycle:SetScript('OnEvent',function(_,event)
 if event=='PLAYER_LEAVING_WORLD'or event=='PLAYER_LOGOUT'then C.Boundary();if ns.AthenaMoments then ns.AthenaMoments.Boundary(event)end end
 C.RefreshCapture();if ns.AthenaTextSources then ns.AthenaTextSources.Refresh()end
end)
local refreshGate=ns.Chronicle.RefreshGate
ns.Chronicle.RefreshGate=function(...)local a,b=refreshGate(...);C.RefreshCapture();if ns.AthenaTextSources then ns.AthenaTextSources.Refresh()end;return a,b end
local setEnabled=ns.Chronicle.SetEnabled
ns.Chronicle.SetEnabled=function(...)local a,b=setEnabled(...);C.RefreshCapture();return a,b end
C.captureFrame=frame
