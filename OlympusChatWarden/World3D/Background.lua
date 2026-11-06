-- World-plane presentation behind the native actor scene. No database or world rendering hooks.
local _,ns=...
local B={};ns.Fireside3D.Background=B
local root='Interface\\AddOns\\OlympusChatWarden\\Media\\'
function B.New(viewport)
    local self={viewport=viewport,rows={}}
    viewport:SetClipsChildren(true)
    local backing=viewport:CreateTexture(nil,'BACKGROUND',nil,-8)
    backing:SetAllPoints();backing:SetColorTexture(.22,.48,.78,1)
    local sky=viewport:CreateTexture(nil,'BACKGROUND',nil,-7)
    sky:SetAllPoints();sky:SetTexture(root..'SharedSky84\\sky-day-0-0.tga')
    -- Include all visible sky content, excluding the source's unused transparent padding.
    sky:SetTexCoord(.004,.993,.004,.922)
    local skyRight=viewport:CreateTexture(nil,'BACKGROUND',nil,-7)
    skyRight:SetTexture(root..'SharedSky84\\sky-day-1-0.tga');skyRight:SetTexCoord(.004,.653,.004,.922)
    local clouds=viewport:CreateTexture(nil,'BACKGROUND',nil,-6)
    clouds:SetTexture(root..'World50\\a2-cloud-far-left-0-0.tga');clouds:SetTexCoord(0,1,0,344/512)
    clouds:SetPoint('TOPLEFT',0,0);clouds:SetPoint('TOPRIGHT',0,0)
    local fallback=viewport:CreateTexture(nil,'BACKGROUND',nil,-5)
    fallback:SetColorTexture(.20,.29,.12,1);fallback:SetPoint('BOTTOMLEFT');fallback:SetPoint('BOTTOMRIGHT')
    -- Small horizontal strips approximate the ground's perspective UV interpolation.
    -- They never sort native actors or claim native ground-mesh depth/triangle collision.
    for i=1,128 do
        local under=viewport:CreateTexture(nil,'ARTWORK',nil,0);under:SetColorTexture(.20,.29,.12,1)
        local texture=viewport:CreateTexture(nil,'ARTWORK',nil,1)
        texture:SetTexture(root..'World3D\\Grass.tga','REPEAT','REPEAT','LINEAR')
        under:Hide();texture:Hide()
        self.rows[i]={texture=texture,under=under}
    end
    function self:SetLighting(state)
        if self.skyState==state then return end;self.skyState=state
        sky:SetTexture(root..'SharedSky84\\sky-'..state..'-0-0.tga');skyRight:SetTexture(root..'SharedSky84\\sky-'..state..'-1-0.tga')
        local c=state=='night'and{.06,.08,.16}or state=='dusk'and{.38,.25,.36}or state=='dawn'and{.58,.48,.54}or{.22,.48,.78}
        backing:SetColorTexture(c[1],c[2],c[3],1);clouds:SetVertexColor(state=='night'and .25 or 1,state=='night'and .3 or 1,state=='night'and .4 or 1,1)
    end
    function self:Update(frame,shot)
        local w,h=viewport:GetWidth(),viewport:GetHeight()
        if w<1 or h<1 then return end
        local size=w..':'..h..':'..viewport:GetEffectiveScale()
        if self.size~=size then
            self.size=size;self.warm=false;self.pending=nil;self.drawKey=nil
            sky:ClearAllPoints();sky:SetPoint('TOPLEFT');sky:SetSize(w*1013/1672,h)
            skyRight:ClearAllPoints();skyRight:SetPoint('TOPRIGHT');skyRight:SetSize(w*665/1672,h)
            clouds:SetHeight(h*.48);fallback:SetHeight(h*.5);fallback:Show()
            for _,row in ipairs(self.rows)do row.texture:Hide();row.under:Hide()end
        end
        local map,why,sampleKey=ns.Fireside3D.Coordinates.FloorMap(frame,shot)
        if not map then
            self.registration=why or'Waiting for native ground projection'
            -- A late native camera/viewport cache must not flash the whole
            -- grass layer off after a usable projection has been displayed.
            return
        end
        sampleKey=sampleKey or tostring(map)
        if not self.warm then
            if self.pending~=sampleKey then self.pending=sampleKey;self.registration='Waiting for stable native grass projection';return end
            self.warm=true
        end
        self.registration='Stable native world Z=0 projection'
        if self.drawKey==sampleKey and self.allTexturesReady then return end
        self.drawKey=sampleKey;self.allTexturesReady=true;fallback:Hide()
        local count=#self.rows
        for i,row in ipairs(self.rows) do
            -- Integer screen rows avoid subpixel gaps/overlap between strips.
            local y0=math.floor(h*(i-1)/count+.5);local y1=math.floor(h*i/count+.5)
            local a,b=y0/h,y1/h
            local x1,y1,x2,y2,x3,y3,x4,y4
            if map then x1,y1=map(0,a);x2,y2=map(1,a);x3,y3=map(0,b);x4,y4=map(1,b) end
            if b>a and x1 and x2 and x3 and x4 then
                for _,t in ipairs({row.under,row.texture}) do
                    t:ClearAllPoints();t:SetPoint('TOPLEFT',viewport,'TOPLEFT',0,-a*h)
                    t:SetSize(w,(b-a)*h)
                end
                -- Keep UVs near zero without changing repetition phase (4 world units/tile).
                local ox,oy=math.floor(x1/4),math.floor(y1/4)
                row.texture:SetTexCoord(x1/4-ox,y1/4-oy,x3/4-ox,y3/4-oy,x2/4-ox,y2/4-oy,x4/4-ox,y4/4-oy)
                row.under:Show()
                local ready=not row.texture.IsObjectLoaded or row.texture:IsObjectLoaded()
                row.texture:SetShown(ready==true)
                if not ready then self.allTexturesReady=false end
            else row.texture:Hide();row.under:Hide() end
        end
    end
    return self
end
