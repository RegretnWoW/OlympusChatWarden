-- Bundled reference, using the public facade. Never a playable Banner game.
local _,ns=...
local A=_G.OlympusWarden and _G.OlympusWarden.API;if not A then return end
local id='org.olympus.developer-example';local handle
local manifest={id=id,addon='OlympusChatWarden',publisher='Olympus Warden',title='Developer Example',version='0.1.0',apiMajor=1,minMinor=0,
 permissions={'profile.local_page','profile.public_read','profile.public_card','presence.discover','activity.local'},pageTitle='Developer Example',cardSchema=1,activitySchema=1}
handle=A:RegisterExtension(manifest,{BuildProfilePage=function(context,host)
 host:Text('Developer Example','Local extension page · public SDK remains disabled')
 host:Text('Selected character',context.identity.name or context.guid)
 host:Text('Data access','Public shared fields only. No private notes, chat, historical routes, reputation grants or gameplay evidence access.')
 host:Button('Run local contract and rejection checks',function()
  local result=ns.WardenExtensions.RunExample(handle)
  ns.WardenExtensions.lastExample=result and'Authorized local contract and abuse rejection checks passed; no native network or rewards.'or'Example failed; inspect private developer results.'
  ns.UI2.Refresh(true)
 end)
 host:Text('Last example',ns.WardenExtensions.lastExample or'Not run')
 host:Button('Review my example profile card',function()
  ns.UI2Forms.Confirm('Publish my developer example card?','Only your own profile receives this explicitly approved test card. It is not an official achievement, reputation rating or Banner reward.',function()
   local value,why=A:PublishProfileCard(handle,{cardID='preview',title='Developer Example',text='Owner-approved API preview. No gameplay accomplishment is claimed.',icon='torch'})
   return value~=nil,why
  end)
 end)
end})
function ns.WardenExtensions.RunExample(h)
 local e,why=ns.WardenExtensions.Check(h,'activity.local');if not e then return nil,why end
 local own=ns.PlayerCard.Own();local at=ns.SafeCall(GetServerTime)or 1
 local S=assert(ns.AetherActivityService.New({owner=own,clock=function()return at end,
  authorize=function(v)return v.actorGUID==own and v.targetGUID==own end,
  verify=function(v,p)return p=='LOCAL_DEVELOPER_FIXTURE'and own or nil end}))
 assert(S.Define({extension=id,activityID='local-contract',version=1,ruleset='developer-preview',minimum=1,maximum=1,authority='COORDINATOR_SIGNED'}))
 local first={version=1,extension=id,activityID='local-contract',rulesVersion=1,envelopeID='example-session',kind='SESSION',sessionID='example',actorGUID=own,targetGUID=own,sequence=0,prior='root',issuedAt=at,expiresAt=at+60,body={authority=own,holder=own,participants={own}}}
 assert(S.Receive(first,'LOCAL_DEVELOPER_FIXTURE','self'))
 local turn=ns.Athena.Copy(first);turn.envelopeID='example-turn';turn.kind='TURN';turn.sequence=1;turn.prior=first.envelopeID;turn.body={nextHolder=own}
 assert(S.Receive(turn,'LOCAL_DEVELOPER_FIXTURE','self'));assert(S.Receive(turn,'LOCAL_DEVELOPER_FIXTURE','self'))
 local forged=ns.Athena.Copy(turn);forged.envelopeID='forged';assert(not S.Receive(forged,'UNTRUSTED','stranger'))
 assert(not A:PublishProfileCard(h,{cardID='bad',title='Impersonation',text='x',icon='torch',subjectGUID='Player-FAKE-Other'}))
 assert(not A:PublishProfileCard(h,{cardID='bad',title='Markup',text='<script>bad</script>',icon='torch'}))
 assert(A.GetPrivateHistory==nil and A.SendMessage==nil and A.AwardRenown==nil)
 return {status='MOCK_PASS',authority='LOCAL_DEVELOPER_FIXTURE_ONLY',turns=S.root.sessions.example.revision,rewards=0,abuseRejected=true,native='NOT_RUN'}
end
