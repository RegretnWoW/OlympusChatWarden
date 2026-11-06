-- Relay's account-wide operational data shares the addon's complete saved FILE,
-- not Chronicle's schema or ledger. Incoming data is never evaluated as Lua.
local _,ns=...
local R={SCHEMA=1,MAX_LOCAL=200,MAX_INBOX=500,MAX_BYTES=8192};ns.RelayStore=R
R.modules={{'suite','Fireside / general'},{'chronicle','ChronicleWarden'},{'intel','IntelWarden'},
    {'messages','ChatWarden'},{'mentions','SignalWarden'},{'shield','ShieldWarden'},{'relay','RelayWarden'},
    {'realm','Fields / Oasis scenes'},{'journal','Athena Journal'},{'aether','Aether / Agora'},{'codex','Athenaeum'}}
R.categories={{'bug','Something is broken'},{'display','Display or navigation'},{'performance','Performance'},
    {'recording','Recording or saved data'},{'delivery','Report delivery'},{'other','Other problem'}}
local moduleKeys,categoryKeys={},{}
for _,s in ipairs(R.modules) do moduleKeys[s[1]]=true end
for _,s in ipairs(R.categories) do categoryKeys[s[1]]=true end
R.Now=function() return ns.SafeCall(GetServerTime) or time and time() or 0 end
function R.Text(v,max)
    if not ns.CanRead(v) then return nil end
    if #v>max or v:find('[%z\1-\8\11\12\14-\31]') then return nil end
    return v
end
function R.Safe(v) return tostring(v or ''):gsub('|','||') end
function R.ID(v) return R.Text(v,80) and v:match('^[%w%-]+$') and #v>=5 and v end
-- Adler-32 detects accidental corruption; it is not a signature or authentication.
function R.Checksum(v)
    local a,b=1,0
    for i=1,#v do a=(a+v:byte(i))%65521;b=(b+a)%65521 end
    return string.format('%08x',b*65536+a)
end
local fields={'id','version','module','category','title','description','steps','created','diagnostics'}
local limits={id=80,version=48,module=24,category=24,title=96,description=3000,steps=1600,created=16,diagnostics=1800}
function R.Validate(p)
    if type(p)~='table' or not R.ID(p.id) or not moduleKeys[p.module] or not categoryKeys[p.category] then return false end
    for _,k in ipairs(fields) do if not R.Text(p[k],limits[k]) then return false end end
    if not p.title:find('%S') or not p.description:find('%S') or not p.created:match('^%d+$') then return false end
    return tonumber(p.created)~=nil and tonumber(p.created)<=999999999999
end
function R.Encode(p)
    if not R.Validate(p) then return nil,'Enter a title and description within the field limits.' end
    local parts={'R1'}
    for _,k in ipairs(fields) do local v=p[k];parts[#parts+1]=#v..':'..v end
    local wire=table.concat(parts)
    if #wire>R.MAX_BYTES then return nil,'The report is too large. Shorten its description or steps.' end
    return wire
end
function R.Decode(wire)
    if not R.Text(wire,R.MAX_BYTES) or wire:sub(1,2)~='R1' then return end
    local at,p=3,{}
    for _,k in ipairs(fields) do
        local colon=wire:find(':',at,true);if not colon or colon-at>5 then return end
        local digits=wire:sub(at,colon-1);if not digits:match('^%d+$') then return end
        local n=tonumber(digits);if n>limits[k] or colon+n>#wire then return end
        p[k]=wire:sub(colon+1,colon+n);at=colon+n+1
    end
    if at~=#wire+1 or not R.Validate(p) then return end
    return p
end
function R.Changed()
    R.revision=(R.revision or 0)+1
    if ns.Workspace and ns.Workspace.Queue then ns.Workspace.Queue() end
end
local states={draft=true,pending=true,sending=true,received=true,failed=true}
local inboxStates={New=true,Reviewing=true,Confirmed=true,Fixed=true,Closed=true}
local function Dense(array,limit)
    if type(array)~='table' then return false end
    local count=0
    for k in pairs(array) do
        count=count+1;if count>limit or type(k)~='number' or k<1 or k%1~=0 or k>limit then return false end
    end
    return count==#array
end
function R.Initialize()
    if R.db or R.blocked then return end
    if ns.Storage.OlympusWardenRelayDB==nil then ns.Storage.OlympusWardenRelayDB={schema=R.SCHEMA,reports={},inbox={},serial=0} end
    local db=ns.Storage.OlympusWardenRelayDB
    if type(db)~='table' or db.schema~=R.SCHEMA or not Dense(db.reports,R.MAX_LOCAL) or not Dense(db.inbox,R.MAX_INBOX)
        then R.blocked='Relay data needs recovery; the original saved data has been kept.';return end
    local ids={}
    for _,r in ipairs(db.reports) do
        if type(r)~='table' or not R.ID(r.id) or ids[r.id] or not states[r.state] or type(r.fields)~='table' then R.blocked='Relay reports need recovery; saved data has been kept.';return end
        ids[r.id]=true
        for _,k in ipairs({'lastAttempt','nextAttempt','attempts'}) do
            local v=r[k]
            if v~=nil and (type(v)~='number' or v~=v or v<0 or v>999999999999 or v%1~=0) then R.blocked='Relay delivery metadata needs recovery; saved data has been kept.';return end
        end
        if r.autoRetry~=nil and type(r.autoRetry)~='boolean' or r.selfTestReceiver~=nil and not R.Text(r.selfTestReceiver,180) then R.blocked='Relay delivery settings need recovery; saved data has been kept.';return end
        for _,k in ipairs({'title','description','steps'}) do if not R.Text(r.fields[k] or '',limits[k]) then R.blocked='A Relay draft needs recovery; saved data has been kept.';return end end
        if (r.state~='draft' and not r.wire) or r.wire and (not R.Decode(r.wire) or R.Checksum(r.wire)~=r.checksum or R.Decode(r.wire).id~=r.id) then R.blocked='A Relay submission needs recovery; saved data has been kept.';return end
    end
    local keys={}
    for _,r in ipairs(db.inbox) do
        if type(r)~='table' or not R.Text(r.sender,180) or not R.Text(r.key,270) or keys[r.key] or not inboxStates[r.state]
            or not R.Decode(r.wire) or R.Checksum(r.wire)~=r.checksum then R.blocked='The Relay inbox needs recovery; saved data has been kept.';return end
        keys[r.key]=true
    end
    R.db=db;db.serial=type(db.serial)=='number' and db.serial==db.serial and math.max(0,math.min(1000000000,math.floor(db.serial))) or 0
    for _,r in ipairs(db.reports) do if r.state=='sending' then r.state='pending';r.status='Interrupted before a receipt. Delivery remains queued.' end end
end
-- Recipient-private selected historical shares live in Relay's existing save,
-- never Chronicle evidence or the public Aether ledger. Original wire bytes
-- are retained; validation is atomic and recovery never rewrites a bad root.
R.RECEIVED_VERSION=1;R.RECEIVED_MAX=32;R.RECEIVED_BYTES=393216
function R.Received(owner,storage)
    R.Initialize();storage=storage or R.db
    if not storage or not ns.ChronicleStore.GUID(owner) then return nil,'RECEIVED_OWNER_OR_STORE' end
    local root=storage.directHistory
    if root==nil then return {},nil end
    if type(root)~='table' or root.schema~=1 or type(root.owners)~='table' or getmetatable(root) then return nil,'RECEIVED_RECOVERY_REQUIRED' end
    for k in pairs(root) do if k~='schema' and k~='owners' then return nil,'RECEIVED_ROOT_FIELD' end end
    local owners=0
    for guid,rows in pairs(root.owners) do
        owners=owners+1;if owners>16 or not ns.ChronicleStore.GUID(guid) or not Dense(rows,R.RECEIVED_MAX) then return nil,'RECEIVED_CAPACITY' end
        local bytes,seen=0,{}
        for _,row in ipairs(rows) do
            if type(row)~='table' or getmetatable(row) then return nil,'RECEIVED_RECORD' end
            for k in pairs(row) do if not ({id=true,recipient=true,sender=true,principal=true,acceptedAt=true,receivedAt=true,requestID=true,reviewHash=true,snapshot=true,sourceClass=true})[k] then return nil,'RECEIVED_FIELD' end end
            if row.recipient~=guid or not ns.ChronicleStore.GUID(row.sender) or not R.Text(row.principal,128) or not R.Text(row.requestID,96)
                or type(row.acceptedAt)~='number' or type(row.receivedAt)~='number' or row.acceptedAt~=row.acceptedAt or row.receivedAt~=row.receivedAt
                or row.acceptedAt<1 or row.receivedAt>4102444800 or row.acceptedAt%1~=0 or row.receivedAt%1~=0 or row.acceptedAt>row.receivedAt
                or row.sourceClass~='received_direct' or not ns.AthenaSharePolicy.ValidateHistorical(row.snapshot)
                or row.snapshot.observerOwner:match('/(Player%-.+)$')~=row.sender then return nil,'RECEIVED_POLICY' end
            local wire=ns.ChronicleBackup.Encode(row.snapshot);local hash=ns.PackCrypto.Hex(ns.PackCrypto.SHA256(wire))
            if row.reviewHash~=hash or row.id~=row.sender..'/'..hash or seen[row.id] then return nil,'RECEIVED_HASH_OR_DUPLICATE' end
            seen[row.id]=true;bytes=bytes+#wire+512;if bytes>R.RECEIVED_BYTES then return nil,'RECEIVED_BYTES' end
        end
    end
    return root.owners[owner] or {}
end
function R.ImportHistorical(recipient,sender,principal,requestID,snapshot,acceptedAt,receivedAt,reviewHash,userAccepted,storage)
    if userAccepted~=true then return false,'EXPLICIT_RECIPIENT_ACCEPT_REQUIRED' end
    R.Initialize();storage=storage or R.db
    local rows,why=R.Received(recipient,storage);if not rows then return false,why end
    local clean=ns.AthenaSharePolicy.ValidateHistorical(snapshot)
    if not clean or clean.observerOwner:match('/(Player%-.+)$')~=sender then return false,'RECEIVED_SOURCE' end
    local wire=ns.ChronicleBackup.Encode(clean);local hash=ns.PackCrypto.Hex(ns.PackCrypto.SHA256(wire))
    if hash~=reviewHash or type(acceptedAt)~='number' or type(receivedAt)~='number' or acceptedAt>receivedAt then return false,'EXACT_REVIEW_REQUIRED' end
    local id=sender..'/'..hash
    for _,row in ipairs(rows) do if row.id==id then return true,'ALREADY_IMPORTED' end end
    local staged=ns.Athena.Copy(storage.directHistory or {schema=1,owners={}})
    staged.owners[recipient]=staged.owners[recipient] or {}
    table.insert(staged.owners[recipient],{id=id,recipient=recipient,sender=sender,principal=principal,requestID=requestID,
        acceptedAt=acceptedAt,receivedAt=receivedAt,reviewHash=hash,snapshot=ns.Athena.Copy(clean),sourceClass='received_direct'})
    local valid,err=R.Received(recipient,{directHistory=staged});if not valid then return false,err end
    storage.directHistory=staged;R.Changed();return true,id
end
function R.ReceivedFor(recipient,subject,family)
    local rows,why=R.Received(recipient);if not rows then return nil,why end
    local out={};for _,row in ipairs(rows) do if row.snapshot.guid==subject and (not family or row.snapshot.family==family) then out[#out+1]=ns.Athena.Copy(row) end end
    table.sort(out,function(a,b) return a.snapshot.observedAt>b.snapshot.observedAt end);return out
end
function R.DeleteReceived(recipient,id,explicit)
    if explicit~=true or recipient~=ns.PlayerCard.Own() then return false,'EXACT_RECIPIENT_CONFIRMATION_REQUIRED' end
    local rows,why=R.Received(recipient);if not rows then return false,why end
    local staged=ns.Athena.Copy(R.db.directHistory);if not staged then return false,'RECEIVED_NOT_FOUND' end
    for i,row in ipairs(rows) do if row.id==id then table.remove(staged.owners[recipient],i);R.db.directHistory=staged;R.Changed();return true end end
    return false,'RECEIVED_NOT_FOUND'
end
function R.Find(id)
    if not R.db then return end
    for _,r in ipairs(R.db.reports) do if r.id==id then return r end end
end
function R.New()
    if not R.db then return nil,R.blocked or 'Relay is not ready.' end
    if #R.db.reports>=R.MAX_LOCAL then return nil,'Local reports are full (200). Copy or back up reports before explicitly deleting any.' end
    R.db.serial=R.db.serial+1
    local guid=ns.SafeCall(UnitGUID,'player');local identity=R.Text(guid,128) or 'unavailable'
    local id='r'..R.Now()..'-'..R.Checksum(identity)..'-'..R.db.serial..'-'..math.random(100000,999999)
    local r={id=id,state='draft',created=R.Now(),fields={module='suite',category='bug',title='',description='',steps=''},status='Draft saved on this computer.'}
    R.db.reports[#R.db.reports+1]=r;R.Changed();return r
end
function R.Save(id,fields)
    local r=R.Find(id)
    if not r or r.state~='draft' then return false,'Only drafts can be edited. Duplicate a submitted report to make changes.' end
    if not moduleKeys[fields.module] or not categoryKeys[fields.category] then return false,'Choose a module and category.' end
    local copy={module=fields.module,category=fields.category}
    for _,k in ipairs({'title','description','steps'}) do
        if not R.Text(fields[k] or '',limits[k]) then return false,'A report field exceeds its limit or contains unsupported control characters.' end
        copy[k]=fields[k] or ''
    end
    r.fields=copy;r.updated=R.Now();R.Changed();return true
end
function R.Payload(r,diagnostics)
    local f=r.fields
    return {id=r.id,version=ns.VERSION,module=f.module,category=f.category,title=f.title,description=f.description,steps=f.steps,created=tostring(r.created),diagnostics=diagnostics or ''}
end
function R.Submit(id,diagnostics)
    local r=R.Find(id);if not r or r.state~='draft' then return false,'Only an unsent draft can be submitted.' end
    if r.selfTestReceiver and (not ns.RelayTransport.IsDeveloper() or r.selfTestReceiver~=ns.RelayTransport.LocalIdentity()) then return false,'Submit this self-test on its original developer character.' end
    if diagnostics~='' and not (ns.RelayDiagnostics and ns.RelayDiagnostics.Valid(diagnostics)) then return false,'Prepare and preview diagnostics before sending.' end
    local count=0;for _,v in ipairs(R.db.reports) do if v.state=='pending' or v.state=='sending' then count=count+1 end end
    if count>=20 then return false,'The submission queue is full (20). Keep this draft and retry later.' end
    local wire,err=R.Encode(R.Payload(r,diagnostics));if not wire then return false,err end
    r.wire=wire;r.checksum=R.Checksum(wire);r.state='pending';r.submitted=R.Now();r.status='Queued for automatic delivery; no receipt yet.';r.autoRetry=true;r.nextAttempt=R.Now();R.Changed()
    if ns.RelayTransport then ns.RelayTransport.Try(id);ns.RelayTransport.Schedule() end
    return true
end
function R.Copy(id)
    local old=R.Find(id);if not old then return end
    local r,err=R.New();if not r then return nil,err end
    R.Save(r.id,old.fields);return r
end
function R.Delete(id,inbox)
    if not R.db or inbox and not ns.RelayTransport.IsDeveloper() then return false end
    local list=inbox and R.db.inbox or R.db.reports
    for n,r in ipairs(list) do if (inbox and r.key or r.id)==id then
        if not inbox and ns.RelayTransport and ns.RelayTransport.Busy(id) then return false,'Wait for the active transfer to finish.' end
        table.remove(list,n);if ns.RelayTransport then ns.RelayTransport.Schedule() end;R.Changed();return true
    end end
    return false
end
function R.Receipt(sender,id,checksum)
    if not R.db then return end
    local key=sender..'/'..id
    for _,r in ipairs(R.db.inbox) do if r.key==key then return r.checksum==checksum and r or false end end
end
function R.Receive(sender,p,wire,checksum)
    if not R.db or not ns.RelayTransport.IsDeveloper() or not R.Validate(p) or R.Encode(p)~=wire then return false end
    local old=R.Receipt(sender,p.id,checksum);if old~=nil then return old~=false end
    if #R.db.inbox>=R.MAX_INBOX then return false end
    R.db.inbox[#R.db.inbox+1]={key=sender..'/'..p.id,sender=sender,wire=wire,checksum=checksum,received=R.Now(),state='New'}
    R.Changed();return true
end
function R.SetInboxState(key,state)
    if not R.db or not ns.RelayTransport.IsDeveloper() or not ({New=true,Reviewing=true,Confirmed=true,Fixed=true,Closed=true})[state] then return false end
    for _,r in ipairs(R.db.inbox) do if r.key==key then r.state=state;r.reviewed=R.Now();R.Changed();return true end end
end
function R.Export(r,inbox)
    if not r then return 'Choose a report.' end
    local p=r.wire and R.Decode(r.wire) or R.Payload(r,r.supportLocalOnly and R.Text(r.supportDiagnostics or '',1800) or '')
    if not p then return 'This report needs recovery.' end
    local lines={'Fireside bug report',p.id,'Version: '..p.version,'Module: '..p.module,'Category: '..p.category,'Status: '..r.state}
    if inbox then lines[#lines+1]='Received from: '..r.sender end
    if r.selfTestReceiver then lines[#lines+1]='Developer self-test to: '..r.selfTestReceiver end
    if not inbox and r.wire then lines[#lines+1]='Automatic delivery: '..(r.autoRetry==true and 'enabled' or 'paused / completed') end
    for _,k in ipairs({'title','description','steps','diagnostics'}) do lines[#lines+1]='\n'..k..':\n'..p[k] end
    return table.concat(lines,'\n')
end
