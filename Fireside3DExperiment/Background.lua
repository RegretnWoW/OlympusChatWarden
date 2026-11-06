-- Presentation behind the unchanged native actor scene. No database or world rendering hooks.
local _,ns=...
local B={};ns.ExperimentBackground=B
local root='Interface\\AddOns\\Fireside3DExperiment\\Media\\'
local function basis(view)
    local p,t=view.position,view.target
    local x,y,z=t[1]-p[1],t[2]-p[2],t[3]-p[3]
    local length=math.sqrt(x*x+y*y+z*z);x,y,z=x/length,y/length,z/length
    local h=math.sqrt(x*x+y*y)
    return {x,y,z},{y/h,-x/h,0},{-z*x/h,-z*y/h,h}
end
-- Inverse of WardenNativeScene.Project for the same shot/FOV/aspect, intersecting Z=0.
-- This is only a textured presentation plane; actors keep their native shared depth buffer.
function B.GroundPoint(view,u,v,aspect)
    local f,r,up=basis(view);local lens=math.tan(view.fov*.5)
    local sx,sy=(2*u-1)*lens*aspect,(1-2*v)*lens
    local dx,dy,dz=f[1]+r[1]*sx+up[1]*sy,f[2]+r[2]*sx+up[2]*sy,f[3]+up[3]*sy
    if dz>=-1e-6 or view.position[3]<=0 then return end
    local distance=-view.position[3]/dz
    return view.position[1]+dx*distance,view.position[2]+dy*distance
end
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
    function self:Update(view)
        local w,h=viewport:GetWidth(),viewport:GetHeight()
        if w<1 or h<1 then return end
        clouds:SetHeight(h*.48)
        local f,_,up=basis(view)
        local horizon=(1+f[3]/(up[3]*math.tan(view.fov*.5)))*.5
        local top=math.max(0,horizon+.008)
        local count=#self.rows
        for i,row in ipairs(self.rows) do
            local a=top+(1-top)*(i-1)/count;local b=top+(1-top)*i/count
            local x1,y1=B.GroundPoint(view,0,a,w/h);local x2,y2=B.GroundPoint(view,1,a,w/h)
            local x3,y3=B.GroundPoint(view,0,b,w/h);local x4,y4=B.GroundPoint(view,1,b,w/h)
            if top<1 and x1 and x2 and x3 and x4 then
                for _,t in ipairs({row.under,row.texture}) do
                    t:ClearAllPoints();t:SetPoint('TOPLEFT',viewport,'TOPLEFT',0,-a*h)
                    t:SetSize(w,(b-a)*h+.25);t:Show()
                end
                -- Keep UVs near zero without changing repetition phase (4 world units/tile).
                local ox,oy=math.floor(x1/4),math.floor(y1/4)
                row.texture:SetTexCoord(x1/4-ox,y1/4-oy,x3/4-ox,y3/4-oy,x2/4-ox,y2/4-oy,x4/4-ox,y4/4-oy)
            else row.texture:Hide();row.under:Hide() end
        end
    end
    return self
end
