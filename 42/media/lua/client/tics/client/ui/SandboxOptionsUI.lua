-- Tweaks of the sandbox options screens for the TICS options:
-- - color options get a color swatch / picker (SandboxColorPickers)
-- - option names can be written on several lines with "\n" in the translation files
--
-- Sandbox options are edited in three screens, all patched here:
-- - ISServerSandboxOptionsUI: in game, admin panel > Sandbox Options
-- - SandboxOptionsScreen: main menu, new game sandbox settings
-- - ServerSettingsScreen: main menu, host > server settings editor

require 'ISUI/AdminPanel/ISServerSandboxOptionsUI'
require 'OptionScreens/SandboxOptions'
require 'OptionScreens/ServerSettingsScreen'
local SandboxColorPickers = require('tics/client/ui/SandboxColorPickers')

-- translations may keep "\n" as two characters
local function ToRealNewLines(text)
    if type(text) ~= 'string' then
        return text
    end
    return (text:gsub('\\n', '\n'))
end

-- before a panel is built: real line breaks, so the label column is as wide as the longest line
local function PrepareSettingNames(page)
    for _, setting in ipairs(page and page.settings or {}) do
        if type(setting.name) == 'string' and setting.name:match('^TICS%.') then
            setting.translatedName = ToRealNewLines(setting.translatedName)
        end
    end
end

-- after a panel is built: rows have a fixed height, a label on several lines needs a taller
-- row, the rows below it are moved down and the controls of its row are centered on it
local function FixMultilineLabels(container)
    if container == nil or container.getChildren == nil then
        return
    end
    local children = {}
    for _, child in pairs(container:getChildren()) do
        table.insert(children, child)
    end
    for _, label in ipairs(children) do
        if label.Type == 'ISLabel' and type(label.name) == 'string' and not label.ticsMultiline then
            local text = ToRealNewLines(label.name)
            if text ~= label.name then
                -- keep the label right-aligned on the controls
                local right = label:getRight()
                label:setNameWithoutMoving(text)
                label:setX(right - label:getWidth())
            end
            if text:find('\n') then
                label.ticsMultiline = true
                local rowY = label:getY()
                local rowHeight = label:getHeight()
                local extra = getTextManager():MeasureStringY(label.font, text) + 4 - rowHeight
                if extra > 0 then
                    for _, child in ipairs(children) do
                        if child ~= label then
                            local y = child:getY()
                            if y >= rowY + rowHeight / 2 then
                                child:setY(y + extra) -- rows below
                            elseif child:getBottom() > rowY then
                                child:setY(y + math.floor(extra / 2)) -- same row
                            end
                        end
                    end
                    label:setHeight(rowHeight + extra)
                    container:setScrollHeight(container:getScrollHeight() + extra)
                end
            end
        end
    end
end

-- the controls of a panel can be in the panel itself or in a child (group boxes)
local function FixPanel(controls)
    local containers = {}
    for _, control in pairs(controls or {}) do
        if type(control) == 'table' and control.parent then
            containers[control.parent] = true
        end
    end
    for container in pairs(containers) do
        FixMultilineLabels(container)
    end
    SandboxColorPickers.attachAll(controls)
end

-- in game admin panel
local AdminCreatePanel = ISServerSandboxOptionsUI.createPanel
function ISServerSandboxOptionsUI:createPanel(page)
    PrepareSettingNames(page)
    local panel = AdminCreatePanel(self, page)
    if panel then
        FixPanel(panel.controls)
    end
    return panel
end

-- main menu, new game
local NewGameCreatePanel = SandboxOptionsScreen.createPanel
function SandboxOptionsScreen:createPanel(page)
    PrepareSettingNames(page)
    local panel = NewGameCreatePanel(self, page)
    if panel then
        FixPanel(panel.controls)
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
                FixPanel(controls)
            end
        end
    end
end
