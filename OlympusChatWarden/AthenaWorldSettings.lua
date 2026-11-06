-- Original, brief setting prose. Static landscape/history is not live weather.
local _,ns=...
local W={VERSION='settings-8.1'};ns.AthenaWorldSettings=W
local manual='https://assets.blz-contentstack.com/v3/assets/blt3452e3b114fab0cd/blt2e9295db02a222fc/6025bcbb6968b53d529edb2a/media_manual_classic_enUS.pdf'
local cards={
    ['Ashenvale']={page=83,body='Ashenvale’s ancient forest had sheltered the night elves through long ages. War had broken that seclusion: the Warsong clan and the Legion had both left their mark upon its history. Beneath its boughs, the affairs of a single traveler belonged to a much older tale.'},
    ['Elwynn Forest']={page=87,body='Stormwind stood at the foothills of Elwynn, a surviving bastion of humanity after the wars that had broken other kingdoms. Around that refuge, the smaller affairs of a life could begin to take their own shape.'},
    ['Durotar']={page=96,body='Durotar was a harsh homeland, claimed by the orcs after their passage to Kalimdor. Within its canyons, Orgrimmar stood for a future no longer ruled by the old demonic curse.'},
}
function W.Get(name,environment)
    local c=cards[name];if not c then return nil end
    return {title=name,body=c.body,worldRef='world:'..W.VERSION..'/'..name,sourceURL=manual,sourcePage=c.page,
        sourceVersion=W.VERSION,kind='WORLD_HISTORY',era='FOREVER_START',confidence='SOURCE_SUPPORTED_SETTING',
        observedWeather=false,personalExperienceProven=false}
end
function W.Bridge(identity,place)
    local name=ns.AthenaStoryPlanner.Text(identity and identity.name,'This adventurer');local where=ns.AthenaStoryPlanner.Text(place)
    if not name then return nil end
    -- An authorial shift of scale; no invented childhood, memory or destiny.
    return 'The great struggles had left their mark upon the world. '..(where and ('In '..where..', ') or '')..name..'’s own story takes its place among the lives that followed.'
end
