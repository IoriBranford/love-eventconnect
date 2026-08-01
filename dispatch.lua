local ihash = require "ihash"
local sformat = string.format

---@alias evreq "args"|"stop"
---@alias evfunc fun(...):evreq?,...
---@class listener
---@field [string] evfunc
---@field __evco thread?

---@class dispatch
---@field events table<string, ihash<listener>>
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
function dispatch:sub(l, ev)
    assert(type(l[ev]) == "function")
    self:newevent(ev)
    local ls = self.events[ev]
    return ihash.add(ls, l)
end

function dispatch:multisub(l, ...)
    local nev = select("#", ...)
    local sub = self.sub
    for i = 1, nev do
        local ev = select(i, ...)
        sub(self, l, ev)
    end
end

local function allsub(self, l, cond)
    cond = cond or function (ev, f)
        return type(f) == "function"
    end

    for ev, f in pairs(l) do
        if cond(ev, f) then
            self:sub(l, ev)
        end
    end

    local mt = getmetatable(l)
    if not mt then return end

    for ev, f in pairs(mt) do
        if not rawget(l, ev) and cond(ev, f) then
            self:sub(l, ev)
        end
    end
end

function dispatch:allsub(l, force)
    local evs = self.events
    local cond = not force and
        function (ev, f)
            return evs[ev] and type(f) == "function"
        end
    allsub(self, l, cond)
end

---Unsubscribe
---@param l listener
---@param ev string
function dispatch:unsub(l, ev)
    local ls = self.events[ev]
    return ls and ihash.removeordered(ls, l)
end

function dispatch:allunsub(l)
    local unsub = self.unsub
    for ev in pairs(l) do
        unsub(self, l, ev)
    end

    local mt = getmetatable(l)
    if not mt then return end

    for ev in pairs(mt) do
        unsub(self, l, ev)
    end
end

function dispatch:clearsubs(ev)
    local ls = self.events[ev]
    if not ls then return end
    for k in pairs(ls) do
        ls[k] = nil
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

---@param ls ihash<listener>
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
---@param ls ihash<listener>
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
    if ls then ihash.sort(ls, cmp) end
end

function dispatch:compact(ev)
    local ls = self.events[ev]
    if ls then ihash.pruneordered(ls) end
end

function dispatch:stats(min)
    min = min or 0
    local stats = {}
    for ev, ls in pairs(self.events) do
        if #ls >= min then
            stats[#stats+1] = sformat("%s:%d", ev, #ls)
            stats[ev] = #ls
        end
    end
    return stats
end

return dispatch