# love.eventconnect

LOVE event listening system

## Connecting

Connect listeners to each event.

```lua
-- main.lua
require "love.eventconnect"

local world = {}
function world.update(dt) end
function world.draw() end

local hud = {}
function hud.update(dt) end
function hud.draw() end

local menu = {}
function menu.mousepressed(x, y, b, t, p) end
function menu.mousemoved(x, y, dx, dy, t) end
function menu.mousereleased(x, y, b, t, p) end
function menu.update(dt) end
function menu.draw() end

function love.load()
    -- connect to every event for which there is a function
    love.event.connectAll(world)

    -- connect to single event
    love.event.connect(hud, "update")

    -- 3rd param true if listener must receive event last
    -- otherwise may be inserted into a previous listener's slot
    love.event.connect(hud, "draw", true)

    -- optional string format saves connection ids in the listener
    -- for disconnecting later
    -- e.g. mousepressedconnection, updateconnection, drawconnection
    love.event.connectAll(menu, "%sconnection")

    -- world, hud, menu will have update and draw called
    -- in the order they were connected
    -- menu will receive mouse events
end

function menu.close()
    -- make sure to use the same string format you used for connectAll
    love.event.disconnectAll(menu, "%sconnection")
end
```

## Self Mode

If your listening functions expect a self, enable Self Mode. love callbacks don't have a self and are not affected.

```lua
local world = class()
function world:update(dt) end
function world:draw() end

love.event.setSelfMode(true)
-- world will have :update and :draw called
-- with an initial self parameter
```

## Event Directions

Each event has a direction value. Positive means listeners receive the event in the order connected; negative means the reverse order. love callbacks are not affected; they always get the event first.

By default, positive is considered outward (application to user) and negative inward (user to application). The following input events default to negative:

- gamepadaxis, gamepadpressed, gamepadreleased
- joystickaxis, joystickhat, joystickpressed, joystickreleased
- keypressed, keyreleased
- mousemoved, mousepressed, mousereleased, wheelmoved
- touchmoved, touchpressed, touchreleased
- filedropped, directorydropped

You can set an event's direction with
```lua
love.event.setDirection(ev, -1)
```

## Event Requests

A listener function can return "stop" to prevent propagation to the listeners after it.

```lua
function button.mousereleased(x, y, b, t, p)
    if button.isPointInside(x, y) then
        button.press()
        return "stop"
    end
end
```

To change the event arguments for the listeners after, return "args" followed by the new arguments.

```lua
function camera.mousepressed(x, y, b, t, p)
    x, y = camera.screenToWorld(x, y)
    return "args", x, y, b, t, p
end
```

## Custom Events

You can define and send your own events.

```lua
love.event.newEvent("fixedupdate", 1)
-- direction is optional, defaults to 1

local fps = 60
local lerp = 0
function love.update(dt)
    local n
    n, lerp = math.modf(lerp + dt*fps)
    for _ = 1, n do
        love.event.send("fixedupdate")
    end
end
```

## Custom Events with Self

`love.event.send` follows Self Mode. If you must mix self and non-self listeners, define separate self and non-self events, then leave Self Mode off and send events with love.event.send and love.event.sendSelf accordingly. Don't connect a self listener and a non-self listener to the same event.

```lua
function love.load()
    love.event.newEvents({
        fixedupdate = 1,
        fixedupdate_s = 1
    })

    local ball = {}
    function ball.fixedupdate() end
    function ball:fixedupdate_s() end

    love.event.connectAll(ball)
end

local fps = 60
local lerp = 0
function love.update(dt)
    local n
    n, lerp = math.modf(lerp + dt*fps)
    n = math.min(n, 3)
    for _ = 1, n do
        love.event.send("fixedupdate")
        love.event.sendSelf("fixedupdate_s")
    end
end
```

## Resetting

To clear all listeners from all events
```lua
love.event.reset() -- pass true to also forget custom events
```
