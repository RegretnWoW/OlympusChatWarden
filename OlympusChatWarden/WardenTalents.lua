-- Native talent geometry retained at inspection time; read-only historical UI.
local _,ns=...
local T={cache={},order={}};ns.WardenTalents=T
local S,X,B=ns.ChronicleStore,ns.ChronicleCapture,ns.ChronicleBackup
local function ID(v) return S.Integer(v,1,1000000000) end
function T.Node(config,tree,node,owned)
    local x,y=S.Number(node.posX,-1000000,1000000),S.Number(node.posY,-1000000,1000000)
    local max,kind= S.Integer(node.maxRanks,0,1000),S.Integer(node.type,0,1000)
    local entries,edges,groups=X.Table(node.entryIDs),X.Table(node.visibleEdges),X.Table(node.groupIDs)
    local visible=X.Bool(node.isVisible)
    if visible==nil or not x or not y or not max or not kind or not entries or #entries<1 or #entries>8 or not edges or #edges>8 then return end
    local es,ls,gs={},{},{}
    for _,entry in ipairs(entries) do
        if not ID(entry) or not owned() then return end
        local e=X.Table(X.Call('C_Traits.GetEntryInfo',config,entry));local def=e and ID(e.definitionID)
        if not owned() then return end
        local d=def and X.Table(X.Call('C_Traits.GetDefinitionInfo',def));if not owned() then return end
        -- Retail SubTreeSelection entries legitimately have no definition.
        -- Keep the observed entry/type and explicit unknown spell/definition.
        local subtree=e and ID(e.subTreeID)
        if not e or not def and not subtree or def and not d or max==0 and not subtree then return end
        es[#es+1]={entry,def or false,d and ID(d.spellID) or false,S.Integer(e.type,0,1000) or false}
    end
    for _,edge in ipairs(edges) do
        if not X.Table(edge) or not ID(edge.targetNode) or not S.Integer(edge.type,0,1000) or not S.Integer(edge.visualStyle,0,1000) then return end
        ls[#ls+1]={edge.targetNode,edge.type,edge.visualStyle}
    end
    for _,group in ipairs(groups or {}) do if not ID(group) or #gs>=8 then return end;gs[#gs+1]=group end
    table.sort(es,function(a,b) return a[1]<b[1] end);table.sort(ls,function(a,b) return a[1]<b[1] end);table.sort(gs)
    return {node.ID,x,y,max,kind,es,ls,gs,visible}
end
function T.Groups(tree)
    local rows=X.Table(X.Call('C_Traits.GetGroupDisplayInfoByTreeID',tree));local out={}
    for _,g in ipairs(rows or {}) do
        if #out>=8 then break end
        if X.Table(g) and ID(g.groupID) and (not g.treeID or g.treeID==tree) then
            out[#out+1]={g.groupID,S.Text(g.displayName,144) or 'Talent branch',S.Integer(g.orderIndex,0,1000) or #out+1,ID(g.icon) or false}
        end
    end
    table.sort(out,function(a,b) return a[3]<b[3] end);return out
end
function T.Store(layouts,owned)
    local refs={}
    for _,layout in ipairs(layouts or {}) do
        local rows=layout.rows;table.sort(rows,function(a,b) return a[1]<b[1] end)
        local parts=math.ceil(#rows/10)
        for part=1,parts do
            if not owned() or #refs>=32 then return end
            local chunk={};for n=(part-1)*10+1,math.min(#rows,part*10) do chunk[#chunk+1]=rows[n] end
            local values={layoutTree=layout.tree,layoutPart=part,layoutParts=parts,layoutNodes=chunk,
                layoutComplete=layout.complete,layoutGroups=part==1 and layout.groups or nil}
            local canonical=B.Encode(values);local hash=T.cache[canonical]
            if not hash or not X.Find(ns.Chronicle.Owner(),hash) then
                hash=X.Store('traits',values,'INSPECT_READY')
                if not hash then return end
                if not T.cache[canonical] then
                    if #T.order>=32 then T.cache[table.remove(T.order,1)]=nil end
                    T.order[#T.order+1]=canonical
                end
                T.cache[canonical]=hash
            end
            refs[#refs+1]=hash
        end
    end
    return #refs>0 and refs or nil
end
function T.Validate(v)
    if v.layoutRefs~=nil then
        if not S.GUID(v.guid) or not S.Array(v.layoutRefs,32) or #v.layoutRefs==0 then return false end
        local seen={};for _,hash in ipairs(v.layoutRefs) do if type(hash)~='string' or #hash~=64 or hash:find('[^a-f0-9]') or seen[hash] then return false end;seen[hash]=true end
    end
    if v.layoutTree==nil then return v.layoutNodes==nil and v.layoutPart==nil and v.layoutParts==nil and v.layoutGroups==nil and v.layoutComplete==nil end
    if not ID(v.layoutTree) or not S.Integer(v.layoutParts,1,32) or not S.Integer(v.layoutPart,1,v.layoutParts)
        or type(v.layoutComplete)~='boolean' or not S.Array(v.layoutNodes,10) or #v.layoutNodes==0
        or v.guid~=nil or v.choices~=nil or v.layoutRefs~=nil then return false end
    local seen={}
    for _,node in ipairs(v.layoutNodes) do
        if not S.Array(node,9) or #node~=9 or not ID(node[1]) or seen[node[1]] or not S.Number(node[2],-1000000,1000000)
            or not S.Number(node[3],-1000000,1000000) or not S.Integer(node[4],0,1000) or not S.Integer(node[5],0,1000)
            or not S.Array(node[6],8) or #node[6]==0 or not S.Array(node[7],8) or not S.Array(node[8],8) or type(node[9])~='boolean' then return false end
        seen[node[1]]=true;local entries={}
        for _,e in ipairs(node[6]) do
            if not S.Array(e,4) or #e~=4 or not ID(e[1]) or e[2]~=false and not ID(e[2]) or entries[e[1]] or e[3]~=false and not ID(e[3]) or e[4]~=false and not S.Integer(e[4],0,1000)
                or e[2]==false and(e[3]~=false or not S.Integer(e[4],0,1000))or node[4]==0 and e[2]~=false then return false end
            entries[e[1]]=true
        end
        for _,edge in ipairs(node[7]) do if not S.Array(edge,3) or #edge~=3 or not ID(edge[1]) or not S.Integer(edge[2],0,1000) or not S.Integer(edge[3],0,1000) then return false end end
        for _,group in ipairs(node[8]) do if not ID(group) then return false end end
    end
    if v.layoutGroups~=nil then
        if not S.Array(v.layoutGroups,8) then return false end
        for _,g in ipairs(v.layoutGroups) do if not S.Array(g,4) or #g~=4 or not ID(g[1]) or not S.Text(g[2],144) or not S.Integer(g[3],0,1000) or g[4]~=false and not ID(g[4]) then return false end end
    end
    return true
end
function T.Projection(values,objects)
    if not values or not values.layoutRefs then return end
    local trees,order,seenNodes,count={}, {},{},0
    for _,ref in ipairs(values.layoutRefs) do
        local o=objects[ref];local v=o and o.capture and o.capture.family=='traits' and o.capture.values
        if not v or not v.layoutTree or not T.Validate(v) then return end
        local tree=trees[v.layoutTree]
        if not tree then tree={id=v.layoutTree,nodes={},parts={},count=v.layoutParts,groups={}};trees[v.layoutTree]=tree;order[#order+1]=tree end
        if tree.count~=v.layoutParts or tree.parts[v.layoutPart] then return end
        tree.parts[v.layoutPart]=true;tree.complete=tree.complete~=false and v.layoutComplete
        for _,node in ipairs(v.layoutNodes) do
            count=count+1;if seenNodes[node[1]] or count>256 then return end
            seenNodes[node[1]]=true;tree.nodes[node[1]]=node
        end
        if v.layoutGroups then tree.groups=v.layoutGroups end
    end
    for _,tree in ipairs(order) do for n=1,tree.count do if not tree.parts[n] then return end end end
    local selected={}
    for _,row in ipairs(values.choices or {}) do
        local tree=trees[row[1]];local node=tree and tree.nodes[row[2]];local match=false
        if not node then return end
        for _,entry in ipairs(node[6]) do if entry[1]==row[3] and (row[5]==false or row[5]==entry[2]) and (row[6]==false or row[6]==entry[3]) then match=true end end
        if not match or row[4]>math.max(1,node[4]) then return end
        selected[row[2]]=row
    end
    return order,selected
end
function T.ClientProjection(values)
 if not values or not values.choices or #values.choices==0 then return end
 local config=S.Integer(X.Call('C_ClassTalents.GetActiveConfigID'),1);if not config then return end
 local info=X.Table(X.Call('C_Traits.GetConfigInfo',config));local available={};for _,id in ipairs(info and X.Table(info.treeIDs)or{})do available[id]=true end
 local trees={};local byTree={};local recorded,subtrees={},{}
 for _,row in ipairs(values.choices)do
  recorded[row[2]]=true
  local n=X.Table(X.Call('C_Traits.GetNodeInfo',config,row[2]));local e=X.Table(X.Call('C_Traits.GetEntryInfo',config,row[3]))
  local subtree=n and ID(n.subTreeID)or e and ID(e.subTreeID)
  if subtree then subtrees[row[1]]=subtrees[row[1]]or{};subtrees[row[1]][subtree]=true end
 end
 for _,row in ipairs(values.choices)do
  if not available[row[1]]then return end
  if not byTree[row[1]]then
   local ids=X.Table(X.Call('C_Traits.GetTreeNodes',row[1]));if not ids or #ids>2048 then return end
   local tree={id=row[1],nodes={},complete=false,groups=T.Groups(row[1])};byTree[row[1]]=tree;trees[#trees+1]=tree
   local retained=0
   for _,id in ipairs(ids)do local node=X.Table(X.Call('C_Traits.GetNodeInfo',config,id));local subtree=node and ID(node.subTreeID)
    local wanted=subtree and subtrees[row[1]]and subtrees[row[1]][subtree]
    local visible=node and X.Bool(node.isVisible)==true and X.Bool(node.subTreeActive)~=false
    if subtree and subtrees[row[1]]then visible=wanted==true end
    if node and(visible or recorded[id])then
    local geometry=T.Node(config,row[1],node,function()return config==S.Integer(X.Call('C_ClassTalents.GetActiveConfigID'),1)end)
    if geometry then if recorded[id]or wanted then geometry[9]=true end;retained=retained+1;if retained>256 then return end;tree.nodes[id]=geometry end
   end end
  end
  local node=byTree[row[1]].nodes[row[2]];local match=false
  for _,entry in ipairs(node and node[6]or{})do if entry[1]==row[3]and(row[5]==false or row[5]==entry[2])and(row[6]==false or row[6]==entry[3])then match=true end end
  if not match then return end
 end
 if config~=S.Integer(X.Call('C_ClassTalents.GetActiveConfigID'),1)then return end
 local selected={};for _,row in ipairs(values.choices)do selected[row[2]]=row end;return trees,selected
end
local nativeSpecBackgrounds={[250]="talents-background-deathknight-blood",[251]="talents-background-deathknight-frost",[252]="talents-background-deathknight-unholy",[577]="talents-background-demonhunter-havoc",[581]="talents-background-demonhunter-vengeance",[1480]="talents-background-demonhunter-devourer",[102]="talents-background-druid-balance",[103]="talents-background-druid-feral",[104]="talents-background-druid-guardian",[105]="talents-background-druid-restoration",[1467]="talents-background-evoker-devastation",[1468]="talents-background-evoker-preservation",[1473]="talents-background-evoker-augmentation",[253]="talents-background-hunter-beastmastery",[254]="talents-background-hunter-marksmanship",[255]="talents-background-hunter-survival",[62]="talents-background-mage-arcane",[63]="talents-background-mage-fire",[64]="talents-background-mage-frost",[268]="talents-background-monk-brewmaster",[269]="talents-background-monk-windwalker",[270]="talents-background-monk-mistweaver",[65]="talents-background-paladin-holy",[66]="talents-background-paladin-protection",[70]="talents-background-paladin-retribution",[256]="talents-background-priest-discipline",[257]="talents-background-priest-holy",[258]="talents-background-priest-shadow",[259]="talents-background-rogue-assassination",[260]="talents-background-rogue-outlaw",[261]="talents-background-rogue-subtlety",[262]="talents-background-shaman-elemental",[263]="talents-background-shaman-enhancement",[264]="talents-background-shaman-restoration",[265]="talents-background-warlock-affliction",[266]="talents-background-warlock-demonology",[267]="talents-background-warlock-destruction",[71]="talents-background-warrior-arms",[72]="talents-background-warrior-fury",[73]="talents-background-warrior-protection"}
function T.NativeBackground(texture,values)
 local util=ClassTalentUtil;local visuals=util and type(util.GetVisualsForSpecID)=='function'and ns.SafeCall(util.GetVisualsForSpecID,values.specializationID)
 local atlas=X.Table(visuals)and S.Text(visuals.background,160)or nativeSpecBackgrounds[values.specializationID]
 if atlas and C_Texture and ns.SafeCall(C_Texture.GetAtlasInfo,atlas)and texture.SetAtlas then texture:SetAtlas(atlas);texture:SetAlpha(.42);texture:Show();return true end
 texture:Hide();return false
end
local function SmallestGap(values)
    table.sort(values);local gap=math.huge
    local tolerance=math.max(1,values[#values] and values[#values]-values[1] or 0)*.000001
    for n=2,#values do local d=values[n]-values[n-1];if d>tolerance then gap=math.min(gap,d) end end
    return gap
end
function T.Layout(trees)
    local list,byID,groups={}, {},{};local offset,maxY=0,0
    for _,tree in ipairs(trees) do
        local xs,ys,visible,groupNodes={},{},{},{}
        local minX,minY,maxX=math.huge,math.huge,-math.huge;local positions={}
        for _,node in pairs(tree.nodes) do if node[9] then
            -- Coincident visible nodes cannot form a readable historical tree.
            local key=tostring(node[2])..':'..tostring(node[3]);if positions[key] then return end;positions[key]=true
            visible[#visible+1]=node;xs[#xs+1]=node[2];ys[#ys+1]=node[3]
            minX=math.min(minX,node[2]);minY=math.min(minY,node[3]);maxX=math.max(maxX,node[2])
            for _,id in ipairs(node[8]) do local g=groupNodes[id] or {min=math.huge,max=-math.huge};groupNodes[id]=g;g.min=math.min(g.min,node[2]);g.max=math.max(g.max,node[2]) end
        end end
        if #visible>0 then
            local centers={};local headings={}
            for _,g in ipairs(tree.groups) do local nodes=groupNodes[g[1]];if nodes then local x=(nodes.min+nodes.max)/2;centers[#centers+1]=x;headings[#headings+1]={text=g[2],x=x} end end
            -- Native coordinates use 10 units per UI pixel. Never squeeze fixed-size
            -- icons/ranks or headings to fit: extra width belongs in the scroll canvas.
            -- Near x/y values on DIFFERENT branches are not collisions. Scaling
            -- by the smallest independent axis gap can magnify a valid Retail
            -- tree beyond the canvas limit and wrongly select the grid fallback.
            local separation=math.huge
            for i=1,#visible do for j=i+1,#visible do
                local a,b=visible[i],visible[j]
                separation=math.min(separation,math.max(math.abs(a[2]-b[2]),math.abs(a[3]-b[3])))
            end end
            local scale=math.max(.1,62/separation)
            for _,node in ipairs(visible) do
                local item={raw=node,x=offset+(node[2]-minX)*scale,y=(node[3]-minY)*scale,tree=tree}
                if item.x>16000 or item.y>16000 then return end
                list[#list+1]=item;byID[node[1]]=item;maxY=math.max(maxY,item.y)
            end
            for _,g in ipairs(headings) do groups[#groups+1]={text=g.text,x=offset+(g.x-minX)*scale} end
            offset=offset+(maxX-minX)*scale+100
        end
    end
    if #list==0 then return end
    table.sort(list,function(a,b) return a.raw[1]<b.raw[1] end)
    return {list=list,byID=byID,groups=groups,maxX=offset-100,maxY=maxY}
end
function T.Build(parent,options)
    options=options or {}
    local V=ns.Art;local p
    if options.inline then p=CreateFrame('Frame',nil,parent);p:SetSize(1096,600);ns.UI2Components.Fill(p,{.025,.045,.07,1})
    else p=V.Panel(parent,20,-195,1096,342,'minimal') end
    p.nativeBackground=p:CreateTexture(nil,'BACKGROUND');p.nativeBackground:SetAllPoints();p.nativeBackground:Hide()
    p:Hide();p.nodes={};p.lines={};p.headers={};p.zoom=1
    p.scroll=CreateFrame('ScrollFrame',nil,p);p.scroll:SetPoint('TOPLEFT',10,-39);p.scroll:SetSize(1076,292);V.SkinScroll(p.scroll)
    -- Scroll extents stay in viewport units. One scaled content frame owns all
    -- icons, ranks, headings and lines, so zoom changes their size together.
    p.canvas=CreateFrame('Frame',nil,p.scroll);p.canvas:SetSize(1076,292);p.scroll:SetScrollChild(p.canvas)
    p.zoomOrigin=CreateFrame('Frame',nil,p.canvas)
    p.content=CreateFrame('Frame',nil,p.zoomOrigin);p.content:SetPoint('TOPLEFT',0,0)
    p.zoomText=V.Text(p,'100%',778,-11,74,13,V.muted);p.zoomText:SetJustifyH('RIGHT')
    p.zoomOut=V.Button(p,'−',866,-5,38,26,function() p:SetZoom(p.zoom-.25) end,'neutral')
    p.reset=V.Button(p,'Reset',912,-5,70,26,function() p:ResetView() end,'neutral')
    p.zoomIn=V.Button(p,'+',990,-5,38,26,function() p:SetZoom(p.zoom+.25) end,'neutral')
    p.fit=V.Button(p,'Fit',730,-5,44,26,function() p:FitView() end,'neutral')
    p.branch=V.Button(p,'All branches',10,-5,220,26,function()
        if not p.branchChoices or #p.branchChoices<=1 then return end
        p.branchIndex=(p.branchIndex or 1)%#p.branchChoices+1;p:SelectBranch()
    end,'neutral')
    p.empty=V.Text(p.scroll,'No talent tree has been recorded.',20,-70,600,14,V.muted);p.empty:SetHeight(90);p.empty:SetWordWrap(true);p.empty:Hide()
    ns.Theme.Tooltip(p.branch,'Talent branches','Switch between the complete recorded tree and its named branches. Read-only; this does not change talents.')
    ns.Theme.Tooltip(p.zoomOut,'Zoom out','Scale the whole tree down, including icons and ranks. Drag empty space to pan.')
    ns.Theme.Tooltip(p.zoomIn,'Zoom in','Scale the whole tree up, including icons and ranks. Drag empty space to pan.')
    ns.Theme.Tooltip(p.reset,'Reset view','Return to 100% zoom and the start of this recorded tree.')
    function p:ApplyZoom(left,top)
        if not self.layout then return end
        local vw,vh=self.scroll:GetWidth(),self.scroll:GetHeight()
        self.baseWidth=math.max(vw,self.layout.maxX+100);self.baseHeight=math.max(vh,self.layout.maxY+105)
        self.width=math.max(vw,self.baseWidth*self.zoom);self.height=math.max(vh,self.baseHeight*self.zoom)
        self.originX=(self.width-self.baseWidth*self.zoom)/2
        self.canvas:SetSize(self.width,self.height)
        self.zoomOrigin:ClearAllPoints();self.zoomOrigin:SetPoint('TOPLEFT',self.canvas,'TOPLEFT',self.originX,0);self.zoomOrigin:SetSize(self.baseWidth*self.zoom,self.baseHeight*self.zoom)
        self.content:SetSize(self.baseWidth,self.baseHeight);self.content:SetScale(self.zoom)
        self.scroll.ChatWardenUpdateScrollRange(self.height-vh)
        self.scroll:SetHorizontalScroll(math.max(0,math.min(self.width-vw,left or 0)))
        self.scroll:SetVerticalScroll(math.max(0,math.min(self.height-vh,top or 0)))
        self.zoomText:SetText(math.floor(self.zoom*100+.5)..'%');self.zoomOut:SetEnabled(self.zoom>.5);self.zoomIn:SetEnabled(self.zoom<2)
    end
    function p:SetZoom(value)
        if not self.layout then return end
        self.canvas:SetScript('OnUpdate',nil)
        local vw,vh=self.scroll:GetWidth(),self.scroll:GetHeight();local old=self.zoom
        local cx=((self.scroll:GetHorizontalScroll() or 0)+vw/2-(self.originX or 0))/old
        local cy=((self.scroll:GetVerticalScroll() or 0)+vh/2)/old
        self.zoom=math.max(2,math.min(8,math.floor(value*4+.5)))/4
        local origin=(math.max(vw,self.baseWidth*self.zoom)-self.baseWidth*self.zoom)/2
        self:ApplyZoom(origin+cx*self.zoom-vw/2,cy*self.zoom-vh/2)
    end
    function p:ResetView()
        self.canvas:SetScript('OnUpdate',nil);self.zoom=1;self:ApplyZoom(0,0)
    end
    function p:FitView()
        if not self.layout then return end
        self.canvas:SetScript('OnUpdate',nil)
        self.zoom=math.max(.5,math.min(1,(self.scroll:GetWidth()-16)/(self.layout.maxX+100),(self.scroll:GetHeight()-16)/(self.layout.maxY+105)))
        self:ApplyZoom(0,0)
    end
    function p:SelectBranch()
        local choice=self.branchChoices[self.branchIndex or 1];local filtered={}
        for _,tree in ipairs(self.trees) do
            local t={id=tree.id,complete=tree.complete,groups=tree.groups,nodes={}}
            for id,node in pairs(tree.nodes) do
                local include=not choice.group and not choice.tree or choice.tree==tree.id
                if choice.group then for _,group in ipairs(node[8]) do if group==choice.group then include=true end end end
                if include then t.nodes[id]=node end
            end
            filtered[#filtered+1]=t
        end
        self.layout=T.Layout(filtered);self.branch:SetText(choice.title)
        self.branch:SetEnabled(#self.branchChoices>1);self:Draw(true)
    end
    p.canvas:EnableMouse(true)
    p.canvas:SetScript('OnMouseDown',function(_,button)
        if button~='LeftButton' or type(GetCursorPosition)~='function' then return end
        local x,y=GetCursorPosition();local scale=p:GetEffectiveScale()
        if not S.Number(x) or not S.Number(y) or not S.Number(scale,.01) then return end
        local left,top=p.scroll:GetHorizontalScroll(),p.scroll:GetVerticalScroll()
        p.canvas:SetScript('OnUpdate',function()
            if type(IsMouseButtonDown)=='function' and not ns.Checked(ns.SafeCall(IsMouseButtonDown,'LeftButton')) then p.canvas:SetScript('OnUpdate',nil);return end
            local a,b=GetCursorPosition();if not S.Number(a) or not S.Number(b) then return end
            p.scroll:SetHorizontalScroll(math.max(0,math.min(p.width-p.scroll:GetWidth(),left-(a-x)/scale)))
            p.scroll:SetVerticalScroll(math.max(0,math.min(p.height-p.scroll:GetHeight(),top+(b-y)/scale)))
        end)
    end)
    p.canvas:SetScript('OnMouseUp',function() p.canvas:SetScript('OnUpdate',nil) end)
    p:SetScript('OnHide',function() p.canvas:SetScript('OnUpdate',nil) end)
    function p:Draw(reset)
        if not self.layout then return end
        local left,top=self.scroll:GetHorizontalScroll(),self.scroll:GetVerticalScroll()
        for _,b in ipairs(self.nodes) do b:Hide() end;for _,line in ipairs(self.lines) do line:Hide() end;for _,label in ipairs(self.headers) do label:Hide() end
        local layout=self.layout;local list,byID,groups=layout.list,layout.byID,layout.groups
        local center=self.layoutUnavailable and 20 or (math.max(self.scroll:GetWidth(),layout.maxX+100)-(layout.maxX+48))/2
        for n,g in ipairs(groups) do local label=self.headers[n] or V.Text(self.content,'',0,0,220,16,V.gold);self.headers[n]=label;label:ClearAllPoints();label:SetPoint('TOP',self.content,'TOPLEFT',center+g.x+24,-10);label:SetText(ns.WardenBrand.Text(g.text));label:SetJustifyH('CENTER');label:SetWordWrap(false);label:Show() end
        local lineIndex=0
        for _,n in ipairs(list) do n.drawX=center+n.x+24;n.drawY=55+n.y end
        for _,n in ipairs(list) do for _,edge in ipairs(n.raw[7]) do local target=byID[edge[1]]
            if target and lineIndex<1024 and self.content.CreateLine then
                lineIndex=lineIndex+1;local line=self.lines[lineIndex] or self.content:CreateLine(nil,'BACKGROUND');self.lines[lineIndex]=line
                line:SetStartPoint('TOPLEFT',self.content,n.drawX,-n.drawY);line:SetEndPoint('TOPLEFT',self.content,target.drawX,-target.drawY);line:SetThickness(2)
                local active=self.selected[n.raw[1]] and self.selected[target.raw[1]];line:SetColorTexture(active and .95 or .27,active and .72 or .30,active and .30 or .33,1);line:SetThickness(active and 3 or 2);line:Show()
            end
        end end
        for index,n in ipairs(list) do
            local b=self.nodes[index]
            if not b then
                b=CreateFrame('Button',nil,self.content);b:SetSize(42,42);b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetPoint('TOPLEFT',3,-3);b.icon:SetPoint('BOTTOMRIGHT',-3,3)
                b.border=b:CreateTexture(nil,'OVERLAY');b.border:SetAllPoints()
                b.rank=V.Text(b,'',-7,-38,56,12,V.gold);b.rank:SetJustifyH('CENTER');b.rank:SetHeight(18)
                b:SetScript('OnEnter',function(self)
                    if not GameTooltip then return end;GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText(self.title)
                    if self.spell then ns.SafeCall(GameTooltip.SetSpellByID,GameTooltip,self.spell) end
                    GameTooltip:AddLine('Historical rank: '..self.rankText,.55,.8,1,true);GameTooltip:AddLine('Observed '..self.observed,.8,.8,.8,true)
                    GameTooltip:Show()
                end);b:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end);self.nodes[index]=b
            end
            local chosen=self.selected[n.raw[1]];local entry=n.raw[6][1]
            if chosen then for _,e in ipairs(n.raw[6]) do if e[1]==chosen[3] then entry=e end end end
            local row=chosen or {n.tree.id,n.raw[1],entry[1],0,entry[2],entry[3]};local name,icon,spell,atlas=ns.WardenDossier.TalentLabel(row)
            local enums=X.Table(Enum);local types=enums and X.Table(enums.TraitNodeEntryType);local nodes=enums and X.Table(enums.TraitNodeType)
            local shape=nodes and n.raw[5]==nodes.Selection and 'Choice' or types and (entry[4]==types.SpendCircle or entry[4]==types.SpendCapstoneCircle) and 'Circle' or 'Square'
            b.border:SetTexture('Interface\\AddOns\\OlympusChatWarden\\Media\\Warden\\Talent'..shape..'.tga')
            b.title=name;b.spell=spell;b.observed=self.observed;b.rankText=self.partial and ('Rank '..(chosen and tostring(chosen[4])or '?'))or(chosen and tostring(chosen[4]) or self.complete and n.tree.complete and '0' or '?')..'/'..n.raw[4]
            if self.layoutUnavailable then
                b.choiceName=b.choiceName or V.Text(b,'',54,-10,700,14,V.gold)
                b.choiceName:SetText(name);b.choiceName:SetWidth(math.max(80,self.scroll:GetWidth()-120));b.choiceName:Show()
            elseif b.choiceName then b.choiceName:Hide()end
            if entry[2]==false then b.rankText=chosen and'Selected'or'Not recorded'end
            b.rank:SetText(b.rankText);if atlas and b.icon.SetAtlas then b.icon:SetAtlas(atlas)else b.icon:SetTexture(icon or 'Interface\\Icons\\INV_Misc_QuestionMark')end;if b.icon.SetDesaturated then b.icon:SetDesaturated(not chosen) end;b.icon:SetAlpha(chosen and 1 or .45)
            b.border:SetVertexColor(chosen and 1 or .55,chosen and .78 or .43,chosen and .35 or .29,1)
            b:ClearAllPoints();b:SetPoint('CENTER',self.content,'TOPLEFT',n.drawX,-n.drawY);b:Show()
        end
        if reset then self:FitView()else self:ApplyZoom(left,top)end
    end
    function p:PresentPartial(values,at,key)
        local list,selected={},{}
        for index,row in ipairs(values.choices or {})do
            local raw={row[2],0,0,math.max(1,row[4]),0,{{row[3],row[5],row[6],false}},{},{},true}
            list[#list+1]={raw=raw,x=0,y=45+(index-1)*64,tree={id=row[1],complete=false}};selected[row[2]]=row
        end
        self.partial=true;self.layoutUnavailable=true;self.viewKey=key;self.selected=selected;self.observed=at;self.complete=false;self.zoom=1
        self.layout={list=list,byID={},groups={},maxX=0,maxY=45+math.max(0,#list-1)*64}
        self.branchChoices={{title='Recorded choices · layout unavailable'}};self.branchIndex=1;self.branch:SetText(self.branchChoices[1].title);self.branch:SetEnabled(false)
        self.nativeBackground:Hide();self.empty:ClearAllPoints();self.empty:SetPoint('TOPLEFT',20,-12);self.empty:SetHeight(65)
        self.empty:SetText(#list>0 and 'Tree positions were not recorded and cannot be recovered from this client. These are the retained choices, not a reconstructed tree.'or'No talent choices or tree positions have been recorded.')
        self.empty:Show();self.empty:SetWidth(math.max(100,self.scroll:GetWidth()-40));self:Draw(false);self:ApplyZoom(0,0);self:Show();return true
    end
    function p:Present(values,objects,at,key)
        local trees,selected=T.Projection(values,objects or {})
        self.referenceLayout=false;if not trees then trees,selected=T.ClientProjection(values);self.referenceLayout=trees~=nil end
        T.NativeBackground(self.nativeBackground,values or{})
        local layout=trees and T.Layout(trees)
        if not layout then return self:PresentPartial(values,at,key)end
        self.partial=self.referenceLayout;self.layoutUnavailable=false;self.empty:Hide();self.branch:SetEnabled(true)
        key=key or values;local changed=self.viewKey~=key
        if changed then self.zoom=1;self.canvas:SetScript('OnUpdate',nil) end
        self.viewKey=key
        self.layout=layout
        self.trees,self.selected,self.complete,self.observed=trees,selected,values.choicesComplete==true,at
        if changed then
            self.branchChoices={{title='All branches'}};self.branchIndex=1
            for _,tree in ipairs(trees)do
                if #tree.groups>0 then for _,g in ipairs(tree.groups)do
                    local visible=false;for _,node in pairs(tree.nodes)do if node[9]then for _,id in ipairs(node[8])do if id==g[1]then visible=true;break end end end;if visible then break end end
                    if visible then self.branchChoices[#self.branchChoices+1]={title=g[2],group=g[1]}end
                end
                elseif #trees>1 then self.branchChoices[#self.branchChoices+1]={title='Talent tree '..tree.id,tree=tree.id}end
            end
        end
        if changed then self:SelectBranch()else self:Draw(false)end;self:Show();return true
    end
    if options.inline then
        p.scroll:ClearAllPoints();p.scroll:SetPoint('TOPLEFT',10,-39);p.scroll:SetPoint('BOTTOMRIGHT',-10,10)
        for _,spec in ipairs({{p.zoomIn,-8,30},{p.zoomOut,-44,30},{p.fit,-80,44},{p.reset,-130,56}}) do spec[1]:ClearAllPoints();spec[1]:SetPoint('TOPRIGHT',spec[2],-5);spec[1]:SetWidth(spec[3])end
        p.zoomText:ClearAllPoints();p.zoomText:SetPoint('TOPRIGHT',-192,-11)
        p:SetScript('OnSizeChanged',function(self)self.branch:SetWidth(math.max(90,self:GetWidth()-280));if self.layout then self:Draw(false)end end)
    end
    return p
end
