-- Character sheet window: the player edits their own sheet, or reads the sheet of another
-- player (right click > Examine). The appearance is the 3D model of the character and their
-- avatar (custom portraits), the text fields are the title, the personality & background and
-- the OOC notes. Admins and moderators can clear the sheet of another player.

require 'ISUI/ISPanel'
require 'ISUI/ISButton'
require 'ISUI/ISTextEntryBox'
require 'ISUI/ISRichTextPanel'
require 'ISUI/ISUI3DModel'
require 'ISUI/ISModalDialog'

local AvatarManager = require('tics/client/AvatarManager')
local Character = require('tics/shared/utils/Character')
local CharacterSheetManager = require('tics/client/CharacterSheetManager')
local ChatTheme = require('tics/client/ui/ChatTheme')
local Introductions = require('tics/client/Introductions')
local ClientSend = require('tics/client/network/ClientSend')
local World = require('tics/shared/utils/World')


local CharacterSheetWindow = ISPanel:derive('TicsCharacterSheetWindow')

local FONT = UIFont.Small
local FONT_HGT = getTextManager():getFontHeight(FONT)
local PADDING = 12
local TITLE_HGT = FONT_HGT + 10
local BUTTON_HGT = FONT_HGT + 8
local WIDTH = 600
local HEIGHT = 470
local MODEL_WIDTH = 150
local MODEL_HEIGHT = 230
local AVATAR_WIDTH = 60
local AVATAR_HEIGHT = 80
local LABEL_HGT = FONT_HGT + 4
local BACKGROUND_HGT = 170
local OOC_HGT = 90
-- "How strangers see you", shown while introductions are enabled
local STRANGER_ROW_HGT = LABEL_HGT + BUTTON_HGT + PADDING

-- the window open on each sheet (one per username)
local openWindows = {}

local function CreateButton(window, x, y, text, onClick)
    local width = getTextManager():MeasureStringX(FONT, text) + 20
    local button = ISButton:new(x, y, width, BUTTON_HGT, text, window, onClick)
    button:initialise()
    button:instantiate()
    button.borderColor = { r = 1, g = 1, b = 1, a = 0.15 }
    button.backgroundColor = { r = 0.25, g = 0.25, b = 0.25, a = 0.8 }
    window:addChild(button)
    return button
end

local function CreateEntry(window, x, y, width, height, maxLength, multipleLines)
    local entry = ISTextEntryBox:new('', x, y, width, height)
    entry.font = FONT
    entry:initialise()
    entry:instantiate()
    entry:setMaxTextLength(maxLength)
    if multipleLines then
        entry:setMultipleLine(true)
        entry:setMaxLines(200)
        entry:addScrollBars()
    end
    window:addChild(entry)
    return entry
end

local function CreateReadOnlyText(window, x, y, width, height)
    local panel = ISRichTextPanel:new(x, y, width, height)
    panel:initialise()
    panel:instantiate()
    panel.autosetheight = false
    panel.clip = true
    panel.background = true
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.3 }
    panel.borderColor = { r = 0.25, g = 0.25, b = 0.25, a = 1 }
    panel:setMargins(6, 4, 6, 4)
    panel:addScrollBars()
    window:addChild(panel)
    return panel
end

-- the sheets contain no markup (removed by the server), only line breaks to convert
local function SetReadOnlyText(panel, text)
    panel:setText((text:gsub('\n', ' <LINE> ')))
    panel:paginate()
    panel:setYScroll(0)
end

-- the name in the title: the one the player's character knows them by (introductions)
function CharacterSheetWindow:getShownName()
    local name = self:getCharacterName()
    if self.isOwn or name == self.username then
        return name
    end
    return Introductions.displayName(self.username, name, { lowercase = true })
end

function CharacterSheetWindow:getCharacterName()
    local sheet = CharacterSheetManager.getSheet(self.username)
    if sheet and sheet.firstName then
        return sheet.firstName .. ' ' .. sheet.lastName
    end
    if self.character then
        local firstName, lastName = Character.getFirstAndLastName(self.character)
        return firstName .. ' ' .. lastName
    end
    return self.username
end

function CharacterSheetWindow:createChildren()
    local modelY = TITLE_HGT + PADDING
    self.model = ISUI3DModel:new(PADDING, modelY, MODEL_WIDTH, MODEL_HEIGHT)
    self.model:setVisible(true)
    self:addChild(self.model)
    if self.character then
        self.model:setCharacter(self.character)
    end
    self.model:setState('idle')
    self.model:setDirection(IsoDirections.S)
    self.model:setIsometric(false)

    local x = PADDING + MODEL_WIDTH + PADDING
    local width = self.width - x - PADDING
    local y = TITLE_HGT + PADDING + LABEL_HGT
    self.fieldsX = x
    local limits = CharacterSheetManager.MaxLengths
    if self.isOwn then
        self.titleEntry = CreateEntry(self, x, y, width, BUTTON_HGT, limits.title, false)
        y = y + BUTTON_HGT + PADDING + LABEL_HGT
        if self.showStranger then
            self.strangerEntry = CreateEntry(self, x, y, width, BUTTON_HGT, limits.stranger, false)
            y = y + STRANGER_ROW_HGT
        end
        self.backgroundEntry = CreateEntry(self, x, y, width, BACKGROUND_HGT, limits.background, true)
        y = y + BACKGROUND_HGT + PADDING + LABEL_HGT
        self.oocEntry = CreateEntry(self, x, y, width, OOC_HGT, limits.ooc, true)
    else
        self.titleY = y
        y = y + BUTTON_HGT + PADDING + LABEL_HGT
        if self.showStranger then
            self.strangerY = y
            y = y + STRANGER_ROW_HGT
        end
        self.backgroundText = CreateReadOnlyText(self, x, y, width, BACKGROUND_HGT)
        y = y + BACKGROUND_HGT + PADDING + LABEL_HGT
        self.oocText = CreateReadOnlyText(self, x, y, width, OOC_HGT)
    end

    local buttonY = self.height - PADDING - BUTTON_HGT
    local close = CreateButton(self, 0, buttonY, getText('UI_Close'), CharacterSheetWindow.close)
    close:setX(self.width - PADDING - close:getWidth())
    if self.isOwn then
        local save = CreateButton(self, 0, buttonY, getText('UI_TICS_Sheet_save'), CharacterSheetWindow.onSave)
        save:setX(close:getX() - 6 - save:getWidth())
    elseif Character.isAdminOrModerator(getPlayer()) then
        CreateButton(self, PADDING, buttonY, getText('UI_TICS_Sheet_clear'), CharacterSheetWindow.onClear)
    end

    self.requestedAt = getTimestampMs()
    CharacterSheetManager.ask(self.username)
end

-- fills the fields once the sheet is received (the own sheet only once, not to erase edits)
function CharacterSheetWindow:updateFromSheet()
    local sheet = CharacterSheetManager.getSheet(self.username)
    if sheet == nil then
        return
    end
    if self.isOwn then
        if not self.filled then
            self.filled = true
            self.titleEntry:setText(sheet.title)
            if self.strangerEntry then
                self.strangerEntry:setText(sheet.stranger or '')
            end
            self.backgroundEntry:setText(sheet.background)
            self.oocEntry:setText(sheet.ooc)
        end
    elseif sheet.receivedAt >= self.requestedAt and sheet.receivedAt ~= self.shownAt then
        self.shownAt = sheet.receivedAt
        SetReadOnlyText(self.backgroundText, sheet.background)
        SetReadOnlyText(self.oocText, sheet.ooc)
    end
end

function CharacterSheetWindow:onSave()
    local stranger = self.strangerEntry and self.strangerEntry:getText() or nil
    if stranger == nil then
        -- not shown (introductions disabled): keep the saved one
        local sheet = CharacterSheetManager.getSheet(self.username)
        stranger = sheet and sheet.stranger or ''
    end
    CharacterSheetManager.save(self.titleEntry:getText(), self.backgroundEntry:getText(), self.oocEntry:getText(),
        stranger)
    self.status = getText('UI_TICS_Sheet_saved')
end

function CharacterSheetWindow:onClearConfirmed(button)
    if button.internal ~= 'YES' then
        return
    end
    local sheet = CharacterSheetManager.getSheet(self.username)
    if sheet and sheet.firstName then
        self.requestedAt = getTimestampMs()
        ClientSend.sendAdminClearCharacterSheet(self.username, sheet.firstName, sheet.lastName)
    end
end

function CharacterSheetWindow:onClear()
    local text = getText('UI_TICS_Sheet_clear_confirm', self:getCharacterName())
    local dialog = ISModalDialog:new(0, 0, 300, 120, text, true, self, CharacterSheetWindow.onClearConfirmed)
    dialog:initialise()
    dialog:addToUIManager()
    dialog:setAlwaysOnTop(true)
end

function CharacterSheetWindow:prerender()
    self:updateFromSheet()
    local body = ChatTheme.body
    local titleBar = ChatTheme.titleBar
    local border = ChatTheme.separator
    local active = ChatTheme.textActive
    local muted = ChatTheme.textMuted
    self:drawRect(0, 0, self.width, self.height, 0.95, body.r, body.g, body.b)
    self:drawRect(0, 0, self.width, TITLE_HGT, 1, titleBar.r, titleBar.g, titleBar.b)
    self:drawRect(0, TITLE_HGT - 1, self.width, 1, 1, border.r, border.g, border.b)
    self:drawRectBorder(0, 0, self.width, self.height, 1, border.r, border.g, border.b)
    self:drawText(getText('UI_TICS_Sheet_title', self:getShownName()), PADDING, (TITLE_HGT - FONT_HGT) / 2,
        active.r, active.g, active.b, 1, FONT)

    -- appearance: 3D model, and the avatar when custom portraits are used
    local modelY = TITLE_HGT + PADDING
    self:drawRect(PADDING, modelY, MODEL_WIDTH, MODEL_HEIGHT, 0.35, 0, 0, 0)
    self:drawRectBorder(PADDING, modelY, MODEL_WIDTH, MODEL_HEIGHT, 1, border.r, border.g, border.b)
    local portrait = TicsServerSettings and TicsServerSettings['options']['portrait']
    if portrait == 2 then
        local sheet = CharacterSheetManager.getSheet(self.username)
        local firstName = sheet and sheet.firstName
        local lastName = sheet and sheet.lastName
        if firstName == nil and self.character then
            firstName, lastName = Character.getFirstAndLastName(self.character)
        end
        local avatar = firstName and AvatarManager:getAvatar(self.username, firstName, lastName)
        if avatar then
            local avatarX = PADDING + (MODEL_WIDTH - AVATAR_WIDTH) / 2
            local avatarY = modelY + MODEL_HEIGHT + PADDING
            self:drawTextureScaled(avatar, avatarX, avatarY, AVATAR_WIDTH, AVATAR_HEIGHT, 1, 1, 1, 1)
            self:drawRectBorder(avatarX, avatarY, AVATAR_WIDTH, AVATAR_HEIGHT, 1, border.r, border.g, border.b)
        end
    end

    -- field labels
    local x = self.fieldsX
    local y = TITLE_HGT + PADDING
    self:drawText(getText('UI_TICS_Sheet_field_title'), x, y, muted.r, muted.g, muted.b, 1, FONT)
    y = y + LABEL_HGT + BUTTON_HGT + PADDING
    if self.showStranger then
        self:drawText(getText('UI_TICS_Sheet_field_stranger'), x, y, muted.r, muted.g, muted.b, 1, FONT)
        y = y + STRANGER_ROW_HGT
    end
    self:drawText(getText('UI_TICS_Sheet_field_background'), x, y, muted.r, muted.g, muted.b, 1, FONT)
    y = y + LABEL_HGT + BACKGROUND_HGT + PADDING
    self:drawText(getText('UI_TICS_Sheet_field_ooc'), x, y, muted.r, muted.g, muted.b, 1, FONT)

    if not self.isOwn then
        local sheet = CharacterSheetManager.getSheet(self.username)
        local loaded = sheet and sheet.receivedAt >= self.requestedAt
        local titleText = loaded and sheet.title or getText('UI_TICS_AvatarAdmin_loading')
        if loaded and titleText == '' then
            titleText = '-'
        end
        self:drawText(titleText, x, self.titleY + (BUTTON_HGT - FONT_HGT) / 2, active.r, active.g, active.b, 1, FONT)
        if self.strangerY then
            local stranger = loaded and (sheet.stranger ~= '' and sheet.stranger or '-') or ''
            self:drawText(stranger, x, self.strangerY + (BUTTON_HGT - FONT_HGT) / 2, active.r, active.g, active.b, 1, FONT)
        end
    end

    if self.status then
        self:drawText(self.status, PADDING, self.height - PADDING - BUTTON_HGT + (BUTTON_HGT - FONT_HGT) / 2,
            active.r, active.g, active.b, 1, FONT)
    end
end

function CharacterSheetWindow:close()
    openWindows[self.username:lower()] = nil
    self:setVisible(false)
    self:removeFromUIManager()
end

function CharacterSheetWindow:new(username, isOwn)
    local x = getCore():getScreenWidth() / 2 - WIDTH / 2
    local y = getCore():getScreenHeight() / 2 - HEIGHT / 2
    local showStranger = Introductions.isEnabled()
    local height = HEIGHT + (showStranger and STRANGER_ROW_HGT or 0)
    local o = ISPanel.new(self, x, y - (height - HEIGHT) / 2, WIDTH, height)
    o.moveWithMouse = true
    o.background = false
    o.showStranger = showStranger
    o.username = username
    o.isOwn = isOwn
    o.character = World.getPlayerByUsername(username)
    o.filled = false
    return o
end

function CharacterSheetWindow.isOpen(username)
    return openWindows[username:lower()] ~= nil
end

-- closes the sheet of a player when it is open, opens it otherwise (title bar button)
function CharacterSheetWindow.toggle(username)
    local existing = openWindows[username:lower()]
    if existing then
        existing:close()
        return nil
    end
    return CharacterSheetWindow.open(username)
end

-- opens the sheet of a player (own one: editable), brings it to the front if already open
function CharacterSheetWindow.open(username)
    local existing = openWindows[username:lower()]
    if existing then
        existing:bringToTop()
        return existing
    end
    local isOwn = username:lower() == getPlayer():getUsername():lower()
    local window = CharacterSheetWindow:new(username, isOwn)
    window:initialise()
    window:addToUIManager()
    window:setVisible(true)
    window:bringToTop()
    openWindows[username:lower()] = window
    return window
end

return CharacterSheetWindow
