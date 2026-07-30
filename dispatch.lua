local sformat = string.format

---@alias evreq "args"|"stop"
---@alias evfunc fun(...):evreq?,...
---@class listener
---@field [string] evfunc
---@field __evco thread?

---@class listeners
---@field [integer] listener|false
---@field free integer[]?

---@class dispatch
---@field events table<string, listeners>
local dispatch = {}
dispatch.__index = dispatch

function dispatch.new(...)
    local self = { events = {} } ---@type dispatch
    setmetatable(self, dispatch)
    self:newevents(...)
    return self
end

function dispatch:newevent(ev)
    if not self.events[ev] then
        self.events[ev] = {}
    end
end

function dispatch:newevents(...)
    for i = 1, select("#", ...) do
        local ev = select(i, ...)
        self:newevent(ev)
    end
end

---Subscribe
---@param ev string
---@param l listener
---@return integer i
function dispatch:sub(l, ev, after)
    assert(type(l[ev]) == "function")

    self:newevent(ev)
    local ls = self.events[ev]

    local free = ls.free
    local i = not after and
        free and free[#free]
        or (#ls+1)
    if free then free[#free] = nil end

    ls[i] = l
    return i
end

local function writesub(self, l, ev, format, after)
    if type(l[ev]) ~= "function" then return end
    local s = self:sub(l, ev, after)
    if format then
        local k = sformat(format, ev)
        l[k] = s
    end
end

function dispatch:multisub(l, format, after, ...)
    local nev = select("#", ...)
    for i = 1, nev do
        local ev = select(i, ...)
        writesub(self, l, ev, format, after)
    end
end

local allsub_evs = {}

local function allsub(self, l, format, after, cond)
    cond = cond or function () return true end

    -- not safe to write in a table during pairs loop
    local evs = allsub_evs
    for ev, f in pairs(l) do
        if type(f) == "function" then
            evs[#evs+1] = ev
        end
    end
    for i = 1, #evs do
        local ev = evs[i]
        if cond(ev, l[ev]) then
            writesub(self, l, ev, format, after)
        end
    end
    for i = #evs, 1, -1 do
        evs[i] = nil
    end

    local mt = getmetatable(l)
    if not mt then return end

    for ev, f in pairs(mt) do
        if not rawget(l, ev) and cond(ev, f) then
            writesub(self, l, ev, format, after)
        end
    end
end

function dispatch:allsub(l, format, after, force)
    local evs = self.events
    local cond = not force and
        function (ev) return evs[ev] end
    allsub(self, l, format, after, cond)
end

---Unsubscribe
---@param ev string
---@param i integer
---@param l listener?
function dispatch:unsub(l, ev, i)
    local ls = self.events[ev]
    if not ls then return end

    if l then assert(l == ls[i]) end

    if i == #ls then ls[i] = nil return end

    local free = ls.free or {}
    ls.free = free
    free[#free+1] = i
    ls[i] = false
end

function dispatch:allunsub(l, format)
    local unsub = self.unsub
    for ev in pairs(l) do
        local k = sformat(format, ev)
        local i = l[k]
        if type(i) == "number" then
            unsub(self, l, ev, i)
        end
    end
end

function dispatch:clearsubs(ev)
    local ls = self.events[ev]
    if not ls then return end
    for i = #ls, 1, -1 do
        ls[i] = nil
    end
    local free = ls.free
    if not free then return end
    for i = #free, 1, -1 do
        free[i] = nil
    end
end

function dispatch:clearallsubs()
    local clear = self.clearsubs
    for ev in pairs(self.events) do
        clear(self, ev)
    end
end

local cocreate = coroutine.create
local coresume = coroutine.resume
local costatus = coroutine.status

local yielded = {}

local function cosend1(co, l, ev, a, b, c, d, e, f)
    local ok, req, u, v, w, x, y, z
        = coresume(co, l, ev, a, b, c, d, e, f)
    assert(ok, req)
    if req == "stop" then return req end
    if req == "args" then
        if u ~= nil then a = u end
        if v ~= nil then b = v end
        if w ~= nil then c = w end
        if x ~= nil then d = x end
        if y ~= nil then e = y end
        if z ~= nil then f = z end
    end
    return req, a, b, c, d, e, f
end

---@param ls listeners
---@param i1 integer
---@param i2 integer
---@param di integer
---@param cl fun(l:listener, ev:string, ...):...
---@param ev string
---@param a any
---@param b any
---@param c any
---@param d any
---@param e any
---@param f any
local function cosend(ls, i1, i2, di, cl, ev, a, b, c, d, e, f)
    for i = i1, i2, di do
        local l = ls[i]
        if l then
            local co = cocreate(cl)
            local req
            req, a, b, c, d, e, f
                = cosend1(co, l, ev, a, b, c, d, e, f)
            if req == "stop" then break end
            if costatus(co) ~= "dead" then
                l.__evco = co
                yielded[#yielded+1] = l
            end
        end
    end

    for i = #yielded, 1, -1 do
        local l = yielded[i]
        yielded[i] = nil
        local co = l.__evco
        l.__evco = nil
        local req
        req, a, b, c, d, e, f
            = cosend1(co, l, ev, a, b, c, d, e, f)
        if req == "stop" then
            for i = #yielded, 1, -1 do
                yielded[i] = nil
            end
            break
        end
    end
end

---comment
---@param ls listeners
---@param i1 integer
---@param i2 integer
---@param di integer
---@param cl fun(l:listener, ev:string, ...):...
---@param ev string
---@param a any
---@param b any
---@param c any
---@param d any
---@param e any
---@param f any
local function send(ls, i1, i2, di, cl, ev, a, b, c, d, e, f)
    for i = i1, i2, di do
        local l = ls[i]
        if l then
            local req, u, v, w, x, y, z
                = cl(l, ev, a, b, c, d, e, f)
            if req == "stop" then break end
            if req == "args" then
                if u ~= nil then a = u end
                if v ~= nil then b = v end
                if w ~= nil then c = w end
                if x ~= nil then d = x end
                if y ~= nil then e = y end
                if z ~= nil then f = z end
            end
        end
    end
end

local function callself(l, ev, ...)
    return l[ev](l, ...)
end

local function call(l, ev, ...)
    return l[ev](...)
end

function dispatch:send(ev, ...)
    local ls = self.events[ev]
    if ls then send(ls, 1, #ls, 1, call, ev, ...) end
end

function dispatch:rsend(ev, ...)
    local ls = self.events[ev]
    if ls then send(ls, #ls, 1, -1, call, ev, ...) end
end

function dispatch:sendself(ev, ...)
    local ls = self.events[ev]
    if ls then send(ls, 1, #ls, 1, callself, ev, ...) end
end

function dispatch:rsendself(ev, ...)
    local ls = self.events[ev]
    if ls then send(ls, #ls, 1, -1, callself, ev, ...) end
end

function dispatch:sort(ev, cmp)
    local ls = self.events[ev]
    if not ls then return end

    table.sort(ls, function(a, b)
        return a and not b
            or a and b and cmp(a, b)
    end)

    while not ls[#ls] do
        ls[#ls] = nil
    end
    local sub = ev.."sub"
    for i = 1, #ls do
        ls[i][sub] = i
    end
    ls.free = nil
end

function dispatch:stats(min)
    min = min or 0
    local stats = {}
    for ev, ls in pairs(self.events) do
        if #ls >= min then
            stats[#stats+1] = sformat(
            "%s: %d sub, %d free", ev, #ls, ls.free and #ls.free or 0)
            stats[ev] = #ls
        end
    end
    return table.concat(stats, "; ")
end

return dispatch