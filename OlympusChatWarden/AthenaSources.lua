-- Field manifests from pinned Forever 1.60.1.70425 native documentation.
local _,ns=...
local R={version=3,events={},families={}};ns.AthenaSources=R
-- These events are consumed by the pinned native nameplate driver, rather
-- than listed in its generated API event table. Never use forbidden plates.
R.events.NAME_PLATE_UNIT_ADDED={family='identity',fields={{'namePlateUnitToken','UnitTokenNamePlate'}},documentation='Blizzard_NamePlates/Blizzard_NamePlates.lua',status='NOT_TESTED'}
R.events.NAME_PLATE_UNIT_REMOVED={family='identity',fields={{'namePlateUnitToken','UnitTokenNamePlate'}},documentation='Blizzard_NamePlates/Blizzard_NamePlates.lua',status='NOT_TESTED'}
R.unregistered={UNIT_DIED={status='NOT_TESTED',documentation='UnitDocumentation.lua',reason='Documented synchronous GUID event; native addon registration and restricted-identity delivery remain unverified. Not probed or interpreted as a kill.'}}
R.families['identity']={status='NOT_TESTED',scope='manual watchlist or explicitly armed self'}
R.events['PLAYER_TARGET_CHANGED']={family='identity',fields={},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['PLAYER_FOCUS_CHANGED']={family='identity',fields={},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UPDATE_MOUSEOVER_UNIT']={family='identity',fields={},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UNIT_NAME_UPDATE']={family='identity',fields={{'unitTarget','UnitTokenVariant'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UNIT_TARGET']={family='identity',fields={{'unitTarget','UnitTokenVariant'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['states']={status='NOT_TESTED',scope='manual watchlist or explicitly armed self'}
R.events['UNIT_FLAGS']={family='states',fields={{'unitTarget','UnitTokenVariant'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UNIT_FACTION']={family='states',fields={{'unitTarget','UnitTokenVariant'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UNIT_LEVEL']={family='states',fields={{'unitTarget','UnitTokenVariant'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UNIT_HEALTH']={family='states',fields={{'unitTarget','UnitTokenVariant'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UNIT_MAXHEALTH']={family='states',fields={{'unitTarget','UnitTokenVariant'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UNIT_POWER_UPDATE']={family='states',fields={{'unitTarget','UnitTokenVariant'},{'powerType','cstring'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UNIT_AURA']={family='states',fields={{'unitTarget','UnitTokenVariant'},{'updateInfo','UnitAuraUpdateInfo'}},documentation='UnitAuraDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UNIT_PET']={family='states',fields={{'unitTarget','UnitTokenVariant'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['inspection']={status='NOT_TESTED',scope='manual watchlist or explicitly armed self'}
R.events['INSPECT_READY']={family='inspection',fields={{'inspecteeGUID','WOWGUID'}},documentation='PaperDollInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UNIT_INVENTORY_CHANGED']={family='inspection',fields={{'unitTarget','UnitTokenVariant'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['PLAYER_EQUIPMENT_CHANGED']={family='inspection',fields={{'equipmentSlot','number'},{'hasCurrent','bool'}},documentation='PaperDollInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['casts']={status='NOT_TESTED',scope='manual watchlist or explicitly armed self'}
R.events['UNIT_SPELLCAST_START']={family='casts',fields={{'unitTarget','UnitTokenVariant'},{'castGUID','WOWGUID'},{'spellID','number'},{'castBarID','UnitCastBarID'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UNIT_SPELLCAST_STOP']={family='casts',fields={{'unitTarget','UnitTokenVariant'},{'castGUID','WOWGUID'},{'spellID','number'},{'castBarID','UnitCastBarID'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UNIT_SPELLCAST_SUCCEEDED']={family='casts',fields={{'unitTarget','UnitTokenVariant'},{'castGUID','WOWGUID'},{'spellID','number'},{'castBarID','UnitCastBarID'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UNIT_SPELLCAST_INTERRUPTED']={family='casts',fields={{'unitTarget','UnitTokenVariant'},{'castGUID','WOWGUID'},{'spellID','number'},{'interruptedBy','WOWGUID'},{'castBarID','UnitCastBarID'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UNIT_SPELLCAST_CHANNEL_START']={family='casts',fields={{'unitTarget','UnitTokenVariant'},{'castGUID','WOWGUID'},{'spellID','number'},{'castBarID','UnitCastBarID'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UNIT_SPELLCAST_CHANNEL_STOP']={family='casts',fields={{'unitTarget','UnitTokenVariant'},{'castGUID','WOWGUID'},{'spellID','number'},{'interruptedBy','WOWGUID'},{'castBarID','UnitCastBarID'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['combat']={status='NOT_TESTED',scope='manual watchlist or explicitly armed self'}
R.events['PARTY_KILL']={family='combat',fields={{'attackerGUID','WOWGUID'},{'targetGUID','WOWGUID'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['PLAYER_DEAD']={family='combat',fields={},documentation='DeathInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['PLAYER_ALIVE']={family='combat',fields={},documentation='DeathInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['PLAYER_UNGHOST']={family='combat',fields={},documentation='DeathInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['PLAYER_REGEN_DISABLED']={family='combat',fields={},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['PLAYER_REGEN_ENABLED']={family='combat',fields={},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['meter']={status='NOT_TESTED',scope='manual watchlist or explicitly armed self'}
R.events['DAMAGE_METER_COMBAT_SESSION_UPDATED']={family='meter',fields={{'type','DamageMeterType'},{'sessionID','number'}},documentation='DamageMeterDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['DAMAGE_METER_CURRENT_SESSION_UPDATED']={family='meter',fields={},documentation='DamageMeterDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['DAMAGE_METER_RESET']={family='meter',fields={},documentation='DamageMeterDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['group']={status='NOT_TESTED',scope='manual watchlist or explicitly armed self'}
R.events['GROUP_ROSTER_UPDATE']={family='group',fields={},documentation='PartyInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['GROUP_JOINED']={family='group',fields={{'category','number'},{'partyGUID','WOWGUID'}},documentation='PartyInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['GROUP_LEFT']={family='group',fields={{'category','number'},{'partyGUID','WOWGUID'}},documentation='PartyInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['PARTY_LEADER_CHANGED']={family='group',fields={},documentation='PartyInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['PLAYER_ENTERING_WORLD']={family='group',fields={{'isInitialLogin','bool'},{'isReloadingUi','bool'}},documentation='SystemDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['ZONE_CHANGED_NEW_AREA']={family='group',fields={},documentation='MapDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['encounter']={status='NOT_TESTED',scope='manual watchlist or explicitly armed self'}
R.events['ENCOUNTER_START']={family='encounter',fields={{'encounterID','number'},{'encounterName','cstring'},{'difficultyID','number'},{'groupSize','number'}},documentation='EncounterInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['ENCOUNTER_END']={family='encounter',fields={{'encounterID','number'},{'encounterName','cstring'},{'difficultyID','number'},{'groupSize','number'},{'success','number'},{'encounterUnitStatus','table'}},documentation='EncounterInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['BOSS_KILL']={family='encounter',fields={{'encounterID','number'},{'encounterName','cstring'}},documentation='EncounterInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['INSTANCE_ENCOUNTER_ENGAGE_UNIT']={family='encounter',fields={},documentation='InstanceEncounterDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['battleground']={status='NOT_TESTED',scope='manual watchlist or explicitly armed self'}
R.events['UPDATE_BATTLEFIELD_SCORE']={family='battleground',fields={},documentation='PvpInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['PVP_MATCH_COMPLETE']={family='battleground',fields={{'winner','number'},{'duration','time_t'}},documentation='PvpInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['PVP_MATCH_ACTIVE']={family='battleground',fields={},documentation='PvpInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['BATTLEGROUND_POINTS_UPDATE']={family='battleground',fields={},documentation='PvpInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['public']={status='NOT_TESTED',scope='manual watchlist or explicitly armed self'}
R.events['CHAT_MSG_ACHIEVEMENT']={family='public',fields={{'text','cstring'},{'playerName','cstring'},{'languageName','cstring'},{'channelName','cstring'},{'playerName2','cstring'},{'specialFlags','cstring'},{'zoneChannelID','number'},{'channelIndex','number'},{'channelBaseName','cstring'},{'languageID','number'},{'lineID','number'},{'guid','WOWGUID'},{'bnSenderID','number'},{'isMobile','bool'},{'isSubtitle','bool'},{'hideSenderInLetterbox','bool'},{'suppressRaidIcons','bool'},{'discordInfo','DiscordChatInfo'}},documentation='ChatInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['CHAT_MSG_GUILD_ACHIEVEMENT']={family='public',fields={{'text','cstring'},{'playerName','cstring'},{'languageName','cstring'},{'channelName','cstring'},{'playerName2','cstring'},{'specialFlags','cstring'},{'zoneChannelID','number'},{'channelIndex','number'},{'channelBaseName','cstring'},{'languageID','number'},{'lineID','number'},{'guid','WOWGUID'},{'bnSenderID','number'},{'isMobile','bool'},{'isSubtitle','bool'},{'hideSenderInLetterbox','bool'},{'suppressRaidIcons','bool'},{'discordInfo','DiscordChatInfo'}},documentation='ChatInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['loot']={status='NOT_TESTED',scope='manual watchlist or explicitly armed self'}
R.events['ENCOUNTER_LOOT_RECEIVED']={family='loot',fields={{'encounterID','number'},{'itemID','number'},{'itemLink','cstring'},{'quantity','number'},{'itemName','cstring'},{'fileName','cstring'}},documentation='LootDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['QUEST_LOOT_RECEIVED']={family='loot',fields={{'questID','number'},{'itemLink','cstring'},{'quantity','number'}},documentation='LootDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['QUEST_CURRENCY_LOOT_RECEIVED']={family='loot',fields={{'questID','number'},{'currencyId','number'},{'quantity','number'}},documentation='LootDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['START_LOOT_ROLL']={family='loot',fields={{'rollID','number'},{'rollTime','number'},{'lootHandle','number'}},documentation='LootDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['CANCEL_LOOT_ROLL']={family='loot',fields={{'rollID','number'}},documentation='LootDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['interaction']={status='NOT_TESTED',scope='manual watchlist or explicitly armed self'}
R.events['PARTY_INVITE_REQUEST']={family='interaction',fields={{'name','cstring'},{'isTank','bool'},{'isHealer','bool'},{'isDamage','bool'},{'isNativeRealm','bool'},{'allowMultipleRoles','bool'},{'inviterGUID','WOWGUID'},{'questSessionActive','bool'}},documentation='PartyInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['PARTY_INVITE_CANCEL']={family='interaction',fields={},documentation='PartyInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['TRADE_SHOW']={family='interaction',fields={},documentation='TradeInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['TRADE_CLOSED']={family='interaction',fields={},documentation='TradeInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['TRADE_ACCEPT_UPDATE']={family='interaction',fields={{'playerAccepted','number'},{'targetAccepted','number'}},documentation='TradeInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['DUEL_REQUESTED']={family='interaction',fields={{'playerName','cstring'}},documentation='DuelInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['DUEL_FINISHED']={family='interaction',fields={},documentation='DuelInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['guild']={status='NOT_TESTED',scope='manual watchlist or explicitly armed self'}
R.events['PLAYER_GUILD_UPDATE']={family='guild',fields={{'unitTarget','UnitTokenVariant'}},documentation='GuildInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['GUILD_ROSTER_UPDATE']={family='guild',fields={{'canRequestRosterUpdate','bool'}},documentation='GuildInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['social']={status='NOT_TESTED',scope='manual watchlist or explicitly armed self'}
R.events['FRIENDLIST_UPDATE']={family='social',fields={},documentation='FriendListDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['WHO_LIST_UPDATE']={family='social',fields={},documentation='FriendListDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['self_quest']={status='NOT_TESTED',scope='own-character only'}
R.events['QUEST_ACCEPTED']={family='self_quest',fields={{'questId','number'}},documentation='QuestLogDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['QUEST_LOG_UPDATE']={family='self_quest',fields={},documentation='QuestLogDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['QUEST_REMOVED']={family='self_quest',fields={{'questID','number'},{'wasReplayQuest','bool'}},documentation='QuestLogDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['QUEST_TURNED_IN']={family='self_quest',fields={{'questID','number'},{'xpReward','number'},{'moneyReward','number'}},documentation='QuestLogDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['self_progress']={status='NOT_TESTED',scope='own-character only'}
R.events['PLAYER_LEVEL_UP']={family='self_progress',fields={{'level','number'},{'healthDelta','number'},{'powerDelta','number'},{'numNewTalents','number'},{'numNewPvpTalentSlots','number'},{'strengthDelta','number'},{'agilityDelta','number'},{'staminaDelta','number'},{'intellectDelta','number'},{'spiritDelta','number'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['PLAYER_XP_UPDATE']={family='self_progress',fields={{'unitTarget','UnitTokenVariant'}},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['ACHIEVEMENT_EARNED']={family='self_progress',fields={{'achievementID','number'},{'alreadyEarned','bool'}},documentation='AchievementInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['SKILL_LINES_CHANGED']={family='self_progress',fields={},documentation='SkillInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['LEARNED_SPELL_IN_SKILL_LINE']={family='self_progress',fields={{'spellID','number'},{'skillLineIndex','luaIndex'},{'isGuildPerkSpell','bool'}},documentation='SpellBookDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['NEW_RECIPE_LEARNED']={family='self_progress',fields={{'recipeID','number'},{'recipeLevel','luaIndex'},{'baseRecipeID','number'}},documentation='TradeSkillUIDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['TRADE_SKILL_ITEM_CRAFTED_RESULT']={family='self_progress',fields={{'data','CraftingItemResultData'}},documentation='TradeSkillUIDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['UPDATE_FACTION']={family='self_progress',fields={},documentation='PaperDollInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['CURRENCY_DISPLAY_UPDATE']={family='self_progress',fields={{'currencyType','number'},{'quantity','number'},{'quantityChange','number'},{'quantityGainSource','number'},{'destroyReason','number'}},documentation='CurrencyInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['self_travel']={status='NOT_TESTED',scope='own-character only'}
R.events['ZONE_CHANGED']={family='self_travel',fields={},documentation='MapDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['ZONE_CHANGED_INDOORS']={family='self_travel',fields={},documentation='MapDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['HEARTHSTONE_BOUND']={family='self_travel',fields={},documentation='UnitDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['TAXIMAP_OPENED']={family='self_travel',fields={{'system','number'}},documentation='TaxiMapDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['TAXIMAP_CLOSED']={family='self_travel',fields={},documentation='TaxiMapDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['self_economy']={status='NOT_TESTED',scope='own-character only'}
R.events['PLAYER_MONEY']={family='self_economy',fields={},documentation='CurrencyInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['MAIL_SEND_SUCCESS']={family='self_economy',fields={},documentation='MailInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['MAIL_SUCCESS']={family='self_economy',fields={{'itemID','number'}},documentation='MailInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['AUCTION_HOUSE_AUCTION_CREATED']={family='self_economy',fields={{'auctionID','number'}},documentation='AuctionHouseDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.families['self_collection']={status='NOT_TESTED',scope='own-character only'}
R.events['NEW_MOUNT_ADDED']={family='self_collection',fields={{'mountID','number'}},documentation='MountJournalDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.events['NEW_PET_ADDED']={family='self_collection',fields={{'battlePetGUID','WOWGUID'}},documentation='PetJournalInfoDocumentation.lua',status='API_PRESENT_UNTESTED'}
R.apis={recentAllies='C_RecentAllies.GetRecentAllyByGUID',tooltip='C_TooltipInfo.GetUnit',friends='C_FriendList.GetFriendInfo',who='C_FriendList.GetWhoInfo',meter='C_DamageMeter.GetCombatSessionSourceFromID'}
-- Recent Allies is capability-gated Retail research, absent in the pinned Forever catalog.
R.events.RECENT_ALLY_DATA_UPDATED={family='social',fields={{'characterGUID','WOWGUID'}},capability='C_RecentAllies.GetRecentAllyByGUID',status='NOT_TESTED'}
R.events.RECENT_ALLIES_DATA_READY={family='social',fields={},capability='C_RecentAllies.GetRecentAllyByGUID',status='NOT_TESTED'}
for event,spec in pairs(R.events) do
    if event=='NAME_PLATE_UNIT_REMOVED' then
        spec.production='binding_only';spec.productionRule='Invalidates a unit binding; never proves a historical death, departure or location'
    elseif ns.ChronicleCapture.registered[event] then
        spec.production='conditional';spec.productionRule='Existing collector route; native readability, attribution, module and consent gates still apply'
    elseif spec.family:match('^self_') then
        spec.production='self_only_or_lab';spec.productionRule='Own-character source/candidate; cannot become a watched-other-player history record'
    else
        spec.production='lab_only';spec.productionRule='Research candidate only; no watched-player production collector is implemented for this event'
    end
end
