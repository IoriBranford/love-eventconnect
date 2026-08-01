---@class ihash<T>
---@field [integer] T|false
---@field [T] integer
local ihash = {}

---add element
---@generic T
---@param h ihash<T>
---@param t T
---@return integer i
function ihash.add(h, t)
    local i = h[t] or #h+1
    h[i] = t
    h[t] = i
    return i
end

---remove element
---@generic T
---@param h ihash<T>
---@param t T
---@return integer? i
---@return T? u
function ihash.remove(h, t)
    local i = h[t]
    if not i then return end

    local u = h[#h]
    h[i] = u
    h[u] = i
    h[#h] = nil
    h[t] = nil
    return i, u
end

---remove element preserving order
---@generic T
---@param h ihash<T>
---@param t T
---@return integer? i
function ihash.removeordered(h, t)
    local i = h[t]
    if i == #h then
        h[i] = nil
    elseif i then
        h[i] = false
    end
    h[t] = nil
    return i
end

---prune dead elements
---@generic T
---@param h ihash<T>
---@param tdead fun(t:T):boolean
---@param tcleanup fun(t:T)?
---@return integer n
function ihash.prune(h, tdead, tcleanup)
    tcleanup = tcleanup or function() end
    local n = 0
    local remove = ihash.remove
    for i = #h, 1, -1 do
        local t = h[i]
        if tdead(t) then
            tcleanup(t)
            remove(h, t)
            n = n + 1
        end
    end
    return n
end

---prune dead elements preserving order
---@generic T
---@param h ihash<T>
---@param tdead (fun(t:T):boolean)?
---@param tcleanup fun(t:T)?
---@return integer n
function ihash.pruneordered(h, tdead, tcleanup)
    tdead = tdead or function() return false end
    tcleanup = tcleanup or function() end
    local remove = ihash.removeordered
    local newi
    local n = 0
    for i = 1, #h do
        local t = h[i]
        if t and not tdead(t) then
            if newi then
                h[i] = false
                h[newi] = t
                h[t] = newi
                newi = i
            end
        else
            if t then
                tcleanup(t)
                remove(h, t)
                n = n + 1
            end
            newi = newi or i
        end
    end
    while #h > 0 and not h[#h] do
        h[#h] = nil
    end
    return n
end

function ihash.sort(h, cmp)
    table.sort(h, function(a, b)
        return a and not b
            or a and b and cmp(a, b)
    end)

    while #h > 0 and not h[#h] do
        h[#h] = nil
    end

    for i = 1, #h do
        h[h[i]] = i
    end
end

return ihash
