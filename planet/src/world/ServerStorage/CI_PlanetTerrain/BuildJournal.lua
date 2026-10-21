-- Persistent build bookkeeping; independent of Roblox services for fault-injection tests.
local J={}
local function integer(n) return type(n)=='number' and n%1==0 end
local function encode(b)
    local parts=table.create(32)
    for i=0,31 do parts[i+1]=string.format('%02x',buffer.readu8(b,i)) end
    return table.concat(parts)
end
local function decode(s)
    assert(type(s)=='string' and #s==64 and not string.find(s,'[^0-9a-f]'),'Corrupt build journal block')
    local b=buffer.create(32)
    for i=0,31 do buffer.writeu8(b,i,tonumber(string.sub(s,i*2+1,i*2+2),16)) end
    return b
end
function J.open(store,identity,count)
    assert(type(identity)=='string' and #identity>0 and integer(count) and count>0,'Invalid build journal identity')
    local expected='CI-native-build-1:'..identity..':'..count
    local previous=store.get('Identity')
    if previous then assert(previous==expected,'Build state belongs to a different dataset or configuration')
    else store.set('Identity',expected) end
    local blocks={}
    local done=0
    for group=0,math.ceil(count/256)-1 do
        local raw=store.get('B'..group)
        local b=if raw then decode(raw) else buffer.create(32)
        blocks[group]=b
        for offset=0,255 do
            local bit=bit32.band(buffer.readu8(b,math.floor(offset/8)),bit32.lshift(1,offset%8))~=0
            if group*256+offset>=count then assert(not bit,'Build journal has out-of-range bits')
            elseif bit then done+=1 end
        end
    end
    local rawPending=store.get('Pending')
    local pending=if rawPending then tonumber(rawPending) else 0
    assert(integer(pending) and pending>=0 and pending<=count,'Corrupt pending chunk')
    local function check(i) assert(integer(i) and i>=1 and i<=count,'Invalid chunk index') end
    local function isDone(i)
        check(i);local index=i-1
        return bit32.band(buffer.readu8(blocks[math.floor(index/256)],math.floor(index%256/8)),bit32.lshift(1,index%8))~=0
    end
    if pending>0 and isDone(pending) then store.set('Pending','0');pending=0 end
    return {
        isDone=isDone,
        completed=function()return done end,
        pending=function()return pending end,
        begin=function(i)
            check(i);assert(not isDone(i),'Chunk already complete')
            assert(pending==0 or pending==i,'Recover pending chunk before continuing')
            store.set('Pending',tostring(i));pending=i
        end,
        finish=function(i)
            check(i);assert(pending==i,'Chunk was not begun')
            local index=i-1;local group=math.floor(index/256);local offset=math.floor(index%256/8)
            local b=buffer.create(32);buffer.copy(b,0,blocks[group])
            buffer.writeu8(b,offset,bit32.bor(buffer.readu8(b,offset),bit32.lshift(1,index%8)))
            -- Commit marker only after caller's terrain write. Persist before changing in-memory state.
            store.set('B'..group,encode(b));blocks[group]=b;done+=1
            store.set('Pending','0');pending=0
        end,
    }
end
return table.freeze(J)
