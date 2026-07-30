local dispatch = require "dispatch"

---@alias evdir integer

local LoveEvents = {
    update = 1,
    draw = 1,

    filedropped = -1,
    directorydropped = -1,
    displayrotated = 1,
    focus = 1,
    visible = 1,
    resize = 1,

    joystickadded = 1,
    joystickremoved = 1,

    gamepadaxis = -1,
    gamepadpressed = -1,
    gamepadreleased = -1,
    joystickaxis = -1,
    joystickhat = -1,
    joystickpressed = -1,
    joystickreleased = -1,

    keypressed = -1,
    keyreleased = -1,

    lowmemory = 1,

    mousefocus = 1,
    mousemoved = -1,
    mousepressed = -1,
    mousereleased = -1,
    wheelmoved = -1,

    quit = 1,

    textedited = -1,
    textinput = -1,

    threaderror = 1,

    touchmoved = -1,
    touchpressed = -1,
    touchreleased = -1,

    -- in LOVE 12
    audiodisconnected = 1,
    dropbegan = -1,
    dropcompleted = -1,
    dropmoved = -1,
    exposed = 1,
    joysticksensorupdated = 1,
    localechanged = 1,
    occluded = 1,
    sensorupdated = 1,
}

local Conns = dispatch.new()
local EventDirs = {}
local SelfMode = false

---@alias conn integer

function love.event.setSelfMode(selfmode)
    SelfMode = selfmode
end

function love.event.setDirection(ev, dir)
    EventDirs[ev] = dir
end

---Register a new event
function love.event.newEvent(ev, dir)
    Conns:newevent(ev)
    EventDirs[ev] = dir or 1
end

---Register multiple new events
---@param evs table<string, evdir>
function love.event.newEvents(evs)
    local newev = love.event.newEvent
    for ev, dir in pairs(evs) do
        newev(ev, dir)
    end
end

love.event.newEvents(LoveEvents)

---Reset the event engine
function love.event.reset()
    Conns = dispatch.new()
    love.event.newEvents(LoveEvents)
end

function love.event.resetConnections()
    Conns:clearallsubs()
end

function love.event.addSelfLoveEvents(format)
    local newev = love.event.newEvent
    local sformat = string.format
    format = format or "%sself"
    for ev, dir in pairs(LoveEvents) do
        ev = sformat(format, ev)
        newev(ev, dir)
    end
end

---Connect to event
---@param ev string
---@param l listener
---@param after boolean?
---@return integer
function love.event.connect(l, ev, after)
    return Conns:sub(l, ev, after)
end

---Connect all of a table's matching functions to events
---@param l listener
---@param after boolean?
function love.event.connectAll(l, format, after)
    Conns:allsub(l, format, after)
end

---Disconnect from event
---@param ev string
---@param conn conn
---@param l listener?
function love.event.disconnect(l, ev, conn)
    Conns:unsub(l, ev, conn)
end

---Disconnect all of a table's matching functions from events
---@param l any
function love.event.disconnectAll(l, format)
    Conns:allunsub(l, format)
end

local function send(lovef, fsend, rsend, ev, a,b,c,d,e,f)
    if lovef then
        local req, u, v, w, x, y, z
            = lovef(a,b,c,d,e,f)

        if req == "stop" then
            return req
        end
        if req == "args" then
            a,b,c,d,e,f = u, v, w, x, y, z
        end
    end
    if (EventDirs[ev] or 1) < 0 then
        rsend(Conns, ev, a,b,c,d,e,f)
    else
        fsend(Conns, ev, a,b,c,d,e,f)
    end
end

---Broadcast an event immediately, bypassing love event queue
---@param ev string
---@param ... any
function love.event.send(ev, ...)
    send(love[ev], Conns.send, Conns.rsend, ev, ...)
end

---Broadcast an event immediately, bypassing love event queue,
---callbacks receive the listening table as 1st argument
---@param ev any
---@param ... any
function love.event.sendSelves(ev, ...)
    send(love[ev], Conns.sendself, Conns.rsendself, ev, ...)
end

---@diagnostic disable-next-line: duplicate-set-field
function love.run()
    if love.load then
        love.load(love.arg.parseGameArguments(arg), arg)
    end

    -- We don't want the first frame's dt to include time taken by love.load.
    if love.timer then love.timer.step() end

    local dt = 0

    -- Main loop time.
    return function()
        local fsend, rsend
        if SelfMode then
            fsend, rsend = Conns.sendself, Conns.rsendself
        else
            fsend, rsend = Conns.send, Conns.rsend
        end

        -- Process events.
        if love.event then
            love.event.pump()
            for name, a, b, c, d, e, f in love.event.poll() do
                if name == "quit" then
                    if not love.quit or not love.quit() then
                        return a or 0
                    end
                else
                    send(love.handlers[name], fsend, rsend,
                        name, a,b,c,d,e,f)
                end
            end
        end

        -- Update dt, as we'll be passing it to update
        if love.timer then dt = love.timer.step() end

        -- Call update and draw
        send(love.update, fsend, rsend, "update", dt) -- will pass 0 if love.timer is disabled

        if love.graphics and love.graphics.isActive() then
            love.graphics.origin()
            love.graphics.clear(love.graphics.getBackgroundColor())

            send(love.draw, fsend, rsend, "draw")

            love.graphics.present()
        end

        if love.timer then love.timer.sleep(0.001) end
    end
end