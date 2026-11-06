-- Separate bounded SavedVariables for received claims, opinions and consent.
-- Pending requests, chat, dossiers and canonical evidence are never saved here.
local _,ns=...
local R=ns.Athena2
local S={VERSION=1,MAX_CHARACTERS=16};ns.AthenaExchangeState=S
local bound=setmetatable({},{__mode='k'})
function S.Bind(client,storage)
 if not client or not R.GUID(client.owner) then return false,'EXACT_CHARACTER_REQUIRED' end
 if storage==nil then
  storage=ns.Storage.OlympusWardenExchangeDB
  if storage==nil then storage={schema=1,characters={}};ns.Storage.OlympusWardenExchangeDB=storage end
 end
 if type(storage)~='table' or getmetatable(storage) or storage.schema~=1 or type(storage.characters)~='table' or getmetatable(storage.characters) then return false,'STATE_ROOT_UNAVAILABLE_OR_NEWER' end
 for key in pairs(storage) do if key~='schema' and key~='characters' and key~='netClients'and key~='netLocal'and key~='aetherCredentials'and key~='extensionActivities' then return false,'STATE_ROOT_FIELD' end end
 if R.Count(storage.characters)>S.MAX_CHARACTERS or not storage.characters[client.owner] and R.Count(storage.characters)>=S.MAX_CHARACTERS then return false,'STATE_CHARACTER_CAPACITY' end
 if client.stateStorage then return client.stateStorage==storage,'ALREADY_BOUND' end
 local old=storage.characters[client.owner]
 if old then local ok,why=client:RestoreState(old);if not ok then return false,why end end
 client.stateStorage=storage
 bound[client]=true
 function client:SaveState()
  if self.privacyDetached then return false,'PRIVACY_ERASED_SESSION' end
  -- Retired public snapshots are rollback material, never an active ledger.
  -- Binding or logout must not replace an old consent/cache with an empty or
  -- pruned state merely because the old public service has been disabled.
  if self.legacyState then return true,'LEGACY_STATE_READ_ONLY' end
  local snapshot=self:ExportState();if not snapshot then return false,'STATE_UNAVAILABLE' end
  self.stateStorage.characters[self.owner]=snapshot;return true
 end
 for _,method in ipairs({'Join','Leave','Vote','Receive','Decide'}) do
  local original=client[method]
  client[method]=function(self,...)
   local a,b=original(self,...)
   ns.WardenScheduler.Submit('exchange save/'..self.owner,'low',function() self:SaveState();return true end,{module='relay'})
   return a,b
  end
 end
 ns.WardenScheduler.Submit('exchange save/'..client.owner,'low',function() client:SaveState();return true end,{module='relay'})
 return true
end
local frame=CreateFrame('Frame');frame:RegisterEvent('PLAYER_LOGOUT')
frame:SetScript('OnEvent',function()
 for client in pairs(bound) do local ok,why=pcall(client.SaveState,client);if not ok then S.lastError=tostring(why):sub(1,160) end end
end)

function S.ForgetLocal(owner) for c in pairs(bound) do if not owner or c.owner==owner then c:Leave();c.privacyDetached=true;bound[c]=nil;ns.WardenScheduler.Cancel('exchange save/'..c.owner) end end end
