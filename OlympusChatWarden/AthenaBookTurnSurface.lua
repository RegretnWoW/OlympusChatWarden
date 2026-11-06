-- Curved paper and ink share explicit projected quads. No animation-group state,
-- inherited child transforms, scroll clipping or per-frame text reflow is involved.
local _,ns=...
local S={VERSION=2};ns.AthenaBookTurnSurface=S
local PI=math.pi
local PAPER='Interface\\AddOns\\OlympusChatWarden\\Media\\Journal3\\Paper.tga'
local TYPE='Interface\\AddOns\\OlympusChatWarden\\Media\\JournalType\\'
local colors={body={.105,.065,.035},quote={.105,.065,.035},title={.23,.105,.035},heading={.27,.13,.045},meta={.28,.22,.16},accent={.10,.29,.40}}
local TL,BL,TR,BR=UPPER_LEFT_VERTEX or 1,LOWER_LEFT_VERTEX or 2,UPPER_RIGHT_VERTEX or 3,LOWER_RIGHT_VERTEX or 4
local function Characters(text)
    local out={}
    for ch in text:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
        local a,b,c,d=ch:byte(1,4);local cp=a
        if a>=240 then cp=(a-240)*262144+(b-128)*4096+(c-128)*64+d-128
        elseif a>=224 then cp=(a-224)*4096+(b-128)*64+c-128
        elseif a>=192 then cp=(a-192)*64+b-128 end
        out[#out+1]={text=ch,cp=cp}
    end
    return out
end
function S.Advance(text,size,kind)
 local face=(kind=='title'or kind=='heading')and'bold'or'regular';local glyphs=ns.JournalGlyphs.styles[face];local width=0
 for _,ch in ipairs(Characters(text or''))do local g=glyphs[ch.cp];width=width+(g and g[7]*size/ns.JournalGlyphs.size or size)end;return width
end
-- Pagination, document boxes and visible ink must share these exact word/glyph
-- breaks. Client FontString metrics can be narrower than the letter atlas.
local function WalkText(text,size,maxWidth,kind,emit)
 text=(text or ''):gsub('||','|')
 local style=(kind=='title' or kind=='heading')and'bold'or'regular'
 local glyphs=ns.JournalGlyphs.styles[style];local factor=size/ns.JournalGlyphs.size
 local atX,atY,bottom,wordIndex=0,0,0,0
 local function Advance(chars)
  local w=0;for _,ch in ipairs(chars)do local g=glyphs[ch.cp];w=w+(g and g[7]*factor or size)end;return w
 end
 local function Emit(chars)
  for _,ch in ipairs(chars)do
   local g=glyphs[ch.cp]
   bottom=math.max(bottom,atY+(g and size*.94+(g[6]+g[4])*factor or size))
   if emit then emit(ch,g,atX,atY,wordIndex,style,factor)end
   atX=atX+(g and g[7]*factor or size)
  end
 end
 for line in (text..'\n'):gmatch('(.-)\n')do
  for spaces,word in line:gmatch('(%s*)(%S+)')do
   wordIndex=wordIndex+1
   local spaceChars,chars=Characters(spaces),Characters(word)
   local sw,ww=Advance(spaceChars),Advance(chars)
   if atX>0 and atX+sw+ww>maxWidth then atX=0;atY=atY+size+3;sw=0 end
   if atX>0 then atX=atX+sw end
   if ww>maxWidth then
    for _,ch in ipairs(chars)do local cw=Advance({ch});if atX>0 and atX+cw>maxWidth then atX=0;atY=atY+size+3 end;Emit({ch})end
   else Emit(chars)end
  end
  atX=0;atY=atY+size+3
 end
 return math.max(bottom,atY)
end
function S.TextHeight(text,size,width,kind)return WalkText(text,size,width,kind)end
function S.New(parent)
    local self={faces={},pool={},used=0,buckets={},parent=parent}
    for i=1,16 do local f=CreateFrame('Frame',nil,parent);f:SetAllPoints(parent);f:SetFrameLevel(parent:GetFrameLevel()+i);self.buckets[i]=f end
    function self:Clear()
        for _,entry in ipairs(self.pool) do entry.region:Hide();if entry.fallback then entry.fallback:Hide() end end
        self.used=0;self.faces={};self.quads={}
    end
    local function Entry(face,kind,x,y,w,h,path,uv,color)
        self.used=self.used+1;local item=self.pool[self.used]
        if not item then item={region=self.buckets[1]:CreateTexture(nil,'ARTWORK')};self.pool[self.used]=item end
        item.face,item.kind,item.x,item.y,item.w,item.h=face,kind,x,y,w,h
        item.inkBlock=self.emissionBlock;item.inkWord=self.emissionWord;item.revealShown=nil
        item.alpha=1;item.points=nil;item.path,item.uv,item.color=path,uv,color or {1,1,1}
        if ns.AthenaBookMotion then ns.AthenaBookMotion.NoteTexture()end
        item.region:SetTexture(path,'CLAMP','CLAMP','LINEAR');item.region:SetTexCoord(unpack(uv));item.region:SetDrawLayer(kind=='paper' and 'BACKGROUND' or 'ARTWORK');item.region:Hide()
        if item.region.SetSnapToPixelGrid then item.region:SetSnapToPixelGrid(false);item.region:SetTexelSnappingBias(0) end
        return item
    end
    function self:AddArtwork(face,x,y,w,h,art)
        local item=Entry(face,'illustration',x,y,w,h,art.path,art.uv or {0,1,0,1});item.alpha=art.alpha or 1;return item
    end
    function self:AddText(face,text,x,y,size,maxWidth,kind,tone)
        local color=colors[tone or kind] or colors.body
        return WalkText(text,size,maxWidth,kind,function(ch,g,atX,atY,wordIndex,style,factor)
                self.emissionWord=wordIndex
                if not g then
                    -- Preserve unsupported scripts with the client's alphabet-aware
                    -- font instead of replacing or silently dropping their text.
                    local item=Entry(face,'fallback',x+atX,y+atY,size,size,nil,{0,1,0,1},color)
                    if not item.fallback then item.fallback=self.buckets[1]:CreateFontString(nil,'ARTWORK') end
                    ns.Theme.ReaderFont(item.fallback,size,kind,'paper');item.fallback:SetTextColor(unpack(color));item.fallback:SetText(ch.text)
                    item.region:Hide();item.fallback:Hide()
                else
                    if ch.cp~=32 and ch.cp~=160 and ch.cp~=9 then
                        Entry(face,'ink',x+atX+g[5]*factor,y+atY+size*.94+g[6]*factor,g[3]*factor,g[4]*factor,
                            TYPE..style..'.tga',{g[1]/2048,(g[1]+g[3])/2048,g[2]/2048,(g[2]+g[4])/2048},color)
                    end
                end
        end)
    end
    function self:AddFace(face,document,config)
        self.faces[face]=config
        local half,h=config.half,config.height
        -- Many narrow strips allow a continuous bend; both faces can be visible
        -- at once around the curled fold instead of vanishing at the midpoint.
        local left=config.rightSide and .5 or .045;local right=config.rightSide and .955 or .5
        local bw,bh=self.parent:GetWidth(),self.parent:GetHeight()
        local function paperUV(s,v)
            local u=config.rightSide and s or 1-s;local spine,pw,top,ph=ns.AthenaBookScene.PageGeometry(bw,bh)
            local x=spine+(config.rightSide and 1 or -1)*pw*u
            local y=top+bh*.03*(1-u)^2+v*(ph-bh*.03*(1-u)^2-bh*.03*u*u)
            x,y=ns.AthenaBookScene.Project(x,y,bw,bh);return x/bw,y/bh
        end
        for i=0,config.onlyInk and -1 or 63 do local x0,x1=i/64,(i+1)/64
            local a,b=paperUV(x0,0);local c,d=paperUV(x0,1);local e,f=paperUV(x1,0);local g,k=paperUV(x1,1)
            Entry(face,'paper',half*x0,0,half*(x1-x0)+.15,h,ns.AthenaBookScene.Path('OpenBook'),{a,b,c,d,e,f,g,k})
            Entry(face,'edge',half*x0,-.35,half*(x1-x0)+.15,.9,'Interface\\Buttons\\WHITE8X8',{0,1,0,1},{.64,.46,.24})
            Entry(face,'edge',half*x0,h-.4,half*(x1-x0)+.15,1.25,'Interface\\Buttons\\WHITE8X8',{0,1,0,1},{.55,.37,.18})
        end
        -- Preserve the rendered outgoing sheet even if its document changed
        -- before the scheduled ink painter. Reuse the same projected quads.
        local snapshot=config.snapshot
        if snapshot and snapshot.used>0 then
            for i=1,snapshot.used do local old=snapshot.pool[i]
                if old.kind~='paper' and old.kind~='edge' and old.revealShown~=false then
                    local item=Entry(face,old.kind,old.x,old.y,old.w,old.h,old.path,old.uv,old.color)
                    item.alpha=old.alpha or 1;item.inkBlock,item.inkWord=old.inkBlock,old.inkWord;item.points=old.points
                    if old.fallback then
                        if not item.fallback then item.fallback=self.buckets[1]:CreateFontString(nil,'ARTWORK')end
                        local font,size,flags=old.fallback:GetFont();if font then item.fallback:SetFont(font,size,flags)end
                        item.fallback:SetText(old.fallback:GetText());item.fallback:SetTextColor(unpack(old.color));item.fallback:Hide()
                    end
                end
            end
            return
        end
        local _,_,paperTop=ns.AthenaBookScene.PageGeometry(self.parent:GetWidth(),self.parent:GetHeight())
        local y=math.max(16,self.parent:GetHeight()*.22-paperTop)
        for i,block in ipairs(document.blocks or {}) do
            self.emissionBlock=i;self.emissionWord=0
            local box=document.boxes and document.boxes[i]
            if block.doodle and ns.WardenDrawing then
                local model=ns.WardenDrawing.Decode(block.doodle)
                if model then
                    local dw=math.min(config.textWidth,380);local dh=dw/2
                    for _,stroke in ipairs(model.strokes)do for n=1,math.max(1,#stroke.points-1)do
                        local a,b=stroke.points[n],stroke.points[math.min(n+1,#stroke.points)]
                        local x1,y1=config.inset+a[1]*dw/255,y+dh-a[2]*dh/255
                        local x2,y2=config.inset+b[1]*dw/255,y+dh-b[2]*dh/255
                        local dx,dy=x2-x1,y2-y1;if dx==0 and dy==0 then x2=x2+.1;dx=.1 end
                        local len=math.max(.1,math.sqrt(dx*dx+dy*dy));local r=ns.WardenDrawing.sizes[stroke.size]/2
                        local nx,ny=-dy/len*r,dx/len*r
                        local entry=Entry(face,'drawing',x1,y1,1,1,'Interface\\Buttons\\WHITE8X8',{0,1,0,1},ns.WardenDrawing.palette[stroke.color])
                        entry.points={x1+nx,y1+ny,x2+nx,y2+ny,x1-nx,y1-ny,x2-nx,y2-ny}
                    end end
                end
            end
            if ns.AthenaBookArt then ns.AthenaBookArt.Emit(self,face,block,config.inset,y,config.textWidth);y=y+ns.AthenaBookArt.Height(block)end
            local _,bh,maxWidth,size=ns.Theme.BookBlockMetrics(block,config.textWidth,document.fontScale,true)
            local inset=(block.characterCard or block.guildSeal) and 78 or 0
            self:AddText(face,block.text or '',config.inset+inset,y,size,maxWidth,block.kind,block.tone)
            self.emissionBlock=nil;self.emissionWord=nil
            if block.margin then local narrow=config.textWidth-8<340;self:AddText(face,narrow and 'Ink' or block.margin.text or '',config.inset+config.textWidth-(narrow and 28 or 132),y,narrow and 13 or 14,narrow and 28 or 132,'meta') end
            -- Use real laid-out block heights, including ornaments and margins.
            y=y+bh+(block.gap or (block.kind=='heading' and 9 or 14))
            if box and box.ornament and box.ornament:IsShown() and box.ornament.icon then
                local icon=box.ornament.icon;local texture=icon:GetTexture()
                local uv=icon.GetTexCoord and {icon:GetTexCoord()} or {0,1,0,1}
                local ornamentY=y-bh-(block.gap or 14)
                if texture then Entry(face,'ornament',config.inset+4,ornamentY+4,56,56,texture,uv) end
                local caption=box.ornament.caption
                if caption and caption.GetText then self:AddText(face,caption:GetText() or '',config.inset,ornamentY+64,13,66,'meta') end
            end
        end
        if config.folio then self:AddText(face,tostring(config.folio),config.inset+config.textWidth*.45,self.parent:GetHeight()*.77-paperTop,12,50,'meta') end
    end
    function self:Reveal(document)
        local limits={}
        for i,box in ipairs(document.boxes or{})do local _,n=(box:GetText()or''):gsub('%S+','');limits[i]=n end
        for i=1,self.used do local item=self.pool[i]
            if item.inkBlock then local shown=(item.inkWord or 0)<=(limits[item.inkBlock]or 0)
                if item.revealShown~=shown then item.revealShown=shown;if item.fallback then item.fallback:SetShown(shown)else item.region:SetShown(shown)end end
            end
        end
    end
    function self:Curve(progress)
        if self.curveAt==progress then return end;self.curveAt=progress
        local angle,curl,twist,poseID=ns.AthenaBookMotion.Sample(ns.AthenaBookMotion.page,progress)
        self.poseID,self.twist=poseID,twist;self.curve={};local x,z=0,0;local count=96
        self.curve[1]={0,0,math.cos(angle-curl)}
        for i=1,count do
            local mid=(i-.5)/count;local theta=angle+curl*(2*mid-1)
            x=x+math.cos(theta)/count;z=z+math.sin(theta)/count
            self.curve[i+1]={x,z,math.cos(angle+curl*(2*i/count-1))}
        end
    end
    function self:Point(s,v,rightSide,progress,forward)
        if self.projector then return self.projector(s,v,rightSide,progress,forward)end
        local u=rightSide and s or 1-s
        local half,h=self.half,self.height
        local at=math.max(0,math.min(96,u*96));local n=math.min(96,math.floor(at)+1);local f=at-(n-1);local a,b=self.curve[n],self.curve[n+1]
        local x=half*(a[1]+(b[1]-a[1])*f+self.twist*(v-.5)*u*.12)
        local z=half*(a[2]+(b[2]-a[2])*f+self.twist*(v-.5)*u*.20)
        local normal=a[3]+(b[3]-a[3])*f
        local perspective=1/(1-z/(half*5))
        local px=self.spine+(forward and 1 or -1)*x*perspective
        -- The leaf follows the same shallow gutter/outer-edge contour as the
        -- bound paper. Apply it to ink and paper together, including at rest.
        local gutter=self.bookHeight*.03*(1-u)*(1-u)
        local outer=self.bookHeight*.03*u*u
        local restingY=self.paperTop+gutter+v*(h-gutter-outer)
        local py=self.paperTop+h*.5+(restingY-self.paperTop-h*.5)*perspective-z*.30
        if ns.AthenaBookScene then px,py=ns.AthenaBookScene.Project(px,py,self.bookWidth,self.bookHeight)end
        return px,py,z,normal
    end
    local function Quad(region,bucket,x1,y1,x2,y2,x3,y3,x4,y4)
        local minX,minY=math.min(x1,x2,x3,x4),math.min(y1,y2,y3,y4)
        local maxX,maxY=math.max(x1,x2,x3,x4),math.max(y1,y2,y3,y4)
        if region.journalBucket~=bucket then region:SetParent(bucket);region.journalBucket=bucket end
        region:ClearAllPoints();region:SetPoint('TOPLEFT',bucket,'TOPLEFT',minX,-minY);region:SetSize(math.max(.01,maxX-minX),math.max(.01,maxY-minY))
        if region.SetVertexOffset then
            region:SetVertexOffset(TL,x1-minX,minY-y1);region:SetVertexOffset(TR,x2-maxX,minY-y2)
            region:SetVertexOffset(BL,x3-minX,maxY-y3);region:SetVertexOffset(BR,x4-maxX,maxY-y4)
        end
    end
    function self:Draw(progress,forward,bookWidth,bookHeight)
        self.spine,self.half,self.paperTop,self.height=ns.AthenaBookScene.PageGeometry(bookWidth,bookHeight);self.bookWidth,self.bookHeight=bookWidth,bookHeight
        self:Curve(progress)
        if self.capture then self.quads={} end
        local visibleInk,visiblePaper=0,0
        local minLeaf,maxLeaf=math.huge,-math.huge
        for i=0,32 do local x=self:Point(i/32,.5,true,progress,forward);minLeaf=math.min(minLeaf,x);maxLeaf=math.max(maxLeaf,x)end
        for i=1,self.used do local item=self.pool[i];local face=self.faces[item.face]
            local s0,s1=item.x/self.half,(item.x+item.w)/self.half
            local v0,v1=item.y/self.height,(item.y+item.h)/self.height
            local _,_,z,normal=self:Point((s0+s1)*.5,(v0+v1)*.5,face.rightSide,progress,forward)
            local shown=(item.face=='front' and normal>.006) or (item.face=='back' and normal<-.006)
            if face.hideInk and item.kind~='paper'and item.kind~='edge'then shown=false end
            -- Frozen ink is occluded as its face turns edge-on. Never turn live
            -- text or glyphs into an unreadable narrow vertical strip.
            -- Frozen ink follows its paper normally. Only actual edge-on
            -- surfaces are culled; the former global width threshold made
            -- whole blocks pop out and back while the leaf was still broad.
            if item.kind~='paper'and item.kind~='edge'and(progress>0 and progress<1 or self.inkMotion)and math.abs(normal)<.10 then shown=false end
            if item.kind=='fallback'and(progress>0 and progress<1 or self.inkMotion)then shown=false end
            if item.fallback then item.fallback:Hide() end
            if not shown then item.region:Hide()
            else
                local x1,y1=self:Point(s0,v0,face.rightSide,progress,forward)
                local x2,y2=self:Point(s1,v0,face.rightSide,progress,forward)
                local x3,y3=self:Point(s0,v1,face.rightSide,progress,forward)
                local x4,y4=self:Point(s1,v1,face.rightSide,progress,forward)
                if item.points then local q=item.points
                    x1,y1=self:Point(q[1]/self.half,q[2]/self.height,face.rightSide,progress,forward)
                    x2,y2=self:Point(q[3]/self.half,q[4]/self.height,face.rightSide,progress,forward)
                    x3,y3=self:Point(q[5]/self.half,q[6]/self.height,face.rightSide,progress,forward)
                    x4,y4=self:Point(q[7]/self.half,q[8]/self.height,face.rightSide,progress,forward)
                end
                -- Keep ink above the paper mesh. Per-strip depth layers otherwise
                -- let a neighboring paper strip cut holes through whole glyphs.
                local depth=math.max(1,math.min(8,1+math.floor(z/self.half*11)))
                local bucket=self.buckets[depth+(item.kind=='paper' and 0 or 8)]
                if item.kind=='fallback' then
                    local f=item.fallback;local scale=math.max(.02,math.abs(x2-x1)/math.max(1,item.w))
                    f:SetParent(bucket);f:SetScale(scale);f:ClearAllPoints();f:SetPoint('TOPLEFT',bucket,'TOPLEFT',math.min(x1,x2)/scale,-y1/scale);f:Show();item.region:Hide()
                else
                    local clipped=false
                    if self.clipMin or self.clipMax then
                        local lo,hi=math.min(x1,x2,x3,x4),math.max(x1,x2,x3,x4)
                        local ca=math.max(0,math.min(1,((self.clipMin or lo)-lo)/math.max(.001,hi-lo)))
                        local cb=math.max(0,math.min(1,((self.clipMax or hi)-lo)/math.max(.001,hi-lo)))
                        if cb<=ca then item.region:Hide();clipped=true
                        elseif ca>0 or cb<1 then
                            local ax,ay,bx,by=x1,y1,x2,y2;local cx,cy,dx,dy=x3,y3,x4,y4
                            x1,y1=ax+(bx-ax)*ca,ay+(by-ay)*ca;x2,y2=ax+(bx-ax)*cb,ay+(by-ay)*cb
                            x3,y3=cx+(dx-cx)*ca,cy+(dy-cy)*ca;x4,y4=cx+(dx-cx)*cb,cy+(dy-cy)*cb
                            local uv=item.uv;if #uv==4 then item.region:SetTexCoord(uv[1]+(uv[2]-uv[1])*ca,uv[1]+(uv[2]-uv[1])*cb,uv[3],uv[4]);item.clipLast=true end
                        elseif item.clipLast then item.region:SetTexCoord(unpack(item.uv));item.clipLast=nil end
                    elseif item.clipLast then item.region:SetTexCoord(unpack(item.uv));item.clipLast=nil end
                    if not clipped then
                    Quad(item.region,bucket,x1,y1,x2,y2,x3,y3,x4,y4)
                    local shade=item.kind=='paper' and (1-.20*math.sin(PI*progress)*(1-math.min(1,math.abs(normal)))) or 1
                    local color=item.color;item.region:SetVertexColor(color[1]*shade,color[2]*shade,color[3]*shade,item.alpha or 1);item.region:Show()
                    if item.kind=='ink' then visibleInk=visibleInk+1 elseif item.kind=='paper' then visiblePaper=visiblePaper+1 end
                    if self.capture then self.quads[#self.quads+1]={path=item.path,uv=item.uv,color={color[1]*shade,color[2]*shade,color[3]*shade},xy={x1,y1,x2,y2,x3,y3,x4,y4},kind=item.kind,face=item.face,z=z} end
                    end
                end
            end
        end
        self.visibleInk,self.visiblePaper=visibleInk,visiblePaper
    end
    function self:Hide() for _,item in ipairs(self.pool) do item.region:Hide();if item.fallback then item.fallback:Hide() end end end
    return self
end
