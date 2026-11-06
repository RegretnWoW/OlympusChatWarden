-- Isolated addon namespace; no production addon, saved roots, collectors or transport.
local _, ns = ...
local N = ns.WardenNativeScene
local sin, cos, pi = math.sin, math.cos, math.pi
local function clamp(n, a, b) return math.max(a, math.min(b, n)) end
local candidates = {
    {190430, 'Swamp water hut', 'world/azeroth/swamposorrow/passivedoodads/waterhuts/waterhut01.m2'},
    {191492, 'Ogrila hut', 'world/expansion01/doodads/bladesedge/ogrila/ogrilahut/ogrila_hut.m2'},
    {106965, 'Human farmhouse (WMO probe)', 'world/wmo/azeroth/buildings/human_farm/farm.wmo'},
}
local window, engine, house, player, furniture, background, chair, interaction, scene
local navigation, clickChair
local keys, dragging, active = {}, false, false
local index, yaw, pitch, distance, houseFloor = 1, -pi / 2, .35, 18, 0
local status, message, orbitX, orbitY, halfX, halfY
local shot = {position={0,-20,10}, target={0,0,1}, fov=.85}
local function say(s) print('|cffedbc67Fireside 3D:|r '..s) end
local function clearInput()
    keys = {}; dragging = false
    if window then window:SetPropagateKeyboardInput(true) end
end
local function text(s) message=s; if status then status:SetText(s) end end
local function visibleActor(a) N.Call(a.actor, 'SetAlpha', 1) end
local function placeHouse()
    if house and house.ready then engine:Place(house,0,0,-houseFloor,0) end
end
local function camera()
    local p = active and player and player.ready and player.position or {0,0,0}
    local x,y,z = N.World(shot,p[1],p[2],p[3]+1.3)
    local horizontal = distance*cos(pitch)
    local view={position={x-horizontal*cos(yaw),y-horizontal*sin(yaw),math.max(.4,z+distance*sin(pitch))},target={x,y,z},fov=.85}
    if not N.ViewCamera(engine,view) then active=false; clearInput(); text('Camera API rejected. Stop: this client cannot run the experiment.');return end
    if background then background:Update(engine.frame,shot) end
end
local function probe()
    active=false; clearInput(); houseFloor=0; halfX=nil; halfY=nil
    house=nil; player=nil; furniture=nil; chair=nil; interaction=nil; scene=nil
    if engine and engine.frame then engine:Show(false) end
    if index>#candidates then
        text('STOP: all three house candidates exhausted. No usable house confirmed. /fs3d report'); return
    end
    -- Retire the previous scene, keeping only one visible house; at most three scenes per session.
    engine=N.Create(window.viewport,shot)
    if engine.unsupported then text('STOP: '..engine.unsupported); return end
    ns.ExperimentWorldSpace.Bind(engine)
    engine.onReady=function(a)
        visibleActor(a)
        if a.id=='house' then
            halfX=(a.bounds[4]-a.bounds[1])*a.scale/2
            halfY=(a.bounds[5]-a.bounds[2])*a.scale/2
            distance=math.max(18,math.max(halfX,halfY)*3)
            placeHouse()
            text(candidates[index][2]..' loaded bounds; VISUAL UNVERIFIED. Right-drag to orbit. /fs3d accept if a real usable house is visible; /fs3d next if not.')
        end
    end
    for _,method in ipairs({'SetLightAmbientColor','SetLightDiffuseColor'}) do N.Call(engine.frame,method,.8,.8,.8) end
    N.Call(engine.frame,'SetLightDirection',-.5,-.5,-1)
    house=engine:Add({id='house',fileID=candidates[index][1],width=12,at={0,0,0},yaw=0})
    player=nil; furniture=nil
    text('Requesting '..candidates[index][2]..' ('..candidates[index][1]..'). No visual result yet.')
end
local function accept()
    if active then return end
    if not engine or not engine.frame or not house or not house.ready or house.failed then say('Wait for a loaded house. Use /fs3d next if it fails.'); return end
    -- Explicit human observation, never inferred from IsLoaded/bounds.
    house.visualConfirmed=true
    furniture=engine:Add({id='table',fileID=198603,height=.9,at={0,0,0},yaw=0})
    chair=engine:Add({id='chair',fileID=198114,height=1.55,seatFraction=.29,seatHeightOffset=.3,interaction='chair',at={-3,-halfY-2,0},yaw=0})
    -- Same BodyDisplay/appearance/native actor path used by Fireside's scenic people.
    -- These are generic demo NPCs, not captures of any real player.
    engine:Add({id='npc-inside',appearance={raceID=1,sex=2},height=1.8,at={-halfX*.55,halfY*.55,0},yaw=pi,animations={0,4},appearanceSource='Generic demo NPC'})
    engine:Add({id='npc-outside',appearance={raceID=1,sex=3},height=1.8,at={3,-halfY-2,0},yaw=pi,animations={0,4},appearanceSource='Generic demo NPC'})
    player=engine:Add({id='player',unit='player',controlled=true,height=1.85,at={0,-halfY-4,0},yaw=0,animations={0,4,102,103,104}})
    interaction,scene=ns.ExperimentInteractions.Bind(engine,shot,navigation)
    engine.onRouteEnd=function(a)
        if a==player and a.pendingInteraction then
            local intent=a.pendingInteraction;a.pendingInteraction=nil
            local yes=interaction:SeatPlayer(scene,a,intent)
            if not yes then say(a.motionStatus or 'Seat unavailable') end
        end
    end
    engine.onRouteBlocked=function(a) if a==player then a.pendingInteraction=nil;say(a.motionStatus or 'Chair approach blocked') end end
    active=true; distance=12
    text('WASD while pointer is inside viewport; right-drag orbit/pitch; wheel zoom. Left-click chair to approach/sit; WASD stands up. /fs3d report. Solid house collision; /fs3d interior enables approximate doorway trial.')
end
local interior=false
local function obstacles()
    local rows={}
    if not interior then rows[1]={id='house',left=-halfX,right=halfX,near=-halfY,far=halfY}
    else
        -- Explicit approximation only; ModelScene exposes no walkable WMO/M2 triangle mesh.
        local t=.25; local door=1.1
        rows={{id='left wall',left=-halfX,right=-halfX+t,near=-halfY,far=halfY},
            {id='right wall',left=halfX-t,right=halfX,near=-halfY,far=halfY},
            {id='rear wall',left=-halfX,right=halfX,near=halfY-t,far=halfY},
            {id='front left',left=-halfX,right=-door,near=-halfY,far=-halfY+t},
            {id='front right',left=door,right=halfX,near=-halfY,far=-halfY+t}}
    end
    if furniture and furniture.ready then rows[#rows+1]=N.Footprint(shot,furniture) end
    if chair and chair.ready then rows[#rows+1]=N.Footprint(shot,chair) end
    return rows
end
navigation=function(a)
    return N.PeopleNavigation({ground=true,continuous=true,floor=0,radius=.3,boundary={-24,-24,24,24},obstacles=obstacles()},engine,a)
end
clickChair=function()
    if not active or not player or not player.ready or not chair or not chair.ready then return end
    local x,y=GetCursorPosition();local scale=window.viewport:GetEffectiveScale()
    local u=(x/scale-window.viewport:GetLeft())/window.viewport:GetWidth()
    local v=(window.viewport:GetTop()-y/scale)/window.viewport:GetHeight()
    local C=ns.WardenSceneObjectControls
    if not C.ContainsPick(C.ProjectPick(engine,shot,chair),u,v) then return end
    if player.seating then if player.seating.phase~='leaving' then interaction:LeavePlayerSeat(scene,player) end;return end
    -- Clicking the same target twice must not restart its native walk animation.
    if player.pendingInteraction then return end
    local yes,why=interaction:InteractPlayer(scene,'chair')
    if not yes then say(why) end
end
local function move(dt)
    if not active or not player or not player.ready then return end
    if not (house.ready and furniture and furniture.ready) then return end
    local forward=(keys.W and 1 or 0)-(keys.S and 1 or 0)
    local right=(keys.D and 1 or 0)-(keys.A and 1 or 0)
    local length=math.sqrt(forward*forward+right*right)
    local moved=false
    if player.seating then
        if length>0 and player.seating.phase~='leaving' then interaction:LeavePlayerSeat(scene,player) end
        interaction:UpdatePlayerSeat(scene,player,dt)
        return
    end
    if length>0 then player.route=nil;player.pendingInteraction=nil
    elseif player.route then return end
    if length>0 then
        -- N.World's fixed shot maps authored right/depth to native X/Y. Camera changes never alter this basis.
        local dx=(cos(yaw)*forward+sin(yaw)*right)/length*4*dt
        local dy=(sin(yaw)*forward-cos(yaw)*right)/length*4*dt
        local p=player.position
        local nav=navigation(player)
        -- Sweep rather than endpoint-only collision. Existing collision code samples at <= .05 units.
        local path={samples={{x=p[1],y=p[2],z=0},{x=p[1]+dx,y=p[2]+dy,z=0}}}
        if N.CheckPath(path,nav) and N.CanStep(engine,player,p,{p[1]+dx,p[2]+dy,0}) then
            engine:Place(player,p[1]+dx,p[2]+dy,0,math.atan2(dy,dx)); moved=true
        end
    end
    engine:Animate(player,moved and 4 or 0,1)
end
local function create()
    window=CreateFrame('Frame','Fireside3DExperimentWindow',UIParent)
    window:SetSize(1000,700); window:SetPoint('CENTER'); window:SetFrameStrata('DIALOG')
    window:EnableMouse(true); window:EnableKeyboard(true); window:SetPropagateKeyboardInput(true)
    local bg=window:CreateTexture(nil,'BACKGROUND'); bg:SetAllPoints(); bg:SetColorTexture(.04,.05,.07,1)
    status=window:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
    status:SetPoint('TOPLEFT',12,-12); status:SetPoint('TOPRIGHT',-48,-12); status:SetHeight(52); status:SetJustifyH('LEFT')
    local close=CreateFrame('Button',nil,window,'UIPanelCloseButton'); close:SetPoint('TOPRIGHT'); close:SetScript('OnClick',function() window:Hide() end)
    window.viewport=CreateFrame('Frame',nil,window); window.viewport:SetPoint('TOPLEFT',8,-70); window.viewport:SetPoint('BOTTOMRIGHT',-8,8)
    background=ns.ExperimentBackground.New(window.viewport)
    window.viewport:EnableMouse(true); window.viewport:EnableMouseWheel(true)
    window.viewport:SetScript('OnMouseDown',function(_,button) if button=='RightButton' then dragging=true; orbitX,orbitY=GetCursorPosition() elseif button=='LeftButton' then clickChair() end end)
    window.viewport:SetScript('OnMouseUp',function() dragging=false end)
    window.viewport:SetScript('OnMouseWheel',function(_,delta) distance=clamp(distance-delta,2,70) end)
    window.viewport:SetScript('OnLeave',clearInput)
    window:SetScript('OnHide',function() clearInput(); if player and player.route then player.route=nil;player.pendingInteraction=nil;engine:Animate(player,0,1) end; if engine and engine.frame then engine:Show(false) end end)
    window:SetScript('OnKeyDown',function(_,key)
        if key=='ESCAPE' then clearInput(); window:Hide(); return end
        local capture=active and window.viewport:IsMouseOver() and (key=='W' or key=='A' or key=='S' or key=='D') and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()) and not InCombatLockdown()
        window:SetPropagateKeyboardInput(not capture)
        if capture then keys[key]=true end
    end)
    window:SetScript('OnKeyUp',function(_,key) local held=keys[key]; keys[key]=nil; window:SetPropagateKeyboardInput(not held) end)
    window:RegisterEvent('PLAYER_REGEN_DISABLED'); window:SetScript('OnEvent',function() window:Hide() end)
    window:SetScript('OnUpdate',function(_,elapsed)
        if not engine or not engine.frame or index>#candidates then return end
        local dt=clamp(elapsed,0,.05)
        engine:Tick(dt,true)
        if house and house.failed then text('House request FAILED: '..house.status..'. /fs3d next (maximum three candidates).') end
        if dragging then
            if not IsMouseButtonDown('RightButton') then dragging=false
            else local x,y=GetCursorPosition(); yaw=(yaw-(x-orbitX)*.006)%(2*pi); pitch=clamp(pitch+(y-orbitY)*.006,-.3,1.2); orbitX,orbitY=x,y end
        end
        if not window.viewport:IsMouseOver() or (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()) then clearInput() end
        move(dt); camera()
    end)
    probe()
end
SLASH_FIRESIDE3DEXPERIMENT1='/fs3d'
SlashCmdList.FIRESIDE3DEXPERIMENT=function(input)
    if InCombatLockdown() then say('Open outside combat.'); return end
    local command,arg=(input or ''):match('^(%S*)%s*(.-)$')
    if not window then create() end
    if command=='report' then
        say('World-space scene v0.3.1; base 9bc2326f67532c548102caa831b20af2234d6bfe; candidate '..index..'; visual house confirmation='..tostring(house and house.visualConfirmed==true))
        if index<=#candidates then say(candidates[index][1]..' '..candidates[index][3]) end
        for _,a in ipairs(engine and engine.order or {}) do say(a.id..': '..a.status..'; world='..(a.position and table.concat(a.position,',') or 'none')..'; scale='..tostring(a.scale)..'; bounds='..(a.bounds and table.concat(a.bounds,',') or 'none')) end
        say('Coordinates=world XYZ; camera-only perspective; legacy corrections/shadows disabled; ground='..(background and background.registration or 'unavailable'))
        if player then say('Chair state='..(player.seating and player.seating.phase or player.pendingInteraction and 'approaching' or 'free')..'; sit supported='..tostring(player.capabilities[102] or player.capabilities[103] or player.capabilities[104] or false)) end
        say('Sky+wood ground; interior trial='..tostring(interior)..'; house floor offset='..houseFloor..'; rendered appearance/depth require human inspection.')
    elseif command=='next' then index=index+1; interior=false; probe()
    elseif command=='accept' then accept()
    elseif command=='interior' and active then interior=not interior; say('Approximate front doorway collision='..tostring(interior)..'. Not native mesh collision. Verify alignment visually.')
    elseif command=='floor' then
        local n=tonumber(arg)
        if n and n==n and math.abs(n)<=15 then houseFloor=n; placeHouse(); say('House lowered by '..n..' units; align the real interior floor with the table and walking plane.') end
    elseif command~='' then say('/fs3d; accept; next; interior; floor <units>; report') end
    window:Show(); if engine and engine.frame and index<=#candidates then engine:Show(true) end
end
