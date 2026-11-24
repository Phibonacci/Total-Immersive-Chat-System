-- Chat settings, opened by the gear button of the chat window: every setting of the old
-- gear menu in one panel, values visible at once, applied on click.
-- Two columns: Display and Behaviour on the left, Transparency on the right.
-- The settings are changed through the ISChat handlers the old menu used.

local ChatTheme = require('tics/client/ui/ChatTheme')
local ChatPopup = require('tics/client/ui/ChatPopup')

local ChatSettingsPanel = ChatPopup:derive('TicsChatSettingsPanel')

local FONT = UIFont.Small
local PADDING_X = 14
local PADDING_TOP = 2
local PADDING_BOTTOM = 12
local COLUMN_GAP = 22
local SWITCH_WIDTH = 28
local SWITCH_HEIGHT = 14
local SWITCH_LABEL_GAP = 12
local SEGMENT_PADDING = 12
local CLOSE_ICON_SIZE = 12

local OPACITIES = { 0, 0.25, 0.5, 0.6, 0.75, 1 }
local FADE_TIMES = { 0, 1, 2, 3, 5, 10 }

local function SameOpacity(a, b)
    return math.floor(a * 1000) == math.floor(b * 1000)
end

local function OpacityOptions()
    local options = {}
    for _, value in ipairs(OPACITIES) do
        table.insert(options, { value = value, label = string.format('%d', math.floor(value * 100 + 0.5)) })
    end
    return options
end

-- on / off settings
local SWITCHES = {
    timestamps = {
        text = 'UI_TICS_Settings_timestamps',
        get = function(chat) return chat.showTimestamp end,
        toggle = function() ISChat.onToggleTimestampPrefix() end,
    },
    tags = {
        text = 'UI_TICS_Settings_tags',
        get = function(chat) return chat.showTitle end,
        toggle = function() ISChat.onToggleTagPrefix() end,
    },
    hideWindow = {
        text = 'UI_TICS_Settings_hide_window',
        get = function(chat) return chat.isHudEnabled end,
        toggle = function() ISChat.onToggleHud() end,
    },
    voices = {
        text = 'UI_TICS_Settings_voices',
        get = function(chat) return chat.isVoiceEnabled end,
        toggle = function() ISChat.onToggleVoice() end,
    },
    radioIcon = {
        text = 'UI_TICS_Settings_radio_icon',
        get = function(chat) return chat.isRadioIconEnabled end,
        toggle = function() ISChat.onToggleRadioIcon() end,
    },
    portrait = {
        text = 'UI_TICS_Settings_portrait',
        get = function(chat) return chat.isPortraitEnabled end,
        toggle = function() ISChat.onTogglePortrait() end,
        -- the server can disable the bubble portraits
        visible = function()
            local options = TicsServerSettings and TicsServerSettings['options']
            return options ~= nil and options['portrait'] ~= 1
        end,
    },
    rpLog = {
        text = 'UI_TICS_Settings_rp_log',
        get = function(chat) return chat.isRpLogEnabled end,
        toggle = function() ISChat.onToggleRpLog() end,
    },
}

-- settings with a few values, shown as a row of buttons under their label
local CHOICES = {
    font = {
        text = 'UI_chat_context_font_submenu_name',
        options = function()
            return {
                { value = 'small', label = getText('UI_chat_context_font_small') },
                { value = 'medium', label = getText('UI_chat_context_font_medium') },
                { value = 'large', label = getText('UI_chat_context_font_large') },
            }
        end,
        isCurrent = function(chat, value) return chat.chatFont == value end,
        set = function(chat, value) ISChat.onFontSizeChange(chat, value) end,
    },
    minOpacity = {
        text = 'UI_TICS_Settings_min_opacity',
        options = OpacityOptions,
        isCurrent = function(chat, value) return SameOpacity(chat.minOpaque, logTo01(value)) end,
        -- the minimum cannot go above the maximum
        isEnabled = function(chat, value) return logTo01(value) <= chat.maxOpaque end,
        set = function(chat, value) ISChat.onMinOpaqueChange(chat, value) end,
    },
    maxOpacity = {
        text = 'UI_TICS_Settings_max_opacity',
        options = OpacityOptions,
        isCurrent = function(chat, value) return SameOpacity(chat.maxOpaque, logTo01(value)) end,
        isEnabled = function(chat, value) return logTo01(value) >= chat.minOpaque end,
        set = function(chat, value) ISChat.onMaxOpaqueChange(chat, value) end,
    },
    fadeTime = {
        text = 'UI_chat_context_opaque_fade_time_submenu_name',
        options = function()
            local options = {}
            for _, time in ipairs(FADE_TIMES) do
                local label = time == 0 and getText('UI_TICS_Settings_off') or (time .. ' s')
                table.insert(options, { value = time, label = label })
            end
            return options
        end,
        isCurrent = function(chat, value) return chat.fadeTime == value end,
        set = function(chat, value) ISChat.onFadeTimeChange(chat, value) end,
    },
}

local COLUMNS = {
    {
        { section = 'UI_TICS_Settings_display' },
        { switch = 'timestamps' },
        { switch = 'tags' },
        { choice = 'font' },
        { section = 'UI_TICS_Settings_behaviour' },
        { switch = 'hideWindow' },
        { switch = 'voices' },
        { switch = 'radioIcon' },
        { switch = 'portrait' },
        { switch = 'rpLog' },
    },
    {
        { section = 'UI_TICS_Settings_transparency' },
        { choice = 'minOpacity' },
        { choice = 'maxOpacity' },
        { choice = 'fadeTime' },
    },
}

-- Measures the columns and places every row. Fills self.labels (texts to draw),
-- self.switches and self.segments (clickable areas), and sets the panel size.
function ChatSettingsPanel:layout()
    local textManager = getTextManager()
    local fontHeight = textManager:getFontHeight(FONT)
    local rowHeight = fontHeight + 10
    local sectionHeight = fontHeight + 12
    local segmentHeight = fontHeight + 6
    self.fontHeight = fontHeight
    self.headerHeight = fontHeight + 10

    -- visible rows and the width each one needs
    local columns = {}
    for _, column in ipairs(COLUMNS) do
        local rows = {}
        local width = 0
        for _, row in ipairs(column) do
            if row.section then
                local text = getText(row.section)
                table.insert(rows, { section = text })
                width = math.max(width, textManager:MeasureStringX(FONT, text))
            elseif row.switch then
                local def = SWITCHES[row.switch]
                if def.visible == nil or def.visible() then
                    local text = getText(def.text)
                    table.insert(rows, { switch = def, text = text })
                    width = math.max(width, textManager:MeasureStringX(FONT, text) + SWITCH_LABEL_GAP + SWITCH_WIDTH)
                end
            elseif row.choice then
                local def = CHOICES[row.choice]
                local text = getText(def.text)
                local options = def.options()
                local segmentWidth = 0
                for _, option in ipairs(options) do
                    segmentWidth = math.max(segmentWidth, textManager:MeasureStringX(FONT, option.label) + SEGMENT_PADDING)
                end
                table.insert(rows, { choice = def, text = text, options = options })
                width = math.max(width, textManager:MeasureStringX(FONT, text), segmentWidth * #options)
            end
        end
        table.insert(columns, { rows = rows, width = width })
    end

    self.labels = {}
    self.switches = {}
    self.segments = {}
    local x = PADDING_X
    local bottom = 0
    for _, column in ipairs(columns) do
        local y = self.headerHeight + PADDING_TOP
        for _, row in ipairs(column.rows) do
            if row.section then
                table.insert(self.labels, { text = row.section, x = x, y = y + sectionHeight - fontHeight - 4, muted = true })
                y = y + sectionHeight
            elseif row.switch then
                table.insert(self.switches, { def = row.switch, text = row.text, x = x, y = y, width = column.width, height = rowHeight })
                y = y + rowHeight
            elseif row.choice then
                table.insert(self.labels, { text = row.text, x = x, y = y + 3 })
                y = y + fontHeight + 6
                -- the buttons share the column width
                local count = #row.options
                local segmentX = x
                for index, option in ipairs(row.options) do
                    local nextX = x + math.floor(column.width * index / count)
                    table.insert(self.segments, {
                        def = row.choice, value = option.value, label = option.label,
                        x = segmentX, y = y, width = nextX - segmentX, height = segmentHeight,
                        first = index == 1,
                    })
                    segmentX = nextX
                end
                y = y + segmentHeight + 6
            end
        end
        bottom = math.max(bottom, y)
        x = x + column.width + COLUMN_GAP
    end
    self:setWidth(x - COLUMN_GAP + PADDING_X)
    self:setHeight(bottom + PADDING_BOTTOM)
end

local function IsInside(area, x, y)
    return x >= area.x and x < area.x + area.width and y >= area.y and y < area.y + area.height
end

function ChatSettingsPanel:getCloseButtonArea()
    return { x = self.width - self.headerHeight, y = 0, width = self.headerHeight, height = self.headerHeight }
end

function ChatSettingsPanel:renderHeader(mouseX, mouseY)
    local titleBar = ChatTheme.titleBar
    local separator = ChatTheme.separator
    local text = ChatTheme.textActive
    self:drawRect(1, 1, self.width - 2, self.headerHeight - 1, 1, titleBar.r, titleBar.g, titleBar.b)
    self:drawRect(1, self.headerHeight, self.width - 2, 1, 1, separator.r, separator.g, separator.b)
    self:drawText(getText('UI_TICS_Settings_title'), 12, (self.headerHeight - self.fontHeight) / 2,
        text.r, text.g, text.b, 1, FONT)

    local close = self:getCloseButtonArea()
    local hovered = mouseX and IsInside(close, mouseX, mouseY)
    local color = hovered and ChatTheme.textActive or ChatTheme.iconIdle
    local texture = getTexture(ChatTheme.icons.close)
    if texture then
        self:drawTextureScaled(texture, close.x + (close.width - CLOSE_ICON_SIZE) / 2,
            close.y + (close.height - CLOSE_ICON_SIZE) / 2, CLOSE_ICON_SIZE, CLOSE_ICON_SIZE, 1, color.r, color.g, color.b)
    end
end

function ChatSettingsPanel:renderSwitch(area, chat, hovered)
    local on = area.def.get(chat) == true
    local textColor = hovered and ChatTheme.textActive or ChatTheme.textHover
    self:drawText(area.text, area.x, area.y + (area.height - self.fontHeight) / 2,
        textColor.r, textColor.g, textColor.b, 1, FONT)

    local trackX = area.x + area.width - SWITCH_WIDTH
    local trackY = area.y + math.floor((area.height - SWITCH_HEIGHT) / 2)
    local track = on and ChatTheme.accent or ChatTheme.chip
    self:drawRect(trackX, trackY, SWITCH_WIDTH, SWITCH_HEIGHT, 1, track.r, track.g, track.b)
    local knobSize = SWITCH_HEIGHT - 4
    local knobX = on and (trackX + SWITCH_WIDTH - knobSize - 2) or (trackX + 2)
    local knob = on and ChatTheme.textActive or ChatTheme.textHover
    self:drawRect(knobX, trackY + 2, knobSize, knobSize, 1, knob.r, knob.g, knob.b)
end

function ChatSettingsPanel:renderSegment(area, chat, hovered)
    local def = area.def
    local current = def.isCurrent(chat, area.value)
    local enabled = def.isEnabled == nil or def.isEnabled(chat, area.value)
    local border = ChatTheme.inputBorder
    if current then
        local chip = ChatTheme.chip
        local accent = ChatTheme.accent
        self:drawRect(area.x, area.y, area.width, area.height, 1, chip.r, chip.g, chip.b)
        self:drawRect(area.x, area.y + area.height - 2, area.width, 2, 1, accent.r, accent.g, accent.b)
    elseif hovered and enabled then
        local hover = ChatTheme.rowHover
        self:drawRect(area.x, area.y, area.width, area.height, 1, hover.r, hover.g, hover.b)
    end
    -- outer border on every button, the left one only on the first (it is the divider otherwise)
    self:drawRect(area.x, area.y, area.width, 1, 1, border.r, border.g, border.b)
    self:drawRect(area.x, area.y + area.height - 1, area.width, 1, 1, border.r, border.g, border.b)
    self:drawRect(area.x + area.width - 1, area.y, 1, area.height, 1, border.r, border.g, border.b)
    if area.first then
        self:drawRect(area.x, area.y, 1, area.height, 1, border.r, border.g, border.b)
    end

    local color = (current or (hovered and enabled)) and ChatTheme.textActive or ChatTheme.textMuted
    local alpha = enabled and 1 or 0.35
    self:drawTextCentre(area.label, area.x + area.width / 2, area.y + (area.height - self.fontHeight) / 2,
        color.r, color.g, color.b, alpha, FONT)
end

function ChatSettingsPanel:render()
    local chat = ISChat.instance
    if chat == nil then
        return
    end
    local mouseX, mouseY
    if self:isMouseOver() then
        mouseX, mouseY = self:getMouseX(), self:getMouseY()
    end
    self:renderHeader(mouseX, mouseY)
    for _, label in ipairs(self.labels) do
        local color = label.muted and ChatTheme.textMuted or ChatTheme.textHover
        self:drawText(label.text, label.x, label.y, color.r, color.g, color.b, 1, FONT)
    end
    for _, area in ipairs(self.switches) do
        self:renderSwitch(area, chat, mouseX ~= nil and IsInside(area, mouseX, mouseY))
    end
    for _, area in ipairs(self.segments) do
        self:renderSegment(area, chat, mouseX ~= nil and IsInside(area, mouseX, mouseY))
    end
end

function ChatSettingsPanel:onMouseUp(x, y)
    local chat = ISChat.instance
    if chat == nil then
        return true
    end
    if IsInside(self:getCloseButtonArea(), x, y) then
        self:close()
        ChatPopup.restoreChatFocus()
        return true
    end
    for _, area in ipairs(self.switches) do
        if IsInside(area, x, y) then
            area.def.toggle(chat)
            ChatPopup.restoreChatFocus()
            return true
        end
    end
    for _, area in ipairs(self.segments) do
        if IsInside(area, x, y) then
            local def = area.def
            if (def.isEnabled == nil or def.isEnabled(chat, area.value)) and not def.isCurrent(chat, area.value) then
                def.set(chat, area.value)
            end
            ChatPopup.restoreChatFocus()
            return true
        end
    end
    ChatPopup.restoreChatFocus()
    return true
end

function ChatSettingsPanel:new(owner)
    local o = ChatPopup.new(self, 0, 0, 100, 100, owner)
    return o
end

-- Opens the panel above the chat window (right edges aligned), or closes it when open.
function ChatSettingsPanel.toggle(chat)
    if chat.settingsPanel and chat.settingsPanel:isOpen() then
        chat.settingsPanel:close()
        return
    end
    local panel = ChatSettingsPanel:new(chat.gearButton)
    panel:initialise()
    panel:layout()
    panel:show()
    local top = chat:getAbsoluteY()
    panel:placeAbove(chat:getAbsoluteX() + chat:getWidth(), top, top + chat:getHeight())
    chat.settingsPanel = panel
end

return ChatSettingsPanel
