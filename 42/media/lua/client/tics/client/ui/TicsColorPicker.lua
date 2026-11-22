-- The game's HSB color picker (ISColorPickerHSB) with a different layout:
-- - the hue slider is moved under the saturation/brightness square and shows the hue gradient
-- - the saturation and brightness sliders move up to fill its place
-- The square, its mouse handling and the color logic are the vanilla ones.

require 'ISUI/ISColorPickerHSB'
require 'RadioCom/ISUIRadio/ISSliderPanel'

local TicsColorPicker = ISColorPickerHSB:derive('TicsColorPicker')

-- same values as the local constants of ISColorPickerHSB.lua
local UI_BORDER_SPACING = 10
local COLORBOX_HGT = 206
local BUTTON_HGT = getTextManager():getFontHeight(UIFont.Small) + 6
local HUE_BAR_INSET = 3 -- space above and below the gradient inside the slider

-- hue slider: a gradient bar instead of the thin grey bar, and a marker on the current hue
local function RenderHueSlider(self)
    local bar = self.sliderBarDim
    local colors = self.hueColors
    local count = #colors
    for i = 1, count do
        local color = colors[i]
        local x = bar.x + math.floor((i - 1) * bar.w / count)
        local nextX = bar.x + math.floor(i * bar.w / count)
        self:drawRect(x, bar.y, math.max(1, nextX - x), bar.h, 1, color.r, color.g, color.b)
    end
    self:drawRectBorder(bar.x - 1, bar.y - 1, bar.w + 2, bar.h + 2, 1, 0.4, 0.4, 0.4)

    local valueRatio = (self.currentValue - self.minValue) / (self.maxValue - self.minValue)
    local markerX = bar.x + bar.w * valueRatio
    local markerWidth = 6
    local hue = colors[math.max(1, math.min(count, math.floor(valueRatio * (count - 1)) + 1))]
    self:drawRect(markerX - markerWidth / 2, 0, markerWidth, self.height, 1, hue.r, hue.g, hue.b)
    self:drawRectBorder(markerX - markerWidth / 2 - 1, 0, markerWidth + 2, self.height, 1, 0, 0, 0)
    self:drawRectBorder(markerX - markerWidth / 2, 1, markerWidth, self.height - 2, 1, 1, 1, 1)
end

local function LayoutHueSlider(self)
    -- the gradient takes the whole slider minus a small inset, no arrow buttons
    self.sliderBarDim = { x = 4, y = HUE_BAR_INSET, w = self:getWidth() - 8, h = self:getHeight() - HUE_BAR_INSET * 2 }
    self.sliderDim = { x = 2, y = 0, w = 4, h = self:getHeight() }
end

local function BuildHueColors(count)
    local colors = {}
    for i = 1, count do
        local color = Color.HSBtoRGB((i - 1) / (count - 1), 1, 1)
        colors[i] = { r = color:getRedFloat(), g = color:getGreenFloat(), b = color:getBlueFloat() }
    end
    return colors
end

function TicsColorPicker:createChildren()
    ISColorPickerHSB.createChildren(self)

    local hueText = getText('UI_characreation_colorpicker_hue')
    local acceptText = getText('IGUI_Keyboard_Accept')
    local rowHeight = BUTTON_HGT + UI_BORDER_SPACING
    for _, child in pairs(self:getChildren()) do
        if child.name == hueText then
            -- the gradient speaks for itself, and the label would be alone in the left column
            self:removeChild(child)
        elseif child.title == acceptText then
            self.acceptButton = child
        elseif child ~= self.hueSlider and child:getX() < self.colorBlockX then
            -- saturation and brightness rows move up one row
            child:setY(child:getY() - rowHeight)
        end
    end

    local hueY = self.colorBlockY + COLORBOX_HGT + UI_BORDER_SPACING
    local slider = self.hueSlider
    slider.doButtons = false
    slider.doToolTip = false
    slider:setX(self.colorBlockX)
    slider:setY(hueY)
    slider.paginate = LayoutHueSlider
    slider:setWidth(COLORBOX_HGT)
    slider.hueColors = BuildHueColors(64)
    slider.render = RenderHueSlider

    self:setHeight(hueY + BUTTON_HGT + UI_BORDER_SPACING + 1)
    if self.acceptButton then
        self.acceptButton:setY(self.height - UI_BORDER_SPACING - BUTTON_HGT - 1)
    end
end

function TicsColorPicker:new(x, y, initial)
    local o = ISColorPickerHSB.new(self, x, y, initial)
    return o
end

return TicsColorPicker
