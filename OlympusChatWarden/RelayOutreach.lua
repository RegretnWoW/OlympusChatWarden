-- User-started transient coordinator. Live actions deliberately remain locked.
local _,ns=...
local R=ns.Athena2
local O={VERSION=1};ns.RelayOutreach=O
function O.Classify(text)
 text=R.Text(text,256);if not text then return 'AMBIGUOUS' end
 text=text:lower():gsub('^%s+',''):gsub('%s+$',''):gsub('[!%.]+$','')
 if text=='no' or text=='no thanks' or text=='not interested' or text=='full' then return 'DECLINED' end
 if text=='busy' or text=='later' or text=='maybe later' then return 'DEFERRED' end
 if text=='yes' or text=='yes please' or text=='sure' or text=='invite me' or text=='inv' then return 'ACCEPTED' end
 return 'AMBIGUOUS'
end
function O.New(options)
 options=options or {};local c={session=nil,sequence=0,cooldowns={},sent=0,actions=0,options=options}
 local now=options.clock or R.Now
 local function valid(t)
  return t and R.GUID(t.guid) and R.Text(t.name) and R.Text(t.realm) and not t.blocked and not (options.isBlocked and options.isBlocked(t.guid)) and (not t.expiresAt or t.expiresAt>now()) and (not options.validateTarget or options.validateTarget(t)) and (t.olympusVerified or t.nativeListing and not t.queue)
 end
 function c:Prepare(target,context,authorization)
  self:Tick();if self.session and not self.session.closed then return nil,'SESSION_ACTIVE' end
  if not authorization or authorization.userInitiated~=true or not valid(target) then return nil,'EXPLICIT_RESOLVED_TARGET_REQUIRED' end
  if self.cooldowns[target.guid] and self.cooldowns[target.guid]>now() then return nil,'COOLDOWN' end
  if target.expiresAt and target.expiresAt<=now() then return nil,'EXPIRED' end
  context=context or {};local route=target.nativeListing and 'NATIVE_APPLY' or target.intent=='LFM' and 'REQUEST_JOIN' or target.intent=='LFG' and 'OFFER_GROUP' or 'ASK_FIRST'
  local activity=R.Text(context.activityName) or 'this activity';local role=({TANK='tank',HEALER='healer',DAMAGER='damage'})[context.role]
  local message=route=='ASK_FIRST' and ('Hi! Are you interested in grouping for '..activity..'?') or ('Hi! '..(role and 'I play '..role..'. ' or '')..'Would you like to group for '..activity..'?')
  self.sequence=self.sequence+1
  self.session={id='outreach-'..self.sequence,target=R.Copy(target),context=R.Copy(context),route=route,message=message,state='PREPARING',created=now(),expiresAt=now()+120,owner=R.Owner(),closed=false}
  return R.Copy(self.session)
 end
 function c:Queue(targets,context,authorization)
  if type(targets)~='table' or #targets<1 or #targets>3 or not authorization or not authorization.userInitiated then return false,'QUEUE_CAP_OR_AUTHORIZATION' end
  for _,t in ipairs(targets) do if not valid(t) or not t.olympusVerified then return false,'VERIFIED_OLYMPUS_QUEUE_ONLY' end end
  self.queue=R.Copy(targets);self.queueContext=R.Copy(context or {});self.queuePosition=0;return self:Next(true)
 end
 function c:Next(userClick)
  if not userClick or not self.queue or self.session and not self.session.closed then return nil,'ONE_TARGET_AT_A_TIME' end
  self.queuePosition=self.queuePosition+1;local t=self.queue[self.queuePosition];if not t then self.queue=nil;return nil,'QUEUE_COMPLETE' end
  return self:Prepare(t,self.queueContext,{userInitiated=true})
 end
 function c:Send(userClick,reviewedText)
  local s=self.session;if not s or s.state~='PREPARING' or not userClick then return false,'USER_CLICK_REQUIRED' end
  self:Tick();if s.closed or not valid(s.target) then return false,'EXPIRED_OR_BLOCKED' end
  if reviewedText~=s.message then return false,'PREVIEW_CHANGED' end
  if s.route=='NATIVE_APPLY' then s.state='AWAITING_USER_ACTION';s.status='Return to Blizzard Group Finder and use its Apply button';return true,s.status end
  if not options.mockSend then s.state='AWAITING_USER_ACTION';s.status='NATIVE-PENDING: copy the reviewed message into a normal whisper';return false,s.status end
  if options.mockSend(s.target,s.message)~=true then return false,'SEND_REFUSED' end
  s.state='AWAITING_RESPONSE';s.sentAt=now();self.sent=self.sent+1;self.cooldowns[s.target.guid]=now()+600;return true
 end
 function c:Reply(e)
  self:Tick();local s=self.session
  if not s or s.state~='AWAITING_RESPONSE' or not e or e.channel~='WHISPER' or e.guid~=s.target.guid or e.realm~=s.target.realm or not R.Text(e.id,128) or e.id==s.lastReplyID or e.at<s.sentAt or e.at>now() or e.at>s.expiresAt then return false end
  s.lastReplyID=e.id;local result=O.Classify(e.message)
  if result=='ACCEPTED' then s.state='AWAITING_USER_ACTION';s.status='Accepted · native Invite requires your click and permission'
  elseif result=='DECLINED' then s.state='DECLINED';s.closed=true
  elseif result=='DEFERRED' then s.state='DEFERRED';s.closed=true
  else s.state='NEEDS_REVIEW';s.status='Reply is ambiguous. No invitation was sent.' end
  return true
 end
 function c:Party(state)
  local s=self.session;if not s or s.closed then return end
  if state.joinedGUID==s.target.guid then s.state='JOINED';s.closed=true
  elseif state.full or state.disbanded or state.eligible==false then self:Cancel('Party changed') end
 end
 function c:Tick()
  if self.session and not self.session.closed and not valid(self.session.target) then self:Cancel('Target, source or eligibility changed') end
  local s=self.session;if s and not s.closed and now()>=s.expiresAt then s.state='EXPIRED';s.closed=true;self.cooldowns[s.target.guid]=now()+600 end
  for key,at in pairs(self.cooldowns) do if at<=now() then self.cooldowns[key]=nil end end
 end
 function c:Cancel(reason) self.queue=nil;if self.session then self.session.state='CANCELLED';self.session.closed=true;self.session.status=reason or 'Cancelled; sent messages cannot be retracted' end end
 return c
end
O.Current=O.New()
