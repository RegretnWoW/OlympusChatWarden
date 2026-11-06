-- World-plane presentation behind the native actor scene. No database or world rendering hooks.
local _,ns=...
local B={};ns.ExperimentBackground=B
local root='Interface\\AddOns\\Fireside3DExperiment\\Media\\'
function B.New(viewport)
    local self={viewport=viewport,rows={}}
    viewport:SetClipsChildren(true)
    local backing=viewport:CreateTexture(nil,'BACKGROUND',nil,-8)
    backing:SetAllPoints();backing:SetColorTexture(.22,.48,.78,1)
    local sky=viewport:CreateTexture(nil,'BACKGROUND',nil,-7)
    sky:SetAllPoints();sky:SetTexture(root..'Sky.tga')
    -- Include all visible sky content, excluding the source's unused transparent padding.
    sky:SetTexCoord(0,1,0,239/1024)
    local clouds=viewport:CreateTexture(nil,'BACKGROUND',nil,-6)
    clouds:SetTexture(root..'Clouds.tga');clouds:SetTexCoord(0,1,0,344/512)
    clouds:SetPoint('TOPLEFT',0,0);clouds:SetPoint('TOPRIGHT',0,0)
    -- Small horizontal strips approximate the ground's perspective UV interpolation.
    -- They never sort native actors or claim native ground-mesh depth/triangle collision.
    for i=1,128 do
        local under=viewport:CreateTexture(nil,'ARTWORK',nil,0);under:SetColorTexture(.27,.19,.11,1)
        local texture=viewport:CreateTexture(nil,'ARTWORK',nil,1)
        texture:SetTexture(root..'Ground.tga','REPEAT','REPEAT','LINEAR')
        self.rows[i]={texture=texture,under=under}
    end
    function self:Update(frame,shot)
        local w,h=viewport:GetWidth(),viewport:GetHeight()
        if w<1 or h<1 then return end
        clouds:SetHeight(h*.48)
        local map,why=ns.ExperimentWorldSpace.FloorMap(frame,shot)
        self.registration=map and 'native world Z=0 projection' or why
        local top=0
        local count=#self.rows
        for i,row in ipairs(self.rows) do
            local a=top+(1-top)*(i-1)/count;local b=top+(1-top)*i/count
            local x1,y1,x2,y2,x3,y3,x4,y4
            if map then x1,y1=map(0,a);x2,y2=map(1,a);x3,y3=map(0,b);x4,y4=map(1,b) end
            if top<1 and x1 and x2 and x3 and x4 then
                for _,t in ipairs({row.under,row.texture}) do
                    t:ClearAllPoints();t:SetPoint('TOPLEFT',viewport,'TOPLEFT',0,-a*h)
                    t:SetSize(w,(b-a)*h);t:Show()
                end
                -- Keep UVs near zero without changing repetition phase (4 world units/tile).
                local ox,oy=math.floor(x1/4),math.floor(y1/4)
                row.texture:SetTexCoord(x1/4-ox,y1/4-oy,x3/4-ox,y3/4-oy,x2/4-ox,y2/4-oy,x4/4-ox,y4/4-oy)
            else row.texture:Hide();row.under:Hide() end
        end
    end
    return self
end
