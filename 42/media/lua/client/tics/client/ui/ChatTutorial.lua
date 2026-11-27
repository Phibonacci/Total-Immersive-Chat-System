-- Short tutorial of TICS, shown once per server a few seconds after joining and restarted from
-- the chat settings. A card in the chat style points at one element at a time (framed in
-- gold): only what players would not find by themselves, and the features the server enables.
-- Admins get two more steps. Skipped or finished, it is not shown again on this server.

require 'ISUI/ISPanel'

local CharacterSheetManager = require('tics/client/CharacterSheetManager')
local Character = require('tics/shared/utils/Character')
local ChatTheme = require('tics/client/ui/ChatTheme')
local ChatUI = require('tics/client/ui/ChatUI')
local Introductions = require('tics/client/Introductions')
local Journal = require('tics/client/journal/Journal')

local ChatTutorial = ISPanel:derive('TicsChatTutorial')

local FONT = UIFont.Small
local TITLE_FONT = UIFont.Medium
local WIDTH = 300
local PADDING = 12
local GAP = 10                -- between the card and what it points at
local START_DELAY_MS = 5000   -- after joining, so the game has settled
local PULSE_MS = 1200         -- the gold frame around the element breathes

local function Admin()
    return Character.isAdmin(getPlayer())
end

-- target: the element pointed at (nil: the card stays above the chat window, no frame)
local STEPS = {
    {
        key = 'channels', target = function(chat) return chat.textEntry end,
        -- the whole input box: the text field, the channel label before it, the language after
        rect = function(entry)
            local chipWidth, languageWidth = entry.chipWidth or 0, entry.languageWidth or 0
            return entry:getAbsoluteX() - chipWidth, entry:getAbsoluteY(),
                entry:getWidth() + chipWidth + languageWidth, entry:getHeight()
        end,
    },
    { key = 'range', target = function(chat) return chat.rangeButton end },
    {
        key = 'sheet', target = function(chat) return chat.characterSheetButton end,
        visible = function() return CharacterSheetManager.isEnabled() end,
    },
    {
        key = 'introduce', target = function(chat) return chat.introduceButton end,
        visible = function() return Introductions.isEnabled() end,
    },
    {
        key = 'journal', target = function(chat) return chat.journalButton end,
        visible = function() return Journal.isEnabled() end,
    },
    { key = 'help', target = function(chat) return chat.infoButton end },
    { key = 'admin_sandbox', visible = Admin },
    {
        key = 'admin_avatars', target = function(chat) return chat.avatarValidationWindowButton end,
        visible = function()
            return Admin() and TicsServerSettings ~= nil and TicsServerSettings['options']['portrait'] == 2
        end,
    },
}

local instance = nil
local pendingStart = nil -- time the automatic start is due

local function Measure(text, font)
    return getTextManager():MeasureStringX(font or FONT, text)
end

local function WrapText(text, maxWidth)
    local lines = {}
    local line = ''
    for word in text:gmatch('%S+') do
        local candidate = line == '' and word or line .. ' ' .. word
        if Measure(candidate) <= maxWidth then
            line = candidate
        else
            if line ~= '' then
                table.insert(lines, line)
            end
            line = word
            while Measure(line) > maxWidth and #line > 1 do
                local cut = #line - 1
                while cut > 1 and Measure(line:sub(1, cut)) > maxWidth do
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

local function IsInside(area, x, y)
    return area ~= nil and x >= area.x and x < area.x + area.width and y >= area.y and y < area.y + area.height
end

-- the steps for this player on this server, in order
local function BuildSteps(chat)
    local steps = {}
    for _, step in ipairs(STEPS) do
        if step.visible == nil or step.visible() then
            if step.target == nil or step.target(chat) ~= nil then
                table.insert(steps, step)
            end
        end
    end
    return steps
end

-- screen rectangle of what the current step points at (x, y, width, height), nil if none
function ChatTutorial:targetRect()
    local target = self:currentTarget()
    if target == nil then
        return nil
    end
    local step = self.steps[self.index]
    if step.rect then
        return step.rect(target)
    end
    return target:getAbsoluteX(), target:getAbsoluteY(), target:getWidth(), target:getHeight()
end

function ChatTutorial:currentTarget()
    local step = self.steps[self.index]
    local target = step and step.target and step.target(self.chat) or nil
    if target and target:isVisible() then
        return target
    end
    return nil
end

-- sizes the card for the current step
function ChatTutorial:layout()
    local step = self.steps[self.index]
    local fontHeight = getTextManager():getFontHeight(FONT)
    local titleHeight = getTextManager():getFontHeight(TITLE_FONT)
    self.fontHeight = fontHeight
    self.title = getText('UI_TICS_Tuto_' .. step.key .. '_title')
    -- %1: the name of the TICS page of the sandbox options, as translated there
    self.lines = WrapText(getText('UI_TICS_Tuto_' .. step.key, getText('Sandbox_TICS')), WIDTH - PADDING * 2)
    local y = PADDING
    self.titleY = y
    y = y + titleHeight + 6
    self.textY = y
    y = y + #self.lines * fontHeight + 12
    local buttonHeight = fontHeight + 8
    local last = self.index == #self.steps
    local nextText = getText(last and 'UI_TICS_Tuto_done' or 'UI_TICS_Tuto_next')
    local nextWidth = Measure(nextText) + 24
    self.nextArea = { x = WIDTH - PADDING - nextWidth, y = y, width = nextWidth, height = buttonHeight, text = nextText }
    local skipText = getText('UI_TICS_Tuto_skip')
    local skipWidth = Measure(skipText) + 16
    self.skipArea = { x = self.nextArea.x - 6 - skipWidth, y = y, width = skipWidth, height = buttonHeight, text = skipText }
    self.counterY = y + (buttonHeight - fontHeight) / 2
    self:setHeight(y + buttonHeight + PADDING)
end

-- above the element (below when there is no room), centered on it, kept on the screen
function ChatTutorial:place()
    local left, top, width, height = self:targetRect()
    if left == nil then
        local chat = self.chat
        left, top, width, height = chat:getAbsoluteX(), chat:getAbsoluteY(), chat:getWidth(), chat:getHeight()
    end
    local x = left + width / 2 - self.width / 2
    local y = top - GAP - self.height
    if y < 0 then
        y = top + height + GAP
    end
    x = math.max(4, math.min(x, getCore():getScreenWidth() - self.width - 4))
    y = math.max(4, math.min(y, getCore():getScreenHeight() - self.height - 4))
    if x ~= self.x or y ~= self.y then
        self:setX(x)
        self:setY(y)
    end
end

function ChatTutorial:prerender()
    self:place()
    local body, accent = ChatTheme.body, ChatTheme.accent
    self:drawRect(0, 0, self.width, self.height, ChatTheme.popupOpacity, body.r, body.g, body.b)
    self:drawRectBorder(0, 0, self.width, self.height, 1, accent.r, accent.g, accent.b)

    -- gold frame around the element pointed at, breathing
    local left, top, targetWidth, targetHeight = self:targetRect()
    if left then
        local pulse = 0.55 + 0.45 * math.abs(math.sin(getTimestampMs() / PULSE_MS * math.pi))
        local x = left - self:getAbsoluteX() - 3
        local y = top - self:getAbsoluteY() - 3
        local width, height = targetWidth + 6, targetHeight + 6
        self:drawRectBorder(x, y, width, height, pulse, accent.r, accent.g, accent.b)
        self:drawRectBorder(x - 1, y - 1, width + 2, height + 2, pulse * 0.5, accent.r, accent.g, accent.b)
    end
end

function ChatTutorial:drawButton(area, hovered, primary)
    if primary then
        local chip = hovered and ChatTheme.rowHover or ChatTheme.chip
        self:drawRect(area.x, area.y, area.width, area.height, 1, chip.r, chip.g, chip.b)
        local accent = ChatTheme.accent
        self:drawRectBorder(area.x, area.y, area.width, area.height, 1, accent.r, accent.g, accent.b)
    end
    local color = (primary or hovered) and ChatTheme.textActive or ChatTheme.textMuted
    self:drawTextCentre(area.text, area.x + area.width / 2, area.y + (area.height - self.fontHeight) / 2,
        color.r, color.g, color.b, 1, FONT)
end

function ChatTutorial:render()
    local mouseX, mouseY = -1, -1
    if self:isMouseOver() then
        mouseX, mouseY = self:getMouseX(), self:getMouseY()
    end
    local active, hover, muted = ChatTheme.textActive, ChatTheme.textHover, ChatTheme.textMuted
    self:drawText(self.title, PADDING, self.titleY, active.r, active.g, active.b, 1, TITLE_FONT)
    for index, line in ipairs(self.lines) do
        self:drawText(line, PADDING, self.textY + (index - 1) * self.fontHeight, hover.r, hover.g, hover.b, 1, FONT)
    end
    self:drawText(self.index .. ' / ' .. #self.steps, PADDING, self.counterY, muted.r, muted.g, muted.b, 1, FONT)
    if self.index < #self.steps then
        self:drawButton(self.skipArea, IsInside(self.skipArea, mouseX, mouseY), false)
    end
    self:drawButton(self.nextArea, IsInside(self.nextArea, mouseX, mouseY), true)
end

function ChatTutorial:onMouseDown(x, y)
    return true
end

function ChatTutorial:onMouseUp(x, y)
    if IsInside(self.nextArea, x, y) then
        self:next()
    elseif self.index < #self.steps and IsInside(self.skipArea, x, y) then
        self:finish()
    end
    return true
end

function ChatTutorial:next()
    self.index = self.index + 1
    -- a step whose element went away (feature turned off meanwhile) is passed
    while self.steps[self.index] and self.steps[self.index].target and self:currentTarget() == nil do
        self.index = self.index + 1
    end
    if self.index > #self.steps then
        self:finish()
        return
    end
    self:layout()
end

-- skipped or done: not shown again on this server (the chat settings restart it)
function ChatTutorial:finish()
    ChatUI.forceVisible = false
    self:setVisible(false)
    self:removeFromUIManager()
    if instance == self then
        instance = nil
    end
    ISChat.setTutorialDone()
end

function ChatTutorial:new(chat, steps)
    local o = ISPanel.new(self, 0, 0, WIDTH, 100)
    o.background = false
    o.moveWithMouse = false
    o.chat = chat
    o.steps = steps
    o.index = 1
    return o
end

function ChatTutorial.isActive()
    return instance ~= nil
end

-- starts the tutorial now (the chat settings), or restarts it from the first step
function ChatTutorial.start(chat)
    pendingStart = nil
    if instance then
        instance:finish()
    end
    if chat == nil or TicsServerSettings == nil then
        return
    end
    local steps = BuildSteps(chat)
    if #steps == 0 then
        return
    end
    local tutorial = ChatTutorial:new(chat, steps)
    tutorial:initialise()
    tutorial:layout()
    tutorial:addToUIManager()
    tutorial:setAlwaysOnTop(true)
    tutorial:bringToTop()
    ChatUI.forceVisible = true
    instance = tutorial
    return tutorial
end

-- first time on this server: started a few seconds after the server settings arrive
function ChatTutorial.scheduleStart()
    if instance == nil and pendingStart == nil and not ISChat.isTutorialDone() then
        pendingStart = getTimestampMs() + START_DELAY_MS
    end
end

Events.OnTick.Add(function()
    if pendingStart and getTimestampMs() >= pendingStart then
        pendingStart = nil
        local chat = ISChat.instance
        local player = getPlayer()
        if chat and chat:isVisible() and player and not player:isDead() and not ISChat.isTutorialDone() then
            ChatTutorial.start(chat)
        end
    end
end)

-- Escape skips the tutorial
Events.OnKeyPressed.Add(function(key)
    if key == Keyboard.KEY_ESCAPE and instance then
        instance:finish()
    end
end)

return ChatTutorial
