-- Introduce panel (introductions), opened by its button in the chat title bar: the name given
-- (the character name, or a false one remembered per character), a button to introduce
-- oneself to everyone nearby, and the people within /say range with their own button. Those
-- who already know the character by that name are marked instead. Refreshed while open.

require 'ISUI/ISTextEntryBox'

local ChatTheme = require('tics/client/ui/ChatTheme')
local ChatPopup = require('tics/client/ui/ChatPopup')
local Character = require('tics/shared/utils/Character')
local ClientSend = require('tics/client/network/ClientSend')
local Introductions = require('tics/client/Introductions')

local IntroducePanel = ChatPopup:derive('TicsIntroducePanel')

local FONT = UIFont.Small
local WIDTH = 380
local PADDING_X = 12
local MAX_ROWS = 8
local CLOSE_ICON_SIZE = 12
local CHECK_SIZE = 12
local REFRESH_MS = 500

local function Measure(text)
    return getTextManager():MeasureStringX(FONT, text)
end

local function IsInside(area, x, y)
    return area ~= nil and x >= area.x and x < area.x + area.width and y >= area.y and y < area.y + area.height
end

local function Truncate(text, width)
    if Measure(text) <= width then
        return text
    end
    local cut = #text
    while cut > 0 and Measure(text:sub(1, cut) .. '...') > width do
        cut = cut - 1
    end
    return text:sub(1, cut) .. '...'
end

local function SayRange()
    return TicsServerSettings and TicsServerSettings['say'] and TicsServerSettings['say']['range'] or 15
end

-- the name typed in the field, the character name when empty
function IntroducePanel:getName()
    local text = self.nameEntry:getInternalText() or ''
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then
        local firstName, lastName = Character.getFirstAndLastName(getPlayer())
        return firstName .. ' ' .. lastName
    end
    return text
end

-- the other players within /say range: { username, characterName, shown, knownAs }
function IntroducePanel:findNearby()
    local me = getPlayer()
    local players = getOnlinePlayers()
    local nearby = {}
    if me == nil or players == nil then
        return nearby
    end
    local range = SayRange()
    for index = 0, players:size() - 1 do
        local other = players:get(index)
        if other:getUsername() ~= me:getUsername() and not other:isInvisible() then
            local dx, dy = other:getX() - me:getX(), other:getY() - me:getY()
            if math.sqrt(dx * dx + dy * dy) <= range then
                local firstName, lastName = Character.getFirstAndLastName(other)
                local characterName = firstName .. ' ' .. lastName
                table.insert(nearby, {
                    username = other:getUsername(),
                    shown = Introductions.displayName(other:getUsername(), characterName) or characterName,
                    knownAs = Introductions.getKnownAs(other:getUsername(), characterName),
                    distance = dx * dx + dy * dy,
                })
            end
        end
    end
    table.sort(nearby, function(a, b) return a.distance < b.distance end)
    return nearby
end

-- places everything; the height follows the number of people nearby
function IntroducePanel:layout()
    local fontHeight = getTextManager():getFontHeight(FONT)
    self.fontHeight = fontHeight
    self.headerHeight = fontHeight + 10
    self.rowHeight = fontHeight + 10
    local y = self.headerHeight + 8
    self.nameLabelY = y
    y = y + fontHeight + 4
    self.nameEntryY = y
    y = y + fontHeight + 8 + 8
    self.everyoneArea = { x = PADDING_X, y = y, width = WIDTH - PADDING_X * 2, height = fontHeight + 10 }
    y = y + self.everyoneArea.height + 8
    self.separatorY = y
    y = y + 4
    self.listY = y
    local rows = math.max(1, math.min(#self.nearby, MAX_ROWS))
    self.listHeight = rows * self.rowHeight
    self:setHeight(y + self.listHeight + 8)
    local buttonWidth = Measure(getText('UI_TICS_Intro_button')) + 16
    self.buttonWidth = buttonWidth
    local maxScroll = math.max(0, #self.nearby - MAX_ROWS)
    self.scroll = math.max(0, math.min(self.scroll or 0, maxScroll))
end

function IntroducePanel:refresh()
    self.nearby = self:findNearby()
    self.refreshedAt = getTimestampMs()
    local height = self.height
    self:layout()
    if self.height ~= height and self.chat then
        self:placeNearChat()
    end
end

function IntroducePanel:getCloseArea()
    return { x = self.width - self.headerHeight, y = 0, width = self.headerHeight, height = self.headerHeight }
end

-- the button of a row of the list (only for the people who do not know this name yet)
function IntroducePanel:getRowButton(index)
    local y = self.listY + (index - 1 - self.scroll) * self.rowHeight
    return { x = WIDTH - PADDING_X - self.buttonWidth, y = y + 3, width = self.buttonWidth, height = self.rowHeight - 6 }
end

function IntroducePanel:drawButton(area, text, hovered, enabled)
    local fill = hovered and enabled and ChatTheme.rowHover or ChatTheme.chip
    self:drawRect(area.x, area.y, area.width, area.height, enabled and 1 or 0.5, fill.r, fill.g, fill.b)
    local border = hovered and enabled and ChatTheme.accent or ChatTheme.inputBorder
    self:drawRectBorder(area.x, area.y, area.width, area.height, 1, border.r, border.g, border.b)
    local color = enabled and ChatTheme.textActive or ChatTheme.textMuted
    self:drawTextCentre(text, area.x + area.width / 2, area.y + (area.height - self.fontHeight) / 2,
        color.r, color.g, color.b, 1, FONT)
end

function IntroducePanel:render()
    if getTimestampMs() - (self.refreshedAt or 0) >= REFRESH_MS then
        self:refresh()
    end
    local mouseX, mouseY = -1, -1
    if self:isMouseOver() then
        mouseX, mouseY = self:getMouseX(), self:getMouseY()
    end
    local fontHeight = self.fontHeight
    local active, muted = ChatTheme.textActive, ChatTheme.textMuted

    -- header
    local titleBar, separator = ChatTheme.titleBar, ChatTheme.separator
    self:drawRect(1, 1, self.width - 2, self.headerHeight - 1, 1, titleBar.r, titleBar.g, titleBar.b)
    self:drawRect(1, self.headerHeight, self.width - 2, 1, 1, separator.r, separator.g, separator.b)
    self:drawText(getText('UI_TICS_Intro_title'), 12, (self.headerHeight - fontHeight) / 2, active.r, active.g, active.b, 1, FONT)
    local close = self:getCloseArea()
    local closeColor = IsInside(close, mouseX, mouseY) and ChatTheme.textActive or ChatTheme.iconIdle
    local closeTexture = getTexture(ChatTheme.icons.close)
    if closeTexture then
        self:drawTextureScaled(closeTexture, close.x + (close.width - CLOSE_ICON_SIZE) / 2, close.y + (close.height - CLOSE_ICON_SIZE) / 2,
            CLOSE_ICON_SIZE, CLOSE_ICON_SIZE, 1, closeColor.r, closeColor.g, closeColor.b)
    end

    -- name field (the entry is a child) and its frame
    self:drawText(getText('UI_TICS_Intro_name'), PADDING_X, self.nameLabelY, muted.r, muted.g, muted.b, 1, FONT)
    local entry = self.nameEntry
    local border = entry:isFocused() and ChatTheme.accent or ChatTheme.inputBorder
    self:drawRectBorder(PADDING_X, self.nameEntryY, WIDTH - PADDING_X * 2, fontHeight + 8, 1, border.r, border.g, border.b)

    -- everyone nearby
    local count = #self.nearby
    self:drawButton(self.everyoneArea, getText('UI_TICS_Intro_everyone', count),
        IsInside(self.everyoneArea, mouseX, mouseY), count > 0)
    self:drawRect(PADDING_X, self.separatorY, WIDTH - PADDING_X * 2, 1, 1, separator.r, separator.g, separator.b)

    -- people nearby
    if count == 0 then
        self:drawText(getText('UI_TICS_Intro_nobody_near'), PADDING_X, self.listY + (self.rowHeight - fontHeight) / 2,
            muted.r, muted.g, muted.b, 1, FONT)
        return
    end
    local name = self:getName()
    local check = getTexture(ChatTheme.icons.check)
    for index = self.scroll + 1, math.min(count, self.scroll + MAX_ROWS) do
        local person = self.nearby[index]
        local y = self.listY + (index - 1 - self.scroll) * self.rowHeight
        local textY = y + (self.rowHeight - fontHeight) / 2
        local right = WIDTH - PADDING_X
        if person.knownAs == name then
            -- already knows this name
            local text = getText('UI_TICS_Intro_knows_you', person.knownAs)
            local textWidth = Measure(text)
            self:drawText(text, right - textWidth, textY, muted.r, muted.g, muted.b, 1, FONT)
            if check then
                local accent = ChatTheme.accent
                self:drawTextureScaled(check, right - textWidth - CHECK_SIZE - 4, y + (self.rowHeight - CHECK_SIZE) / 2,
                    CHECK_SIZE, CHECK_SIZE, 1, accent.r, accent.g, accent.b)
            end
            right = right - textWidth - CHECK_SIZE - 12
        else
            local button = self:getRowButton(index)
            self:drawButton(button, getText('UI_TICS_Intro_button'), IsInside(button, mouseX, mouseY), true)
            right = button.x - 8
            if person.knownAs then
                -- knows another name: the button gives the new one
                local text = Truncate(getText('UI_TICS_Intro_knows_you', person.knownAs), WIDTH / 3)
                local textWidth = Measure(text)
                self:drawText(text, right - textWidth, textY, muted.r, muted.g, muted.b, 1, FONT)
                right = right - textWidth - 8
            end
        end
        self:drawText(Truncate(person.shown, right - PADDING_X), PADDING_X, textY, active.r, active.g, active.b, 1, FONT)
    end
    if count > MAX_ROWS then
        -- scroll position on the right edge
        local barHeight = self.listHeight * MAX_ROWS / count
        local barY = self.listY + (self.listHeight - barHeight) * self.scroll / (count - MAX_ROWS)
        self:drawRect(WIDTH - 4, barY, 2, barHeight, 1, ChatTheme.chip.r, ChatTheme.chip.g, ChatTheme.chip.b)
    end
end

-- introduces the character to one username, or to everyone nearby when username is nil
function IntroducePanel:introduce(username)
    local name = self:getName()
    ISChat.setIntroduceName(name)
    ClientSend.sendIntroduce(name, username)
end

function IntroducePanel:onMouseUp(x, y)
    if IsInside(self:getCloseArea(), x, y) then
        self:close()
        ChatPopup.restoreChatFocus()
        return true
    end
    if #self.nearby > 0 and IsInside(self.everyoneArea, x, y) then
        self:introduce(nil)
        return true
    end
    local name = self:getName()
    for index = self.scroll + 1, math.min(#self.nearby, self.scroll + MAX_ROWS) do
        local person = self.nearby[index]
        if person.knownAs ~= name and IsInside(self:getRowButton(index), x, y) then
            self:introduce(person.username)
            return true
        end
    end
    return true
end

function IntroducePanel:onMouseWheel(del)
    self.scroll = math.max(0, math.min((self.scroll or 0) + del, math.max(0, #self.nearby - MAX_ROWS)))
    return true
end

function IntroducePanel:createChildren()
    local fontHeight = getTextManager():getFontHeight(FONT)
    local entry = ISTextEntryBox:new(ISChat.getIntroduceName(), PADDING_X + 1, self.nameEntryY + 1,
        WIDTH - PADDING_X * 2 - 2, fontHeight + 6)
    entry.font = FONT
    entry:initialise()
    entry:instantiate()
    entry.backgroundColor = { r = 0, g = 0, b = 0, a = 0.35 }
    entry.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    entry:setMaxTextLength(40)
    self:addChild(entry)
    self.nameEntry = entry
end

function IntroducePanel:placeNearChat()
    local chat = self.chat
    local top = chat:getAbsoluteY()
    self:placeAbove(chat:getAbsoluteX() + chat:getWidth(), top, top + chat:getHeight())
end

function IntroducePanel:new(owner, chat)
    local o = ChatPopup.new(self, 0, 0, WIDTH, 100, owner)
    o.chat = chat
    o.nearby = {}
    o.scroll = 0
    return o
end

-- opens the panel above the chat window (right edges aligned), or closes it when open
function IntroducePanel.toggle(chat)
    if chat.introducePanel and chat.introducePanel:isOpen() then
        chat.introducePanel:close()
        return
    end
    local panel = IntroducePanel:new(chat.introduceButton, chat)
    panel.nearby = panel:findNearby()
    panel:layout()
    panel:initialise()
    panel:show()
    panel:placeNearChat()
    panel.refreshedAt = getTimestampMs()
    panel.onClose = function()
        ISChat.setIntroduceName(panel:getName())
    end
    chat.introducePanel = panel
end

return IntroducePanel
