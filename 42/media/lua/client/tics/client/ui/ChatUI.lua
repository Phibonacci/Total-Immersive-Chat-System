local ChatTheme = require('tics/client/ui/ChatTheme')
local LanguageManager = require('tics/client/languages/LanguageManager')
local AvatarManager = require('tics/client/AvatarManager')
local ChatPopup = require('tics/client/ui/ChatPopup')
local ChatDropdown = require('tics/client/ui/ChatDropdown')
local JournalWindow = require('tics/client/ui/JournalWindow')
local CharacterSheetWindow = require('tics/client/ui/CharacterSheetWindow')

local ChatUI = {}
ChatUI.tabPanel = {}
ChatUI.textEntry = {}

local function Clamp01(value)
    return math.max(0, math.min(1, value))
end

local function MoveTowards(current, target, maxDelta)
    if current < target then
        return math.min(current + maxDelta, target)
    end
    return math.max(current - maxDelta, target)
end

-- Replaces ISChat:makeFade.
-- `fraction` is 1 when the chat is in use and goes down to 0 after the fade time
-- once the chat is unfocused. It computes:
-- - chromeAlpha: opacity of the window itself (background, title bar, tabs, buttons, input)
-- - hudWeight: 0 when the window is shown, 1 when only the messages are shown (HUD mode)
function ChatUI.makeFade(self, fraction)
    local chromeAlpha = self:calcAlpha(0, 1, fraction)

    local hudTarget = 0
    if self.isHudEnabled and not ISChat.focused and not self:isMouseOver() then
        hudTarget = 1 - fraction
        if self.fadeTime == nil or self.fadeTime <= 0 then
            hudTarget = 1 -- no fade time: hide the window as soon as the chat is unfocused
        end
    end
    -- smooth the transition, the vanilla fade can be instantaneous
    local step = UIManager.getMillisSinceLastRender() / 250
    self.hudWeight = MoveTowards(self.hudWeight or 0, hudTarget, step)
    chromeAlpha = chromeAlpha * (1 - self.hudWeight)
    self.chromeAlpha = chromeAlpha

    -- messages stay readable in HUD mode, ChatText handles the per message fade
    local textAlpha = self:calcAlpha(ISChat.minTextOpaque, ISChat.maxGeneralOpaque, fraction)
    textAlpha = textAlpha + (1 - textAlpha) * self.hudWeight
    self.chatText:setContentTransparency(textAlpha)
    if self.tabCnt > 1 then
        self.panel:setTextTransparency(chromeAlpha)
        self.panel:setTabsTransparency(chromeAlpha)
    end
    self.widgetTextureColor.a = chromeAlpha

    -- we draw the input box ourselves (ChatUI.textEntry.prerender)
    if self.textEntry:getHasFrame() then
        self.textEntry:setFrameAlpha(0)
    end
    self.textEntry.backgroundColor.a = 0
end

-- Buttons of the title bar, from right to left.
local function GetTitleButtons(self)
    local buttons = { self.lockButton, false, self.gearButton, self.infoButton, self.rangeButton, self.radioButton }
    if self.journalButton then
        table.insert(buttons, self.journalButton)
    end
    if self.characterSheetButton then
        table.insert(buttons, self.characterSheetButton)
    end
    if self.avatarUploadButton then
        table.insert(buttons, self.avatarUploadButton)
    end
    if self.avatarValidationWindowButton then
        table.insert(buttons, self.avatarValidationWindowButton)
    end
    return buttons
end

local function IsButtonActive(self, button)
    if button == self.rangeButton then
        return self.rangeButtonState == 'visible' or self.rangeButtonState == 'always-visible'
    elseif button == self.radioButton then
        return self.radioButtonState == true
    elseif button == self.lockButton then
        return self.locked == true
    elseif button == self.gearButton then
        return self.settingsPanel ~= nil and self.settingsPanel:isOpen() -- settings panel open
    elseif button == self.infoButton then
        return self.helpPanel ~= nil and self.helpPanel:isOpen() -- help open
    elseif button == self.journalButton then
        return JournalWindow.isOpen()
    elseif button == self.characterSheetButton then
        return CharacterSheetWindow.isOpen(getPlayer():getUsername())
    elseif button == self.avatarUploadButton then
        return self.avatarUploadWindow ~= nil and self.avatarUploadWindow:getIsVisible()
    elseif button == self.avatarValidationWindowButton then
        return AvatarManager:getPendingCount() > 0 -- avatars waiting for approval
    end
    return false
end

-- dot on the avatar validation button while requests are waiting (like an unread tab)
local function DrawPendingAvatarsBadge(self)
    local button = self.avatarValidationWindowButton
    local alpha = self.chromeAlpha or 1
    if button == nil or alpha <= 0.01 or AvatarManager:getPendingCount() == 0 then
        return
    end
    local accent = ChatTheme.accent
    local size = 6
    local x = button:getX() + button:getWidth() / 2 + ChatTheme.iconSize / 2 - size / 2
    local y = button:getY() + button:getHeight() / 2 - ChatTheme.iconSize / 2 - 1
    self:drawRect(x, y, size, size, alpha, accent.r, accent.g, accent.b)
    local titleBar = ChatTheme.titleBar
    self:drawRectBorder(x - 1, y - 1, size + 2, size + 2, alpha, titleBar.r, titleBar.g, titleBar.b)
end

local function StyleButton(button, color, alpha)
    button.borderColor.a = 0
    button.backgroundColor.a = 0
    button.backgroundColorMouseOver = { r = 1, g = 1, b = 1, a = 0.08 * alpha }
    button.textureColor.r = color.r
    button.textureColor.g = color.g
    button.textureColor.b = color.b
    button.textureColor.a = alpha
end

-- Places the title bar buttons with the same size and spacing, vertically centered,
-- and tints them (grey when idle, accent when the feature is on).
function ChatUI.layoutTitleButtons(self)
    local th = self:titleBarHeight()
    local iconSize = math.min(ChatTheme.iconSize, th - 2)
    local buttonWidth = th + 4
    local alpha = self.chromeAlpha or 1

    self.closeButton:setX(3)
    self.closeButton:setY(0)
    self.closeButton:setWidth(th)
    self.closeButton:setHeight(th)
    self.closeButton:forceImageSize(iconSize, iconSize)
    StyleButton(self.closeButton, ChatTheme.iconIdle, alpha)

    local x = self:getWidth() - 4
    self.titleSeparatorX = nil
    for _, button in ipairs(GetTitleButtons(self)) do
        if button == false then
            -- thin separator between the lock and the other buttons
            x = x - 6
            self.titleSeparatorX = x + 3
        else
            x = x - buttonWidth
            button:setX(x)
            button:setY(0)
            button:setWidth(buttonWidth)
            button:setHeight(th)
            button:forceImageSize(iconSize, iconSize)
            local color = IsButtonActive(self, button) and ChatTheme.accent or ChatTheme.iconIdle
            StyleButton(button, color, alpha)
            x = x - ChatTheme.buttonGap
        end
    end
end

local ChipLabels = {
    say = 'Say', whisper = 'Whisper', low = 'Low', yell = 'Yell',
    faction = 'Faction', safehouse = 'Safehouse', general = 'General',
    ooc = 'OOC', pm = 'PM', admin = 'Admin', me = 'Me', ['do'] = 'Do',
}

-- translated with UI_TICS_chip_<channel>, the English names above are the fallback
local function GetChipLabel(stream)
    local key = 'UI_TICS_chip_' .. stream.name
    local label = getText(key)
    if label == nil or label == key then
        return ChipLabels[stream.name] or stream.name
    end
    return label
end

local function GetChipColor(stream)
    -- BuildColorFromMessageType (ISChat.lua) raises an error for types without a color
    local ok, color = pcall(BuildColorFromMessageType, stream.name)
    if ok and type(color) == 'table' then
        return { r = color[1] / 255, g = color[2] / 255, b = color[3] / 255 }
    end
    return ChatTheme.textActive
end

-- The text box starts after the channel chip, the box frame drawn by
-- ChatUI.textEntry.prerender covers both.
-- Language selector: a button at the right end of the input box showing the code of the
-- current language, it opens the list of the known languages. Only when languages are enabled.
local function IsLanguageSelectorEnabled()
    return TicsServerSettings ~= nil and TicsServerSettings['options'] ~= nil
        and TicsServerSettings['options']['languages'] == true
end

local function GetCurrentLanguageCode()
    local code = LanguageManager.GetCodeFromLanguage(LanguageManager:getCurrentLanguage())
    return (code or LanguageManager.GetCodeFromLanguage(LanguageManager.DefaultLanguage) or '?'):upper()
end

local LANGUAGE_ARROW_WIDTH = 5

-- fixed width (two letters) so the input box does not change when the language changes
local function GetLanguageButtonWidth()
    return getTextManager():MeasureStringX(UIFont.Small, 'WW') + ChatTheme.chipPaddingX * 2
        + LANGUAGE_ARROW_WIDTH + 4
end

local function OnLanguageSelected(language)
    LanguageManager:setCurrentLanguageFromCode(LanguageManager.GetCodeFromLanguage(language))
end

-- the list of the known languages, opened above the button (a second click closes it)
local function OnLanguageButtonClick(chat, button)
    if chat.languageDropdown and chat.languageDropdown:isOpen() then
        chat.languageDropdown:close()
        ChatPopup.restoreChatFocus()
        return
    end
    local current = LanguageManager:getCurrentLanguage()
    local items = {}
    for language in pairs(LanguageManager:getKnownLanguages()) do
        local code = LanguageManager.GetCodeFromLanguage(language)
        table.insert(items, {
            label = LanguageManager.GetLanguageTranslated(language),
            value = language,
            detail = code and code:upper() or nil,
            checked = language == current,
        })
    end
    table.sort(items, function(a, b) return a.label < b.label end)
    chat.languageDropdown = ChatDropdown.open(button, items, OnLanguageSelected)
    ChatPopup.restoreChatFocus()
end

local function RenderLanguageButton(self)
    local chat = ISChat.instance
    local alpha = chat and chat.chromeAlpha or 1
    local font = UIFont.Small
    local chip = ChatTheme.chip
    local isOpen = chat and chat.languageDropdown and chat.languageDropdown:isOpen()
    local textColor = (isOpen or self:isMouseOver()) and ChatTheme.textActive or ChatTheme.textHover
    self:drawRect(0, 0, self.width, self.height, alpha, chip.r, chip.g, chip.b)
    local code = GetCurrentLanguageCode()
    local fontHeight = getTextManager():getFontHeight(font)
    self:drawText(code, ChatTheme.chipPaddingX, (self.height - fontHeight) / 2,
        textColor.r, textColor.g, textColor.b, alpha, font)
    -- small arrow pointing down
    local arrowX = self.width - ChatTheme.chipPaddingX - LANGUAGE_ARROW_WIDTH
    local arrowY = math.floor(self.height / 2) - 1
    for row = 0, 2 do
        self:drawRect(arrowX + row, arrowY + row, LANGUAGE_ARROW_WIDTH - row * 2, 1,
            alpha, textColor.r, textColor.g, textColor.b)
    end
end

local function UpdateLanguageButton(self, entry, languageWidth)
    if languageWidth == 0 then
        if self.languageButton then
            self.languageButton:setVisible(false)
        end
        return
    end
    if self.languageButton == nil then
        local button = ISButton:new(0, 0, 10, 10, '', self, OnLanguageButtonClick)
        button:initialise()
        button:instantiate()
        button.render = RenderLanguageButton
        button.prerender = function() end
        button.anchorRight = false
        button.anchorBottom = false
        self:addChild(button)
        self.languageButton = button
    end
    local button = self.languageButton
    local fontHeight = getTextManager():getFontHeight(UIFont.Small)
    local height = math.min(fontHeight + 2, entry:getHeight() - 6)
    button:setWidth(languageWidth - ChatTheme.chipMargin - 2)
    button:setHeight(height)
    button:setX(entry:getRight() + 2)
    button:setY(entry:getY() + (entry:getHeight() - height) / 2)
    -- hidden with the window in HUD mode, a click there then focuses the chat
    button:setVisible((self.chromeAlpha or 1) > 0.05)
    button:bringToTop()
end

function ChatUI.layoutInput(self)
    local entry = self.textEntry
    if entry == nil then
        return
    end
    local chipWidth = 0
    if self.inputChip then
        local label = GetChipLabel(self.inputChip.stream)
        local textWidth = getTextManager():MeasureStringX(UIFont.Small, label)
        chipWidth = ChatTheme.chipMargin + textWidth + ChatTheme.chipPaddingX * 2
    end
    local languageWidth = 0
    if IsLanguageSelectorEnabled() then
        languageWidth = GetLanguageButtonWidth() + ChatTheme.chipMargin
    end
    local x = ChatTheme.inputPadding + chipWidth
    local width = self:getWidth() - ChatTheme.inputPadding * 2 - chipWidth - languageWidth
    if entry:getX() ~= x or entry:getWidth() ~= width then
        entry:setX(x)
        entry:setWidth(width)
    end
    entry.chipWidth = chipWidth
    entry.languageWidth = languageWidth
    UpdateLanguageButton(self, entry, languageWidth)
end

function ChatUI:prerender()
    ISChat.instance = self
    self.gearButton.onclick = self.onGearButtonClick

    self:setDrawFrame(true)

    if not ISChat.focused then
        self.fade:update()
    end
    self:makeFade(self.fade:fraction())
    ChatUI.layoutTitleButtons(self)
    ChatUI.layoutInput(self)

    local alpha = self.chromeAlpha or 1
    local th = self:titleBarHeight()
    local body = ChatTheme.body
    local titleBar = ChatTheme.titleBar
    local separator = ChatTheme.separator
    self:drawRect(0, th, self:getWidth(), self:getHeight() - th, alpha * ChatTheme.bodyOpacity,
        body.r, body.g, body.b)
    self:drawRect(0, 0, self:getWidth(), th, alpha, titleBar.r, titleBar.g, titleBar.b)
    self:drawRect(0, th - 1, self:getWidth(), 1, alpha, separator.r, separator.g, separator.b)
    if self.titleSeparatorX then
        self:drawRect(self.titleSeparatorX, 4, 1, th - 8, alpha, separator.r, separator.g, separator.b)
    end

    if self.servermsg then
        local x = getCore():getScreenWidth() / 2 - self:getX()
        local y = getCore():getScreenHeight() / 4 - self:getY()
        self:drawTextCentre(self.servermsg, x, y, 1, 0.1, 0.1, 1, UIFont.Title)
        self.servermsgTimer = self.servermsgTimer - UIManager.getMillisSinceLastRender()
        if self.servermsgTimer < 0 then
            self.servermsg = nil
            self.servermsgTimer = 0
        end
    end
end

local function DrawPill(self, text, x, y, height, alpha, dotColor)
    local font = UIFont.Small
    local textWidth = getTextManager():MeasureStringX(font, text)
    local fontHeight = getTextManager():getFontHeight(font)
    local dotSpace = dotColor and 12 or 0
    local width = textWidth + 16 + dotSpace
    local pill = ChatTheme.pill
    self:drawRect(x, y, width, height, alpha * ChatTheme.pillOpacity, pill.r, pill.g, pill.b)
    local textColor = ChatTheme.textActive
    self:drawText(text, x + 8, y + (height - fontHeight) / 2, textColor.r, textColor.g, textColor.b, alpha, font)
    if dotColor then
        self:drawRect(x + 8 + textWidth + 6, y + height / 2 - 3, 6, 6, alpha, dotColor.r, dotColor.g, dotColor.b)
    end
    return width
end

-- HUD mode: "Press T to chat" and the current tab (+ unread tabs) where the input box is.
local function DrawHudHints(self)
    local alpha = self.hudWeight or 0
    if alpha <= 0.01 or self.textEntry == nil then
        return
    end
    local height = getTextManager():getFontHeight(UIFont.Small) + 4
    local x = self.textEntry:getX()
    local y = self.textEntry:getY() + (self.textEntry:getHeight() - height) / 2

    local keyName = getKeyName(getCore():getKey('Toggle chat')) or 'T'
    local hintKey = self.draftText and 'UI_TICS_press_to_continue_writing' or 'UI_TICS_press_to_chat'
    x = x + DrawPill(self, getText(hintKey, keyName), x, y, height, alpha) + 8

    -- one pill per tab: the current one, then each unread one with a dot
    -- (a separator glyph like a middle dot is missing from the game font)
    local currentTab = self.chatText and self.chatText.tabTitle
    if currentTab then
        x = x + DrawPill(self, currentTab, x, y, height, alpha) + 6
    end
    for _, name in ipairs(self.panel and self.panel.blinkTabs or {}) do
        if name ~= currentTab then
            x = x + DrawPill(self, name, x, y, height, alpha, ChatTheme.accent) + 6
        end
    end
end

function ChatUI:render()
    local height = self:getHeight()
    local th = self:titleBarHeight()
    local alpha = self.chromeAlpha or 1
    if self.isCollapsed then
        height = th
    end
    -- no resize grip is drawn: the bottom right corner still resizes the window

    if self.clearStentil then
        self:clearStencilRect()
    end
    if self.drawFrame then
        local separator = ChatTheme.separator
        self:drawRectBorder(0, 0, self:getWidth(), height, alpha, separator.r, separator.g, separator.b)
    end

    if self.drawJoypadFocus then
        self:drawRectBorder(0, 0, self:getWidth(), self:getHeight(), 0.4, 0.2, 1.0, 1.0)
        self:drawRectBorder(1, 1, self:getWidth() - 2, self:getHeight() - 2, 0.4, 0.2, 1.0, 1.0)
    end

    DrawPendingAvatarsBadge(self)
    DrawHudHints(self)
end

function ChatUI.tabPanel:prerender()
    -- tabs are drawn in render, we only keep the smooth scrolling of the vanilla prerender
    self:updateSmoothScrolling()
end

local function IsTabUnread(self, name)
    if self.blinkTab and self.blinkTab == name then
        return true
    end
    for _, tab in ipairs(self.blinkTabs or {}) do
        if tab == name then
            return true
        end
    end
    return false
end

function ChatUI.tabPanel:render()
    local newViewList = {}
    local tabDragSelected = -1
    if self.draggingTab and not self.isDragging and ISTabPanel.xMouse > -1 and ISTabPanel.xMouse ~= self:getMouseX() then -- do we move the mouse since we have let the left button down ?
        self.isDragging = self.allowDraggingTabs
    end
    local alpha = self.tabTransparency or 1
    local tabWidth = self.maxLength
    local inset = 1 -- must match ISTabPanel:getTabIndexAtX
    local gap = 1   -- gap between tabs, must match ISTabPanel:getTabIndexAtX
    local font = UIFont.Small
    local fontHeight = getTextManager():getFontHeight(font)
    local textY = (self.tabHeight - fontHeight) / 2

    local strip = ChatTheme.tabStrip
    local separator = ChatTheme.separator
    self:drawRect(0, 0, self.width, self.tabHeight, alpha, strip.r, strip.g, strip.b)
    self:drawRect(0, self.tabHeight - 1, self.width, 1, alpha, separator.r, separator.g, separator.b)

    if self.isDragging and not ISTabPanel.mouseOut then
        -- we fetch all our view to remove the tab of the view we're dragging
        for i, viewObject in ipairs(self.viewList) do
            if i ~= (self.draggingTab + 1) then
                table.insert(newViewList, viewObject)
            else
                ISTabPanel.viewDragging = viewObject
            end
        end
        -- in wich tab slot are we dragging our tab
        tabDragSelected = self:getTabIndexAtX(self:getMouseX()) - 1
        tabDragSelected = math.min(#self.viewList - 1, math.max(tabDragSelected, 0))
        -- show where the tab is going to be
        local accent = ChatTheme.accent
        self:drawRectBorder(inset + (tabDragSelected * (tabWidth + gap)), 0, tabWidth, self.tabHeight - 1, alpha,
            accent.r, accent.g, accent.b)
    else -- no dragging, we display all our tabs
        newViewList = self.viewList
    end
    local x = inset
    if self.centerTabs and (self:getWidth() >= self:getWidthOfAllTabs()) then
        x = (self:getWidth() - self:getWidthOfAllTabs()) / 2
    else
        x = x + self.scrollX
    end
    local widthOfAllTabs = self:getWidthOfAllTabs()
    local overflowLeft = self.scrollX < 0
    local overflowRight = x + widthOfAllTabs > self.width
    if widthOfAllTabs > self.width then
        self:setStencilRect(0, 0, self.width, self.tabHeight)
    end
    for i, viewObject in ipairs(newViewList) do
        tabWidth = self.equalTabWidth and self.maxLength or viewObject.tabWidth
        -- if we drag a tab over an existing one, we move the other
        if tabDragSelected ~= -1 and i == (tabDragSelected + 1) then
            x = x + tabWidth + gap
        end
        local isActive = viewObject.name == self.activeView.name and not self.isDragging and not ISTabPanel.mouseOut
        local isHovered = self:getMouseY() >= 0 and self:getMouseY() < self.tabHeight and self:isMouseOver()
            and self:getTabIndexAtX(self:getMouseX()) == i
        local textColor = ChatTheme.textMuted
        if isActive then
            textColor = ChatTheme.textActive
            local accent = ChatTheme.accent
            self:drawRect(x, self.tabHeight - 2, tabWidth, 2, alpha, accent.r, accent.g, accent.b)
        elseif isHovered then
            textColor = ChatTheme.textHover
        end
        local unread = not isActive and IsTabUnread(self, viewObject.name)
        local textWidth = getTextManager():MeasureStringX(font, viewObject.name)
        local textX = x + (tabWidth - textWidth) / 2
        if unread then
            textX = textX - 4 -- make room for the unread dot
            local accent = ChatTheme.accent
            self:drawRect(textX + textWidth + 5, self.tabHeight / 2 - 3, 6, 6, alpha, accent.r, accent.g, accent.b)
        end
        self:drawText(viewObject.name, textX, textY, textColor.r, textColor.g, textColor.b, alpha, font)
        x = x + tabWidth + gap
    end
    local butPadX = 3
    local strip2 = ChatTheme.tabStrip
    if overflowLeft then
        local tex = getTexture("media/ui/ArrowLeft.png")
        local butWid = tex:getWidthOrig() + butPadX * 2
        self:drawRect(inset, 0, butWid, self.tabHeight - 1, alpha, strip2.r, strip2.g, strip2.b)
        self:drawTexture(tex, inset + butPadX, (self.tabHeight - tex:getHeight()) / 2, alpha, 1, 1, 1)
    end
    if overflowRight then
        local tex = getTexture("media/ui/ArrowRight.png")
        local butWid = tex:getWidthOrig() + butPadX * 2
        self:drawRect(self.width - inset - butWid, 0, butWid, self.tabHeight - 1, alpha, strip2.r, strip2.g, strip2.b)
        self:drawTexture(tex, self.width - butWid + butPadX, (self.tabHeight - tex:getHeight()) / 2, alpha, 1, 1, 1)
    end
    if widthOfAllTabs > self.width then
        self:clearStencilRect()
    end
    -- we draw a ghost of the tab we are currently dragging
    if self.draggingTab and self.isDragging and not ISTabPanel.mouseOut then
        local ghostX = inset + (self:getMouseX() - ISTabPanel.xMouse)
        if self.draggingTab > 0 then
            ghostX = ghostX + self.draggingTab * (tabWidth + gap)
        end
        local strip3 = ChatTheme.separator
        self:drawRect(ghostX, 0, tabWidth, self.tabHeight - 1, 0.8, strip3.r, strip3.g, strip3.b)
        local textColor = ChatTheme.textActive
        self:drawTextCentre(ISTabPanel.viewDragging.name, ghostX + (tabWidth / 2), textY,
            textColor.r, textColor.g, textColor.b, 1, font)
    end
end

function ChatUI.textEntry:prerender()
    local chat = ISChat.instance
    local alpha = chat and chat.chromeAlpha or 1
    if alpha <= 0.01 then
        return
    end
    local chipWidth = self.chipWidth or 0
    local frameWidth = self.width + chipWidth + (self.languageWidth or 0)
    local background = ChatTheme.pill
    self:drawRect(-chipWidth, 0, frameWidth, self.height, alpha * ChatTheme.inputOpacity,
        background.r, background.g, background.b)
    local border = ISChat.focused and ChatTheme.accent or ChatTheme.inputBorder
    self:drawRectBorder(-chipWidth, 0, frameWidth, self.height, alpha, border.r, border.g, border.b)

    local chip = chat and chat.inputChip
    if chip and chipWidth > 0 then
        local font = UIFont.Small
        local label = GetChipLabel(chip.stream)
        local fontHeight = getTextManager():getFontHeight(font)
        local chipHeight = math.min(fontHeight + 2, self.height - 6)
        local chipX = -chipWidth + ChatTheme.chipMargin
        local chipY = (self.height - chipHeight) / 2
        local chipBackground = ChatTheme.chip
        self:drawRect(chipX, chipY, chipWidth - ChatTheme.chipMargin - 2, chipHeight, alpha,
            chipBackground.r, chipBackground.g, chipBackground.b)
        local color = GetChipColor(chip.stream)
        self:drawText(label, chipX + ChatTheme.chipPaddingX, chipY + (chipHeight - fontHeight) / 2,
            color.r, color.g, color.b, alpha, font)
    end
end

function ChatUI.textEntry:instantiate()
    --self:initialise()
    self.javaObject = UITextBox2.new(self.font, self.x, self.y, self.width, self.height, self.title, false)
    self.javaObject:setTable(self)
    self.javaObject:setX(self.x)
    self.javaObject:setY(self.y)
    self.javaObject:setHeight(self.height)
    self.javaObject:setWidth(self.width)
    self.javaObject:setAnchorLeft(self.anchorLeft)
    self.javaObject:setAnchorRight(self.anchorRight)
    self.javaObject:setAnchorTop(self.anchorTop)
    self.javaObject:setAnchorBottom(self.anchorBottom)
    self.javaObject:setEditable(true)
    -- This forces the cursor to the end of the line
    self.javaObject:SetText(self.title)
end

return ChatUI
