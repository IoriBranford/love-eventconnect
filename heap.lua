local ihash = require "ihash"

---@class heap<T>:ihash<T>
---@field cmp fun(a:T, b:T):boolean
local heap = {}
heap.__index = heap

---@return heap
function heap.new(cmp)
    cmp = cmp or function(a, b) return a < b end
    return setmetatable({cmp = cmp}, heap)
end

local swap = ihash.swap

local function movefwd(h, i, v)
    local cmp = h.cmp
    local fwdi = math.floor(i/2)
    while fwdi > 0 do
        local fwdv = h[fwdi]
        if cmp(fwdv, v) then
            break
        end
        swap(h, i, fwdi)
        i, fwdi = fwdi, math.floor(i/2)
    end
    return i
end

function heap.push(h, v)
    local i = ihash.add(h, v)
    movefwd(h, i, v)
end

local function moveback(h, i, v)
    local cmp = h.cmp
    local last = math.floor(#h/2)
    while i <= last do
        local i1 = 2*i
        local i2 = i1+1
        local v1 = h[i1]
        local v2 = h[i2]
        if cmp(v, v1) then
            if not v2 or cmp(v, v2) then
                break
            else
                swap(h, i, i2)
                i = i2
            end
        elseif not v2 or cmp(v, v2) or cmp(v1, v2) then
            swap(h, i, i1)
            i = i2
        elseif v2 then
            swap(h, i, i2)
            i = i2
        end
    end
    return i
end

function heap.pop(h)
    local v = h[1]
    ihash.remove(h, v)
    moveback(h, 1, h[1])
    return v
end

function heap.update(h, v)
    local i = h[v]
    if not i then return end

    local i2 = movefwd(h, i, v)
    if i2 ~= i then return i2 end
    return moveback(h, i, v)
end

return heap