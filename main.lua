require "love.eventconnect"

function love.load()
    local ok, debugger = pcall(require, "lldebugger")
    if ok and debugger then
        debugger.start()
    end

    love.event.newEvent("fixedupdate")
end

local RainSpeed = 50

local function newRainDrop(x)
    local self = {}
    local y, y2 = 0, 0
    local alpha = love.math.random()

    function self.fixedupdate()
        y, y2 = y2, y2 + RainSpeed
        local gh = love.graphics.getHeight()
        if y >= gh then
            love.event.disconnectAll(self, "%sconnection")
            return
        end
    end

    function self.draw()
        love.graphics.setColor(1,1,1,alpha)
        love.graphics.line(x, y, x, y2)
    end

    love.event.connectAll(self, "%sconnection")

    return self
end

local fps = 60
local lerp = 0
function love.update(dt)
    local n
    n, lerp = math.modf(lerp + dt*fps)
    if n >= 1 then
        newRainDrop(love.math.random(0, 800))
        love.event.send("fixedupdate")
    end
end