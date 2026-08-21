local coordinates = require('tics/client/utils/coordinates')

local RangeIndicator = ISUIElement:derive("RangeIndicator")

local function PreLoadTextures()
    --getTexture(IsoBordersTexturePath)
end

function IsSamePosition(firstPos, nextPos)
    return firstPos.x == nextPos.x and firstPos.y == nextPos.y and firstPos.z == nextPos.z
end

-- draw a square at the center and parts of losanges on the borders to avoid
-- drawing too many losanges and hurt the performances
function RangeIndicator:show()
    local x, y, z = self.object:getX(), self.object:getY(), self.object:getZ() + 0.5
    local pos = { x = math.floor(x), y = math.floor(y), z = math.floor(z) }

    if self.markers then
        if IsSamePosition(pos, self.lastPos) then
            return
        else
            self:hide()
        end
    end
    self.lastPos = pos

    self.markers = {}
    if self.range > 30 then
        local square = self.object:getSquare()
        if square == nil then
            return
        end
        local marker = getWorldMarkers():addGridSquareMarker("circle_center", nil, square,
                self.color[1] / 255, self.color[2] / 255, self.color[3] / 255, true, self.range, 1, 0.3, 0.3)
        table.insert(self.markers, marker)
        return
    end

    local maxRange = self.range - 1

    for yModifier = -maxRange, maxRange do
        local lineY = y + yModifier
        local maxLineRange = maxRange - math.abs(yModifier)
        for xModifier =  -maxLineRange , maxLineRange do
            local lineX = x + xModifier
            local square = self.object:getCell():getOrCreateGridSquare(lineX, lineY, z)

            local marker = getWorldMarkers():addGridSquareMarker("circle_center", nil, square,
                self.color[1] / 255, self.color[2] / 255, self.color[3] / 255, true, 0.1, 1, 0.3, 0.3)
            table.insert(self.markers, marker)
        end
    end
end

function RangeIndicator:hide()
    if self.markers == nil then
        return
    end
    for _, marker in ipairs(self.markers) do

        -- -- the highlight way
        -- floor:setHighlighted(false)
        -- -- floor:setBlink(false);

        -- -- The tile object way
        -- square:RemoveTileObject(marker);

        -- The grid square marker way
        marker:remove()

        -- -- Maybe related to tile object way?
        -- square:getSpecialObjects():remove(marker);
        -- square:getObjects():remove(marker);
        -- square:transmitRemoveItemFromSquare(marker)
    end
    self.markers = nil
end

function RangeIndicator:subscribe()
    self:show()
end

function RangeIndicator:unsubscribe()
    self:hide()
end

function RangeIndicator:new(object, range, color)
    RangeIndicator.__index = self
    setmetatable(RangeIndicator, { __index = ISUIElement })
    local o = ISUIElement:new(0, 0, 20, 6)
    setmetatable(o, RangeIndicator)

    o:setX(0)
    o:setY(0)
    o.object = object
    o.range = range
    o.color = color
    o.keepOnScreen = false
    o:instantiate()

    -- TODO: try to use of the non documented events with missleading names to do that
    PreLoadTextures()
    return o
end

return RangeIndicator
