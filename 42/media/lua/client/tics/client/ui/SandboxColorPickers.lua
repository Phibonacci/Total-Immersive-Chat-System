-- Adds a color swatch next to the TICS color sandbox options (text fields holding "#RRGGBB").
-- The swatch shows the color typed in the field, clicking it opens a color picker (TicsColorPicker)
-- set to that color
-- and the picked color is written back in the field as "#RRGGBB".
--
-- Sandbox options are edited in three screens, all patched here:
-- - ISServerSandboxOptionsUI: in game, admin panel > Sandbox Options
-- - SandboxOptionsScreen: main menu, new game sandbox settings
-- - ServerSettingsScreen: main menu, host > server settings editor

require 'ISUI/ISButton'
local TicsColorPicker = require('tics/client/ui/TicsColorPicker')
require 'ISUI/AdminPanel/ISServerSandboxOptionsUI'
require 'OptionScreens/SandboxOptions'
require 'OptionScreens/ServerSettingsScreen'

local SandboxColorPickers = {}

local function IsColorSetting(settingName)
    return type(settingName) == 'string'
        and settingName:match('^TICS%.') ~= nil
        and settingName:match('Color$') ~= nil
end

-- "#RRGGBB" (the "#" is optional) to { r, g, b } in [0, 1], nil if invalid
local function ParseHexColor(text)
    if type(text) ~= 'string' then
        return nil
    end
    local hex = text:match('^%s*#?(%x%x%x%x%x%x)%s*$')
    if hex == nil then
        return nil
    end
    return {
        r = tonumber(hex:sub(1, 2), 16) / 255,
        g = tonumber(hex:sub(3, 4), 16) / 255,
        b = tonumber(hex:sub(5, 6), 16) / 255,
    }
end

local function ToHexColor(color)
    local function Channel(value)
        return math.max(0, math.min(255, math.floor(value * 255 + 0.5)))
    end
    return string.format('#%02X%02X%02X', Channel(color.r), Channel(color.g), Channel(color.b))
end

local function SwatchPrerender(self)
    local color = ParseHexColor(self.colorEntry:getText())
    if color then
        self.backgroundColor = { r = color.r, g = color.g, b = color.b, a = 1 }
        self.backgroundColorMouseOver = { r = color.r, g = color.g, b = color.b, a = 1 }
        self:setTitle('')
    else
        -- invalid value: empty swatch with a question mark
        self.backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 }
        self.backgroundColorMouseOver = { r = 0.2, g = 0.2, b = 0.2, a = 0.5 }
        self:setTitle('?')
    end
    ISButton.prerender(self)
end

local function OnSwatchClick(swatch)
    if swatch.picker then
        swatch.picker:removeSelf()
    end
    local entry = swatch.colorEntry
    local current = ParseHexColor(entry:getText()) or { r = 1, g = 1, b = 1 }
    local initial = ColorInfo.new()
    initial:set(current.r, current.g, current.b, 1.0)

    local picker = TicsColorPicker:new(0, 0, initial)
    picker:initialise()
    picker.keepOnScreen = true
    picker:setX(swatch:getAbsoluteX())
    picker:setY(swatch:getAbsoluteY() + swatch:getHeight())
    picker.pickedFunc = function(_, color)
        entry:setText(ToHexColor(color))
        picker:removeSelf()
        swatch.picker = nil
    end
    picker:addToUIManager()
    picker:setAlwaysOnTop(true)
    -- open on the color of the field: set once the sliders exist so they move too
    picker:setInitialColor(initial)
    swatch.picker = picker
end

-- Adds the swatch to the right of a text field, in the same parent.
function SandboxColorPickers.attach(settingName, control)
    if not IsColorSetting(settingName) or control == nil or control.ticsColorSwatch ~= nil
        or control.getText == nil or control.parent == nil
    then
        return
    end
    local size = control:getHeight()
    local swatch = ISButton:new(control:getRight() + 4, control:getY(), size, size, '', nil, OnSwatchClick)
    swatch.target = nil
    swatch.onclick = function() OnSwatchClick(swatch) end
    swatch:initialise()
    swatch:instantiate()
    swatch.borderColor = { r = 1, g = 1, b = 1, a = 0.6 }
    swatch.colorEntry = control
    swatch.prerender = SwatchPrerender
    swatch.tooltip = getText('UI_TICS_pick_color')
    control.parent:addChild(swatch)
    control.ticsColorSwatch = swatch
end

function SandboxColorPickers.attachAll(controls)
    for settingName, control in pairs(controls or {}) do
        SandboxColorPickers.attach(settingName, control)
    end
end

-- in game admin panel
local AdminCreatePanel = ISServerSandboxOptionsUI.createPanel
function ISServerSandboxOptionsUI:createPanel(page)
    local panel = AdminCreatePanel(self, page)
    if panel then
        SandboxColorPickers.attachAll(panel.controls)
    end
    return panel
end

-- main menu, new game
local NewGameCreatePanel = SandboxOptionsScreen.createPanel
function SandboxOptionsScreen:createPanel(page)
    local panel = NewGameCreatePanel(self, page)
    if panel then
        SandboxColorPickers.attachAll(panel.controls)
    end
    return panel
end

-- main menu, server settings editor: its sandbox page builds every panel when created,
-- the controls are stored per category in pageEdit.controls
local ServerSettingsCreate = ServerSettingsScreen.create
function ServerSettingsScreen:create()
    ServerSettingsCreate(self)
    if self.pageEdit and self.pageEdit.controls then
        for _, controls in pairs(self.pageEdit.controls) do
            if type(controls) == 'table' then
                SandboxColorPickers.attachAll(controls)
            end
        end
    end
end

return SandboxColorPickers
