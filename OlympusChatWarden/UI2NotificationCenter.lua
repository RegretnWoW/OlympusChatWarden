-- One notification view over Activity's existing bounded IDs/read states.
-- This is not a second inbox, a new raw-history scan or another alert policy.
local _,ns=...
local N={VERSION=1};ns.UI2NotificationCenter=N
local A,P=ns.Activity,ns.Notifications
local names={sanctuary='Sanctuary reward',mentions='Mention',wanted='Wanted alert',olympusmute='Olympus sharing observed',messages='Filtered message',shield='Protection alert',athena='Athena activity'}
local function allowed(item,key)
 if not ns.DB or not ns.Membership.Allowed() or not P.Get('badges') then return false end
 if key=='sanctuary'then return P.Get('sanctuary')and item.owner==ns.Chronicle.Owner()
 elseif key=='messages' then local entry=item.reviewID and ns.Review.Get(item.reviewID)
  return ns.Modules.Enabled('chat') and entry~=nil and P.Allows(entry)
 elseif key=='shield' then
  local entry=item.reviewID and ns.Review.Get(item.reviewID) or {shieldReason=item.shieldAlert and item.shieldAlert.message}
  return ns.Modules.Enabled('shield') and P.Get(P.Category(entry)) and (not item.quiet[key] or item.read[key])
 elseif key=='mentions' then return ns.Modules.Enabled('alerts') and ns.DB.alertsEnabled~=false and ns.Mentions.db and ns.Mentions.db.enabled and not item.quiet[key]
 elseif key=='wanted' then return ns.Modules.Enabled('alerts') and ns.DB.alertsEnabled~=false and ns.Wanted.db and ns.Wanted.db.enabled and ns.Wanted.db.badges and not item.quiet[key]
 elseif key=='olympusmute' then return ns.Modules.Enabled('alerts') and ns.DB.alertsEnabled~=false and not item.quiet[key]
 elseif key=='athena' then return ns.Modules.Enabled('alerts') and P.Get(item.notificationPreference or 'athena') and not item.quiet[key]
  and (not item.wallItem or ns.AetherNet.VisibleNotice and ns.AetherNet.VisibleNotice(item)) end
 return false
end
function N.List()
 local rows={};local unread=0
 for n=#A.entries,1,-1 do local item=A.entries[n];local categories={}
  local isUnread=false
  for key in pairs(item.categories) do if allowed(item,key) then categories[#categories+1]=names[key] or key;if not item.read[key] then isUnread=true end end end
  if #categories>0 then
   table.sort(categories)
   rows[#rows+1]={id=item.id,label=table.concat(categories,' · '),title=A.DisplayName(item.sender or 'Olympus'),preview=item.preview or '',at=item.timestamp,unread=isUnread,reviewID=item.reviewID,message=item.categories.mentions and type(item.event)=='string' and item.event:match('^CHAT_MSG_')~=nil,guid=item.subjectGUID or item.wanted and item.wanted.guid,owner=item.owner,eventKey=item.eventKey,wallItem=item.wallItem,subjectType=item.subjectType,preference=item.notificationPreference}
   if isUnread then unread=unread+1 end
  end
 end
 return rows,unread
end
function N.OpenWall(guid,owner,wallItem,subjectType)
 if subjectType=='WIKI' and ns.AthenaLivingWiki then
  local W=ns.AthenaLivingWiki;local first=W.Discussion(guid,1);local selected=1
  for page=1,first.pages do local discussion=page==1 and first or W.Discussion(guid,page)
   for _,post in ipairs(discussion.rows) do if post.id==wallItem then selected=page end end
  end
  return W.Open(guid,{discussionPage=selected,jump='discussion'})
 end
 local view=ns.AetherNet.ReadSubject('CHARACTER',guid);local position
 for i,post in ipairs(view and view.wall or {}) do if post.id==wallItem then position=i end end
 if not position then return ns.UI2.Open({page='intel',kind='player',key=guid,owner=owner,jump='wall'}) end
 ns.UI2.expanded['wall/'..guid]=true;ns.UI2.sectionPages=ns.UI2.sectionPages or {};ns.UI2.sectionPages['wall/'..guid]=math.ceil(position/20)
 return ns.UI2.Open({page='intel',kind='player',key=guid,owner=owner,jump='wall',wallItem=wallItem})
end
function N.OpenItem(id)
 local original=A.Get(id)
 if original and original.categories.sanctuary and original.owner==ns.Chronicle.Owner()then
  local ok=ns.WardenSanctuary.OpenCollection();if ok then A.Mark(id);if N.panel then N.panel:Hide()end end;return ok
 end
 local row
 for _,r in ipairs(N.List()) do if r.id==id then row=r;break end end
 if not row then return false end
 local ok,why
 if row.reviewID then ok,why=ns.UI2.Open({page='messages',messageID=row.reviewID,activityID=id})
 elseif row.message then ok,why=ns.UI2.Open({page='messages',activityID=id})
 elseif row.eventKey then ok,why=ns.UI2.Open({page='chronicle',kind='activity',key=row.eventKey,owner=row.owner})
 elseif row.wallItem then
  ok,why=N.OpenWall(row.guid,row.owner,row.wallItem,row.subjectType)
 elseif row.guid then ok,why=ns.WardenUI.Navigate('player',row.owner or ns.Chronicle.Owner(),row.guid)
 else ok,why=ns.UI2.Open({page='mentions',notificationID=id}) end
 if ok then A.Mark(id);if N.panel then N.panel:Hide() end end
 return ok,why
end
function N.MarkAll()
 A.batch=(A.batch or 0)+1
 for _,r in ipairs(N.List()) do A.Mark(r.id) end
 A.batch=A.batch-1;A.Changed()
end
function N.Refresh()
 local rows,count=N.List();N.count=count
 if N.button then N.button.count:SetText(count>0 and tostring(math.min(count,99))..(count>99 and '+' or '') or '');N.button.dot:SetShown(count>0) end
 if not N.panel or not N.panel:IsShown() then return end
 N.panel:SetHeight(math.min(610,math.max(172,#rows*74+104)))
 local items={}
 for _,r in ipairs(rows) do local id=r.id
  items[#items+1]={title=(r.unread and '• ' or '')..r.title,detail=r.label..' · '..ns.UI2Components.Stamp(r.at,true),activate=function() N.OpenItem(id) end,height=31,widths={.35,.65}}
  items[#items+1]={title=r.preview~='' and r.preview or 'Open notification',activate=function() N.OpenItem(id) end,height=43,wrap=true,kind='caption'}
 end
 if #items==0 then items[1]={title='No notifications from your enabled categories.',wrap=true,height=64,kind='caption'} end
 N.page:SetItems(items,N.page.scroll:GetVerticalScroll())
end
function N.Attach(header,window)
 local C=ns.UI2Components
 local button=C.Button(header,'',function() N.Toggle() end,40);N.button=button;button:SetPoint('TOPRIGHT',-63,-23)
 local face=button.face or button
 local bell=face:CreateTexture(nil,'OVERLAY');N.bell=bell;bell:SetTexture('Interface\\AddOns\\OlympusChatWarden\\Media\\Window64\\bell.tga');bell:SetSize(21,21);bell:SetPoint('CENTER',face,'CENTER',0,0)
 button.dot=face:CreateTexture(nil,'OVERLAY');button.dot:SetSize(8,8);button.dot:SetPoint('TOPRIGHT',face,'TOPRIGHT',-2,-2);button.dot:SetColorTexture(.75,.04,.025,1)
 button.count=C.Text(face,'',10,C.colors.gold);button.count:SetPoint('BOTTOMRIGHT',face,'BOTTOMRIGHT',2,-2);button.count:SetSize(26,15);button.count:SetJustifyH('RIGHT')
 button:SetScript('OnEnter',function(self) if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_BOTTOM');GameTooltip:SetText('Notifications');GameTooltip:AddLine('Mentions and enabled alerts from across Olympus.',1,1,1,true);GameTooltip:Show() end end)
 button:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
 local f=C.Card(window,'Notifications',true);N.panel=f;f:SetPoint('TOPRIGHT',-14,-78);f:SetSize(520,172);f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(window:GetFrameLevel()+80);f:EnableMouse(true);f:Hide()
 ns.Theme.RegisterModal(f,window)
 f:ClearAllPoints();f:SetPoint('TOPRIGHT',window,'TOPRIGHT',-14,-78);f:SetClampedToScreen(true)
 local close=C.Button(f,'×',function() f:Hide() end,28);close:SetPoint('TOPRIGHT',-3,-3)
 local host=CreateFrame('Frame',nil,f);host:SetPoint('TOPLEFT',8,-39);host:SetPoint('BOTTOMRIGHT',-8,48)
 N.page=C.Page(host);N.page.paper=true
 C.Button(f,'Mark all read',N.MarkAll,150):SetPoint('BOTTOMLEFT',12,11)
 C.Button(f,'Preferences',function() f:Hide();ns.UI2.Open({page='settings',category='notifications'}) end,150):SetPoint('BOTTOMRIGHT',-12,11)
 window:HookScript('OnHide',function() f:Hide() end)
 N.Refresh()
end
function N.Toggle() if not N.panel then return end;N.panel:SetShown(not N.panel:IsShown());N.Refresh() end
A.Subscribe(function() N.Refresh() end)
