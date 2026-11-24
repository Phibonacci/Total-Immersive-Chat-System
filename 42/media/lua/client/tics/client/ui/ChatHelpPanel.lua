-- Help of the chat, opened by the info button of the chat window, above the chat window.
-- Left column: the channels the server enables, with their command. Right column: the other
-- commands with an example, the chat buttons with their icon, and the text formatting.
-- Commands come from the code, the translations only hold the descriptions.

local ChatTheme = require('tics/client/ui/ChatTheme')
local ChatPopup = require('tics/client/ui/ChatPopup')
local TokenItalic = require('tics/client/lexer/TokenItalic')
local TICS_VERSION = require('tics/shared/Version')

local ChatHelpPanel = ChatPopup:derive('TicsChatHelpPanel')

local FONT = UIFont.Small
local TITLE = 'Total Immersive Chat System'
local PADDING_X = 14
local PADDING_TOP = 2
local PADDING_BOTTOM = 12
local COLUMN_GAP = 26
local CHIP_PADDING = 5
local CHIP_GAP = 4
local COMMAND_GAP = 12 -- between the commands and their description
local ROW_GAP = 4
local ICON_SIZE = 14
local ICON_GAP = 10
local CLOSE_ICON_SIZE = 12
-- longest description line, in font heights
local LEFT_DESCRIPTION_WIDTH = 13
local RIGHT_DESCRIPTION_WIDTH = 12

-- channels in the order of the help, shown when the server enables them
local CHANNELS = {
    { stream = 'whisper', text = 'UI_TICS_Help_whisper' },
    { stream = 'low', text = 'UI_TICS_Help_low' },
    { stream = 'say', text = 'UI_TICS_Help_say' },
    { stream = 'yell', text = 'UI_TICS_Help_yell' },
    { stream = 'me', text = 'UI_TICS_Help_me' },
    {
        stream = 'do', text = 'UI_TICS_Help_do',
        visible = function(settings) return not settings['do']['adminOnly'] end,
    },
    { stream = 'pm', text = 'UI_TICS_Help_pm', example = 'username' },
    { setting = 'pm', commands = { '/r' }, text = 'UI_TICS_Help_reply' },
    { stream = 'faction', text = 'UI_TICS_Help_faction' },
    { stream = 'safehouse', text = 'UI_TICS_Help_safehouse' },
    { stream = 'general', text = 'UI_TICS_Help_general' },
    { stream = 'admin', text = 'UI_TICS_Help_admin' },
    { stream = 'ooc', text = 'UI_TICS_Help_ooc' },
}

local COMMANDS = {
    { command = 'color', example = '255,120,0', text = 'UI_TICS_Help_color', hint = 'UI_TICS_Help_color_hint' },
    { command = 'pitch', example = '1.2', text = 'UI_TICS_Help_pitch', hint = 'UI_TICS_Help_pitch_hint' },
    { command = 'roll', example = '2d6', text = 'UI_TICS_Help_roll' },
    {
        command = 'language', example = 'en', text = 'UI_TICS_Help_language',
        visible = function(settings) return settings['options']['languages'] end,
    },
}

local BUTTONS = {
    { icon = 'eye', text = 'UI_TICS_Help_range' },
    { icon = 'eyePlus', text = 'UI_TICS_Help_range_always' },
    { icon = 'mic', text = 'UI_TICS_Help_radio' },
}

-- '/whisper ' -> '/whisper'
local function Trim(command)
    return command and command:match('^%s*(.-)%s*$') or nil
end

local function FindByName(list, name)
    for _, entry in pairs(list) do
        if entry.name == name then
            return entry
        end
    end
    return nil
end

local function Measure(text)
    return getTextManager():MeasureStringX(FONT, text)
end

-- Splits a text in lines fitting maxWidth. Words wider than a line (or texts without spaces,
-- like Chinese and Japanese) are cut anywhere.
local function WrapText(text, maxWidth)
    local function Fits(candidate)
        return Measure(candidate) <= maxWidth
    end
    local lines = {}
    local line = ''
    for word in text:gmatch('%S+') do
        local candidate = line == '' and word or line .. ' ' .. word
        if Fits(candidate) then
            line = candidate
        else
            if line ~= '' then
                table.insert(lines, line)
            end
            line = word
            while not Fits(line) do
                local cut = #line - 1
                while cut > 1 and not Fits(line:sub(1, cut)) do
                    cut = cut - 1
                end
                table.insert(lines, line:sub(1, cut))
                line = line:sub(cut + 1)
            end
        end
    end
    if line ~= '' then
        table.insert(lines, line)
    end
    return lines
end

-- Rows of the left column: { chips = { { text, alias } }, text, hint }
local function ChannelRows()
    local settings = TicsServerSettings
    local rows = {}
    if settings == nil then
        return rows
    end
    for _, channel in ipairs(CHANNELS) do
        local setting = settings[channel.setting or channel.stream]
        local visible = setting ~= nil and setting['enabled']
            and (channel.visible == nil or channel.visible(settings))
        if visible then
            local chips = {}
            if channel.stream then
                local stream = FindByName(ISChat.allChatStreams, channel.stream)
                if stream and stream.command then
                    local command = Trim(stream.command)
                    if channel.example then
                        command = command .. ' ' .. channel.example
                    end
                    table.insert(chips, { text = command })
                    if stream.shortCommand then
                        table.insert(chips, { text = Trim(stream.shortCommand), alias = true })
                    end
                end
            else
                for _, command in ipairs(channel.commands) do
                    table.insert(chips, { text = command })
                end
            end
            if #chips > 0 then
                table.insert(rows, { chips = chips, text = getText(channel.text) })
            end
        end
    end
    return rows
end

local function CommandRows()
    local settings = TicsServerSettings
    local rows = {}
    for _, entry in ipairs(COMMANDS) do
        if entry.visible == nil or (settings ~= nil and entry.visible(settings)) then
            local command = FindByName(ISChat.ticsCommand, entry.command)
            local chips = { { text = '/' .. entry.command .. ' ' .. entry.example } }
            if command and command.shortCommand then
                table.insert(chips, { text = Trim(command.shortCommand), alias = true })
            end
            table.insert(rows, {
                chips = chips,
                text = getText(entry.text),
                hint = entry.hint and getText(entry.hint) or nil,
            })
        end
    end
    return rows
end

local function ChipWidth(chip)
    return Measure(chip.text) + CHIP_PADDING * 2
end

local function ChipsWidth(chips)
    local width = 0
    for index, chip in ipairs(chips) do
        width = width + ChipWidth(chip) + (index > 1 and CHIP_GAP or 0)
    end
    return width
end

-- Places the rows of a command table (chips on the left, wrapped description on the right)
-- from (x, y) and returns the y under it.
function ChatHelpPanel:placeCommandRows(rows, x, y, chipsWidth, descriptionWidth)
    local fontHeight = self.fontHeight
    local chipHeight = fontHeight + 2
    local textX = x + chipsWidth + COMMAND_GAP
    for _, row in ipairs(rows) do
        local chipX = x
        for _, chip in ipairs(row.chips) do
            local width = ChipWidth(chip)
            table.insert(self.items, { chip = chip, x = chipX, y = y, width = width, height = chipHeight })
            chipX = chipX + width + CHIP_GAP
        end
        local textY = y + 1
        for _, line in ipairs(WrapText(row.text, descriptionWidth)) do
            table.insert(self.items, { text = line, x = textX, y = textY })
            textY = textY + fontHeight
        end
        if row.hint then
            for _, line in ipairs(WrapText(row.hint, descriptionWidth)) do
                table.insert(self.items, { text = line, x = textX, y = textY, muted = true })
                textY = textY + fontHeight
            end
        end
        y = math.max(y + chipHeight, textY) + ROW_GAP
    end
    return y
end

-- Width of a command table: the widest chips, and the longest description up to maxWidth.
local function TableWidths(rows, maxDescriptionWidth)
    local chipsWidth, descriptionWidth = 0, 0
    for _, row in ipairs(rows) do
        chipsWidth = math.max(chipsWidth, ChipsWidth(row.chips))
        descriptionWidth = math.max(descriptionWidth, Measure(row.text))
        if row.hint then
            descriptionWidth = math.max(descriptionWidth, Measure(row.hint))
        end
    end
    return chipsWidth, math.min(descriptionWidth, maxDescriptionWidth)
end

function ChatHelpPanel:placeSection(text, x, y)
    table.insert(self.items, { text = getText(text), x = x, y = y + self.sectionHeight - self.fontHeight - 4, muted = true })
    return y + self.sectionHeight
end

-- Measures and places everything in self.items, sets the panel size.
function ChatHelpPanel:layout()
    local fontHeight = getTextManager():getFontHeight(FONT)
    self.fontHeight = fontHeight
    self.headerHeight = fontHeight + 10
    self.sectionHeight = fontHeight + 12
    self.items = {}

    local channels = ChannelRows()
    local commands = CommandRows()
    local leftChips, leftDescription = TableWidths(channels, fontHeight * LEFT_DESCRIPTION_WIDTH)
    local rightChips, rightDescription = TableWidths(commands, fontHeight * RIGHT_DESCRIPTION_WIDTH)

    local top = self.headerHeight + PADDING_TOP
    local leftWidth = 0
    local leftBottom = top
    local x = PADDING_X
    if #channels > 0 then
        leftWidth = leftChips + COMMAND_GAP + leftDescription
        local y = self:placeSection('UI_TICS_Help_channels', x, top)
        leftBottom = self:placeCommandRows(channels, x, y, leftChips, leftDescription)
        x = x + leftWidth + COLUMN_GAP
    end

    -- right column
    local rightWidth = rightChips + COMMAND_GAP + rightDescription
    local y = self:placeSection('UI_TICS_Help_commands', x, top)
    y = self:placeCommandRows(commands, x, y, rightChips, rightDescription)

    y = self:placeSection('UI_TICS_Help_buttons', x, y)
    local buttonTextX = x + ICON_SIZE + ICON_GAP
    for _, button in ipairs(BUTTONS) do
        table.insert(self.items, { icon = ChatTheme.icons[button.icon], x = x, y = y + math.floor((fontHeight - ICON_SIZE) / 2) + 1 })
        local textY = y + 1
        for _, line in ipairs(WrapText(getText(button.text), rightWidth - ICON_SIZE - ICON_GAP)) do
            table.insert(self.items, { text = line, x = buttonTextX, y = textY })
            textY = textY + fontHeight
        end
        y = textY + ROW_GAP
    end

    y = self:placeSection('UI_TICS_Help_formatting', x, y)
    for _, line in ipairs(WrapText(getText('UI_TICS_Help_formatting_text'), rightWidth)) do
        table.insert(self.items, { text = line, x = x, y = y })
        y = y + fontHeight
    end
    y = y + 6
    local exampleHeight = fontHeight + 8
    table.insert(self.items, {
        example = getText('UI_TICS_Help_formatting_example'),
        x = x, y = y, width = rightWidth, height = exampleHeight,
    })
    y = y + exampleHeight

    local width = x + rightWidth + PADDING_X
    -- the header must fit the title, the version and the close button
    local titleWidth = 12 + Measure(TITLE) + 8 + Measure(TICS_VERSION) + 12 + self.headerHeight
    self:setWidth(math.max(width, titleWidth))
    self:setHeight(math.max(leftBottom, y) + PADDING_BOTTOM)
end

local function IsInside(area, x, y)
    return x >= area.x and x < area.x + area.width and y >= area.y and y < area.y + area.height
end

function ChatHelpPanel:getCloseButtonArea()
    return { x = self.width - self.headerHeight, y = 0, width = self.headerHeight, height = self.headerHeight }
end

function ChatHelpPanel:renderHeader(mouseX, mouseY)
    local titleBar = ChatTheme.titleBar
    local separator = ChatTheme.separator
    local text = ChatTheme.textActive
    local muted = ChatTheme.textMuted
    self:drawRect(1, 1, self.width - 2, self.headerHeight - 1, 1, titleBar.r, titleBar.g, titleBar.b)
    self:drawRect(1, self.headerHeight, self.width - 2, 1, 1, separator.r, separator.g, separator.b)
    local textY = (self.headerHeight - self.fontHeight) / 2
    self:drawText(TITLE, 12, textY, text.r, text.g, text.b, 1, FONT)
    self:drawText(TICS_VERSION, 12 + Measure(TITLE) + 8, textY, muted.r, muted.g, muted.b, 1, FONT)

    local close = self:getCloseButtonArea()
    local hovered = mouseX and IsInside(close, mouseX, mouseY)
    local color = hovered and ChatTheme.textActive or ChatTheme.iconIdle
    local texture = getTexture(ChatTheme.icons.close)
    if texture then
        self:drawTextureScaled(texture, close.x + (close.width - CLOSE_ICON_SIZE) / 2,
            close.y + (close.height - CLOSE_ICON_SIZE) / 2, CLOSE_ICON_SIZE, CLOSE_ICON_SIZE, 1, color.r, color.g, color.b)
    end
end

-- command in gold on a dark label, short form outlined and muted
function ChatHelpPanel:renderChip(item)
    local chip = item.chip
    local textY = item.y + (item.height - self.fontHeight) / 2
    if chip.alias then
        local border = ChatTheme.inputBorder
        local muted = ChatTheme.textMuted
        self:drawRectBorder(item.x, item.y, item.width, item.height, 1, border.r, border.g, border.b)
        self:drawText(chip.text, item.x + CHIP_PADDING, textY, muted.r, muted.g, muted.b, 1, FONT)
    else
        local background = ChatTheme.chip
        local accent = ChatTheme.accent
        self:drawRect(item.x, item.y, item.width, item.height, 1, background.r, background.g, background.b)
        self:drawText(chip.text, item.x + CHIP_PADDING, textY, accent.r, accent.g, accent.b, 1, FONT)
    end
end

-- example line of the formatting: the text between * in the italic color of the server
function ChatHelpPanel:renderExample(item)
    self:drawRect(item.x, item.y, item.width, item.height, ChatTheme.stripeOpacity, 1, 1, 1)
    local before, emphasis, after = item.example:match('^(.-)%*(.-)%*(.*)$')
    if before == nil then
        before, emphasis, after = item.example, '', ''
    end
    local text = ChatTheme.textHover
    local color = TokenItalic:getColor()
    local x = item.x + 8
    local y = item.y + (item.height - self.fontHeight) / 2
    self:drawText(before, x, y, text.r, text.g, text.b, 1, FONT)
    x = x + Measure(before)
    self:drawText(emphasis, x, y, color[1] / 255, color[2] / 255, color[3] / 255, 1, FONT)
    x = x + Measure(emphasis)
    self:drawText(after, x, y, text.r, text.g, text.b, 1, FONT)
end

function ChatHelpPanel:render()
    local mouseX, mouseY
    if self:isMouseOver() then
        mouseX, mouseY = self:getMouseX(), self:getMouseY()
    end
    self:renderHeader(mouseX, mouseY)
    local idle = ChatTheme.iconIdle
    for _, item in ipairs(self.items) do
        if item.chip then
            self:renderChip(item)
        elseif item.icon then
            local texture = getTexture(item.icon)
            if texture then
                self:drawTextureScaled(texture, item.x, item.y, ICON_SIZE, ICON_SIZE, 1, idle.r, idle.g, idle.b)
            end
        elseif item.example then
            self:renderExample(item)
        else
            local color = item.muted and ChatTheme.textMuted or ChatTheme.textHover
            self:drawText(item.text, item.x, item.y, color.r, color.g, color.b, 1, FONT)
        end
    end
end

function ChatHelpPanel:onMouseUp(x, y)
    if IsInside(self:getCloseButtonArea(), x, y) then
        self:close()
    end
    ChatPopup.restoreChatFocus()
    return true
end

function ChatHelpPanel:new(owner)
    return ChatPopup.new(self, 0, 0, 100, 100, owner)
end

-- Opens the help above the chat window (right edges aligned), or closes it when open.
function ChatHelpPanel.toggle(chat)
    if chat.helpPanel and chat.helpPanel:isOpen() then
        chat.helpPanel:close()
        return
    end
    local panel = ChatHelpPanel:new(chat.infoButton)
    panel:initialise()
    panel:layout()
    panel:show()
    local top = chat:getAbsoluteY()
    panel:placeAbove(chat:getAbsoluteX() + chat:getWidth(), top, top + chat:getHeight())
    chat.helpPanel = panel
end

return ChatHelpPanel
