-- Interacted native dialogue joins the same private conversation archive.
-- No reference quotations, coordinates, dialogue-choice inference or new DB.
local _,ns=...
local C=ns.AthenaConversations;local T={coverage={},pending=0};ns.AthenaTextSources=T
local frame=CreateFrame('Frame');local generation=0
local direct={'GOSSIP_SHOW','QUEST_DETAIL','QUEST_PROGRESS','QUEST_COMPLETE','TALKINGHEAD_REQUESTED','CINEMATIC_START','PLAY_MOVIE'}
local function get(fn,...)return ns.SafeCall(fn,...)end
local function text(v)return ns.SafeString(v,8192)end
local function regionText(region)
 if not ns.Readable(region)or not region or not region.GetText then return end
 local visible=get(region.IsVisible,region);local alpha=ns.SafeNumber(get(region.GetEffectiveAlpha or region.GetAlpha,region))
 if not ns.Checked(visible)or not alpha or alpha<=0 then return end
 return text(get(region.GetText,region))
end
local function candidates(event)
 if event=='GOSSIP_SHOW'then return {GossipGreetingText,GreetingText,GossipFrame and GossipFrame.GreetingPanel and GossipFrame.GreetingPanel.GreetingText,GossipFrame and GossipFrame.GreetingText}end
 if event=='QUEST_DETAIL'then return {QuestInfoDescriptionText,QuestInfoObjectivesText}end
 if event=='QUEST_PROGRESS'then return {QuestProgressText}end
 if event=='QUEST_COMPLETE'then return {QuestInfoRewardText}end
 if event=='TALKINGHEAD_REQUESTED'then return {TalkingHeadFrame and TalkingHeadFrame.TextFrame and TalkingHeadFrame.TextFrame.Text}end
 return {}
end
local function native(event,index)
 if event=='GOSSIP_SHOW'then return text(get(C_GossipInfo and C_GossipInfo.GetText or GetGossipText))end
 if event=='QUEST_DETAIL'then return text(get(index==1 and GetQuestText or GetObjectiveText))end
 if event=='QUEST_PROGRESS'then return text(get(GetProgressText))end
 if event=='QUEST_COMPLETE'then return text(get(GetRewardText))end
end
function T.Refresh()
 frame:UnregisterAllEvents();generation=generation+1
 local status=C.Status()
 if status.state=='RECORDING'and status.policy.scopes.npcDialogue then for _,event in ipairs(direct)do local ok=pcall(frame.RegisterEvent,frame,event);if not ok then T.coverage[event]='EVENT_UNAVAILABLE'end end end
end
function T.Capture(event)
 local status=C.Status();if status.state~='RECORDING'or not status.policy.scopes.npcDialogue then return false,'NOT_AUTHORIZED'end
 if event=='CINEMATIC_START'or event=='PLAY_MOVIE'then T.coverage[event]='UNSUPPORTED_NO_VERIFIED_CAPTION_SOURCE';return false,T.coverage[event]end
 if T.pending>=4 then T.coverage[event]='DIALOGUE_QUEUE_BOUND';return false,T.coverage[event]end
 T.pending=T.pending+1;local epoch=generation;local attempts=0;local owner=ns.Chronicle.Owner()
 local questEvent=event=='QUEST_DETAIL'or event=='QUEST_PROGRESS'or event=='QUEST_COMPLETE'
 local quest=questEvent and ns.SafeNumber(get(GetQuestID))or nil;local guid=ns.SafeString(get(UnitGUID,'npc'),128)
 local function capture()
  attempts=attempts+1
  if epoch~=generation or owner~=ns.Chronicle.Owner()or C.Status().state~='RECORDING'then T.pending=T.pending-1;return end
  if event~='TALKINGHEAD_REQUESTED'and(guid~=ns.SafeString(get(UnitGUID,'npc'),128)or questEvent and quest~=ns.SafeNumber(get(GetQuestID)))then T.pending=T.pending-1;T.coverage[event]='DIALOGUE_BINDING_CHANGED';return end
  local captured=0
  -- Holes in the optional globals are expected; pairs avoids truncating a
  -- later valid native region just because a previous client widget is absent.
  for index,region in pairs(candidates(event))do
   local shown=regionText(region);local original=native(event,index)
   if event=='TALKINGHEAD_REQUESTED'and region and ns.RegionOriginal then original=text(ns.RegionOriginal(region))end
   if shown and shown~=''and original==shown then
    local context=ns.Chronicle.ConversationContext();local speaker=text(get(UnitName,'npc'))
    if event=='TALKINGHEAD_REQUESTED'then local r=TalkingHeadFrame and TalkingHeadFrame.NameFrame and TalkingHeadFrame.Name;speaker=r and regionText(r);guid=nil end
    local input={event=event,text=shown,sender=speaker,senderGUID=guid,observedAt=get(GetServerTime)or get(time),displayState='VISIBLE_REGION_VERIFIED',directDialogue=true,
     questID=quest and quest>0 and quest or nil,deliveryUID=event..'/'..tostring(quest)..'/'..tostring(guid)..'/'..index..'/'..ns.ChatFallbackKey(event,shown,{sender=speaker}),nativeSourceRef='native-dialogue/'..event}
    for k,v in pairs(context)do input[k]=v end
    -- Quest dialogue is observed on this screen; never use a stale unrelated
    -- gameplay anchor. A subsequent matching quest event can add its relation.
    if input.questID then input.sourceRef=nil;input.eventAt=nil end
    input.sessionRef=input.sessionRef or ns.AthenaMoments.session
    local uid,why=C.Observe(input);if uid then captured=captured+1 else T.coverage[event]=why end
   end
  end
  if captured>0 then T.pending=T.pending-1;T.coverage[event]='OBSERVED_VISIBLE_TEXT_PRESERVED_PER_CONSENT';return end
  if attempts<4 and C_Timer and C_Timer.After then C_Timer.After(.2,capture);return end
  T.pending=T.pending-1;T.coverage[event]=T.coverage[event]or'NO_MATCHING_READABLE_VISIBLE_NATIVE_TEXT'
 end
 if C_Timer and C_Timer.After then C_Timer.After(.15,capture)else capture()end
 return true
end
frame:SetScript('OnEvent',function(_,event)T.Capture(event)end);T.frame=frame
