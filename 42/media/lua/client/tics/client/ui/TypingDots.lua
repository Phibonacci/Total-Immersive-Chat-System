-- Three dots above a player who is typing. Their look tells what is coming: the dots are
-- the color of the channel, small and faint for a whisper, big and quick for a yell, and
-- a slow wave for /me and /do (an action, not speech).

local Coordinates = require('tics/client/utils/Coordinates')

local TypingDots = ISUIElement:derive('TypingDots')

local DOT_TEXTURE = 'media/ui/tics/typing-dots/typing-dot.png'
local DOT_COUNT = 3
local SHADOW_ALPHA = 0.45 -- dark disc behind each dot, readable on any ground

-- size: dot diameter in pixels, alpha: brightest dot, period: one wave in ms,
-- bounce: pixels a dot rises at the top of the wave
local STYLES = {
    whisper = { size = 3, alpha = 0.55, period = 1500, bounce = 0 },
    low     = { size = 4, alpha = 0.7, period = 1200, bounce = 0 },
    say     = { size = 5, alpha = 0.9, period = 1000, bounce = 1 },
    yell    = { size = 7, alpha = 1, period = 600, bounce = 2 },
    me      = { size = 4, alpha = 0.85, period = 1800, bounce = 2 },
    ['do']  = { size = 4, alpha = 0.85, period = 1800, bounce = 2 },
}
local DEFAULT_STYLE = { size = 4, alpha = 0.75, period = 1000, bounce = 1 } -- channels that are not heard

local WHITE = { 1, 1, 1 }

-- color of the channel as in the chat, white when unknown
local function ChannelColor(channel)
    local ok, color = pcall(BuildColorFromMessageType, channel)
    if ok and type(color) == 'table' and color[1] then
        return { color[1] / 255, color[2] / 255, color[3] / 255 }
    end
    return WHITE
end

function TypingDots:setType(channel)
    if channel == self.channel and self.style then
        return
    end
    self.channel = channel
    self.style = STYLES[channel] or DEFAULT_STYLE
    self.color = ChannelColor(channel)
    local size = self.style.size
    self.gap = math.max(2, math.floor(size * 0.7))
    self:setWidth(DOT_COUNT * size + (DOT_COUNT - 1) * self.gap + 2)
    self:setHeight(size + self.style.bounce + 2)
end

function TypingDots:render()
    local time = getTimestampMs()
    if time - self.startingTime > self.timer then
        self.dead = true
        return
    end
    local x, y = Coordinates.CenterTopOfPlayer(self.player, self.width, self.height)
    if x == nil then
        return
    end
    self:setX(x)
    self:setY(y - self.height)

    local texture = getTexture(DOT_TEXTURE)
    if texture == nil then
        return
    end
    local style = self.style
    local size = style.size
    local r, g, b = self.color[1], self.color[2], self.color[3]
    for index = 0, DOT_COUNT - 1 do
        -- a wave runs through the dots: each one brightens and rises after the previous one
        local phase = ((time - self.animationStart) / style.period - index / DOT_COUNT) % 1
        local wave = math.max(0, math.sin(phase * math.pi * 2))
        local dotX = 1 + index * (size + self.gap)
        local dotY = 1 + style.bounce - math.floor(style.bounce * wave + 0.5)
        local alpha = style.alpha * (0.4 + 0.6 * wave)
        self:drawTextureScaled(texture, dotX - 1, dotY - 1, size + 2, size + 2, SHADOW_ALPHA * alpha, 0, 0, 0)
        self:drawTextureScaled(texture, dotX, dotY, size, size, alpha, r, g, b)
    end
end

-- the player is still typing, maybe in another channel
function TypingDots:refresh(channel)
    self.startingTime = getTimestampMs()
    if channel then
        self:setType(channel)
    end
end

function TypingDots:new(player, timer, channel)
    TypingDots.__index = self
    setmetatable(TypingDots, { __index = ISUIElement })
    local o = ISUIElement:new(0, 0, 20, 6)
    setmetatable(o, TypingDots)
    o.player = player
    o.startingTime = getTimestampMs()
    o.animationStart = o.startingTime -- not reset by refresh: the wave keeps running smoothly
    o.timer = timer * 1000
    o.dead = false
    o:instantiate()
    o:setType(channel)
    return o
end

return TypingDots
