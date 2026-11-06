-- Generated from the approved 250-cell prospective policy; no historical rewrite.
local _,ns=...
local P={VERSION=1};ns.AthenaCollectionPolicy=P
P.categories={'Self','Manual watch','Earned Important','Verified friend','Ordinary guildmate','Ordinary party/raid','Ordinary BG player','Ordinary duel opponent','Ordinary world player','Unresolved identity'}
P.matrix={
 [1]={'Deep','N/A','N/A','N/A','N/A','N/A','N/A','N/A','N/A','N/A'},
 [2]={'Deep','N/A','N/A','N/A','N/A','N/A','N/A','N/A','N/A','N/A'},
 [3]={'Deep','N/A','N/A','N/A','N/A','N/A','N/A','N/A','N/A','N/A'},
 [4]={'N/A','Light','Light','Light','Light','Light','Context','Light','Context','Context'},
 [5]={'N/A','Light','Light','Light','Light','Light','Context','Light','Context','Context'},
 [6]={'Deep','Context','Context','Context','Light','Light','N/A','Context','N/A','Context'},
 [7]={'Deep','Context','Context','Context','Light','Light','N/A','N/A','N/A','Context'},
 [8]={'Deep','Context','Context','Context','Context','Context','N/A','N/A','N/A','Context'},
 [9]={'Deep','Light','Light','Light','Context','Context','Light','Context','N/A','Context'},
 [10]={'Deep','Light','Light','Light','Light','Light','Light','Light','N/A','Context'},
 [11]={'Deep','Light','Light','Light','Context','Light','Context','Light','Context','Context'},
 [12]={'Deep','Context','Context','Context','N/A','N/A','N/A','Light','Context','Context'},
 [13]={'Deep','Deep','Deep','Deep','N/A','N/A','N/A','Off','N/A','N/A'},
 [14]={'Deep','Deep','Deep','Deep','N/A','N/A','N/A','Light','N/A','N/A'},
 [15]={'Deep','N/A','N/A','N/A','N/A','N/A','N/A','N/A','N/A','N/A'},
 [16]={'Deep','Deep','Deep','Deep','Off','Off','Off','Off','Off','Off'},
 [17]={'Deep','Deep','Deep','Deep','Off','Off','Off','Off','Off','Off'},
 [18]={'Deep','Light','Light','Light','Context','Light','Context','Light','Context','Context'},
 [19]={'Deep','Light','Light','Light','Context','Light','Light','Light','Off','Context'},
 [20]={'Deep','Deep','Deep','Deep','Off','Off','Off','Off','Off','Off'},
 [21]={'Deep','Deep','Deep','Deep','Off','Off','Off','Off','Off','Off'},
 [22]={'N/A','Deep','Deep','Deep','Off','Off','Off','Off','Off','Off'},
 [23]={'Deep','Light','Light','Light','Light','Light','Context','Context','Context','Context'},
 [24]={'Review','Review','Review','Review','Review','Review','Review','Review','Review','Review'},
 [25]={'N/A','Light','Light','Light','Light','Light','Context','Context','Context','Context'},
}
-- This pure resolver is used by live gates and isolated Lab inputs alike.
-- Canonical owner/group/match facts and existing manual actions are separate.
function P.Resolve(activity,f)
    local row=P.matrix[activity];if not row or type(f)~='table' then return 'Off','UNSUPPORTED_POLICY' end
    if f.recording~=true or f.module~=true then return 'Off','RECORDING_OR_MODULE_OFF' end
    if f.witnessRequired==true and f.witness~=true then return 'Off','WITNESS_OFF' end
    if f.duelRequired==true and f.duel~=true then return 'Off','DUEL_OFF' end
    local category=f.self==true and 1 or f.watch==true and 2 or f.earned==true and 3 or f.friend==true and 4
        or f.bg==true and 7 or f.duelOpponent==true and 8 or f.group==true and 6 or f.guild==true and 5 or f.guid==true and 9 or 10
    local mode=row[category]
    if mode=='Review' then return 'Off','REVIEW_NOT_AUTHORIZED',category end
    return mode,mode=='N/A' and 'SOURCE_NOT_APPLICABLE' or 'SELECTED_POLICY',category
end
function P.Facts(guid,options)
    options=options or {};local C,X,S=ns.Chronicle,ns.ChronicleCapture,ns.ChronicleStore
    guid=S.GUID(guid);local self=guid~=nil and guid==select(2,C.Owner());local guild=false
    local e=ns.AthenaEnrichment;local place=not options.priorityOnly and C.Place() or {};local group=false
    local unit=not options.priorityOnly and (options.unit or (guid and not self and e and e.Resolve(guid)))
    if unit and guid and S.GUID(X.Call('UnitGUID',unit))==guid then
        group=X.Bool(X.Call('UnitInParty',unit))==true or S.Integer(X.Call('UnitInRaid',unit),1,40)~=nil
        local mine=S.Text(X.Call('GetGuildInfo','player'),128);local theirs=S.Text(X.Call('GetGuildInfo',unit),128)
        guild=mine~=nil and theirs==mine
        if S.GUID(X.Call('UnitGUID',unit))~=guid then group=false;guild=false end
    end
    return {guid=guid~=nil,self=self,recording=X.Ready()==true,module=self and C.PersonalEnabled() or not self and C.IntelEnabled(),
        watch=guid and e and e.Watched(guid) or false,earned=guid and ns.IntelPolicy.EarnedTier(guid)==1 or false,
        friend=guid and ns.AthenaSocial and ns.AthenaSocial.Friend(guid) or false,group=group,guild=guild,
        bg=place.inInstance==true and (place.instanceType=='pvp' or place.instanceType=='arena'),
        duelOpponent=guid and ns.ChronicleDuels and ns.ChronicleDuels.IsOpponent and ns.ChronicleDuels.IsOpponent(guid) or false,
        witnessRequired=options.witness==true,witness=ns.IntelWitness and ns.IntelWitness.Selected() or false,
        duelRequired=options.duel==true,duel=ns.ChronicleDuels and ns.ChronicleDuels.Enabled() or false}
end
function P.Decide(activity,guid,options) return P.Resolve(activity,P.Facts(guid,options)) end
function P.Deep(activity,guid,options) return P.Decide(activity,guid,options)=='Deep' end
function P.Light(activity,guid,options)
    local mode=P.Decide(activity,guid,options);return mode=='Deep' or mode=='Light'
end
