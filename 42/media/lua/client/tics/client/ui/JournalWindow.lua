-- Journal window, opened by the book button of the chat title bar: the people the character
-- met on the left (search, filters, favorites first, grouped by when they were last seen),
-- the selected person on the right with three tabs: their sheet as last received, the scenes
-- shared with them, and the player's private notes. Data: tics/client/journal/Journal.lua

require 'ISUI/ISPanel'
require 'ISUI/ISTextEntryBox'
require 'ISUI/ISUI3DModel'

local Appearance = require('tics/client/journal/Appearance')
local AvatarManager = require('tics/client/AvatarManager')
local ChatTheme = require('tics/client/ui/ChatTheme')
local AvatarIO = require('tics/shared/utils/AvatarIO')
local File = require('tics/shared/utils/File')
local Journal = require('tics/client/journal/Journal')

local JournalWindow = ISPanel:derive('TicsJournalWindow')

local FONT = UIFont.Small
local NAME_FONT = UIFont.Medium
local PORTRAIT_WIDTH = 45
local PORTRAIT_HEIGHT = 60
local ICON_SIZE = 12
local CLOSE_ICON_SIZE = 12
local DAY_MS = 24 * 60 * 60 * 1000
local REFRESH_MS = 1000     -- the window follows the journal changes at most once per second
local NOTES_SAVE_MS = 3000  -- notes being typed are saved every 3 seconds
-- framing of the 3D portrait on the head and shoulders, like the bubble portraits
local MODEL_ZOOM = 17
local MODEL_Y_OFFSET = -0.92

local FILTERS = {
    { value = 'all', text = 'UI_TICS_Journal_all' },
    { value = 'favorites', text = 'UI_TICS_Journal_favorites' },
    { value = 'today', text = 'UI_TICS_Journal_today' },
}

local TABS = {
    { value = 'sheet', text = 'UI_TICS_Journal_tab_sheet' },
    { value = 'scenes', text = 'UI_TICS_Journal_tab_scenes' },
    { value = 'notes', text = 'UI_TICS_Journal_tab_notes' },
}

local instance = nil

---------------------------------------------------------------------------- helpers

local function Measure(text, font)
    return getTextManager():MeasureStringX(font or FONT, text)
end

local function IsInside(area, x, y)
    return area ~= nil and x >= area.x and x < area.x + area.width and y >= area.y and y < area.y + area.height
end

-- cuts a text to fit `width`, with '...' at the end
local function Truncate(text, width, font)
    if Measure(text, font) <= width then
        return text
    end
    local cut = #text
    while cut > 0 and Measure(text:sub(1, cut) .. '...', font) > width do
        cut = cut - 1
    end
    return text:sub(1, cut) .. '...'
end

-- splits a text in lines fitting maxWidth; words wider than a line (or texts without
-- spaces, like Chinese and Japanese) are cut anywhere
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

local function TimeAgo(ms, now)
    local diff = math.max(0, now - ms)
    local minutes = math.floor(diff / 60000)
    if minutes < 1 then
        return getText('UI_TICS_Journal_now')
    elseif minutes < 60 then
        return getText('UI_TICS_Journal_minutes', minutes)
    elseif diff < DAY_MS then
        return getText('UI_TICS_Journal_hours', math.floor(minutes / 60))
    elseif diff < 2 * DAY_MS then
        return getText('UI_TICS_Journal_yesterday')
    elseif diff < 7 * DAY_MS then
        return getText('UI_TICS_Journal_days', math.floor(diff / DAY_MS))
    elseif diff < 60 * DAY_MS then
        -- weeks up to 8, so a count of months is always 2 or more (plural in every language)
        return getText('UI_TICS_Journal_weeks', math.floor(diff / (7 * DAY_MS)))
    end
    return getText('UI_TICS_Journal_months', math.floor(diff / (30 * DAY_MS)))
end

local function Initials(name)
    local initials = ''
    for word in name:gmatch('%S+') do
        if #initials < 2 then
            initials = initials .. word:sub(1, 1):upper()
        end
    end
    return initials
end

-- the 3D portrait (live or rebuilt): head and shoulders, still
local function ConfigureModel(model)
    model:setState('idle')
    model:setDirection(IsoDirections.SE)
    model:setIsometric(false)
    model:setZoom(MODEL_ZOOM)
    model:setYOffset(MODEL_Y_OFFSET)
end

-- Approved avatar of the person. The game only knows the avatars of the players online this
-- session (its list is not saved by multiplayer clients in build 42), but the files received
-- before stay on disk under a name built from the username and character name: they are
-- looked up there (a deleted avatar is an emptied file and is skipped). The journal only
-- knows the full name: every split in first and last name is tried.
local function FindAvatar(person)
    if TicsServerSettings == nil or TicsServerSettings['options']['portrait'] ~= 2 then
        return nil
    end
    local start = 1
    while true do
        local space = person.name:find(' ', start, true)
        if space == nil then
            return nil
        end
        local firstName, lastName = person.name:sub(1, space - 1), person.name:sub(space + 1)
        local avatar = AvatarManager:getAvatar(person.username, firstName, lastName)
        if avatar then
            return avatar
        end
        -- approved avatars are saved in <base>/<own username>/ (AvatarManager SaveAvatar)
        local fileName = AvatarIO.createFileName(person.username, firstName, lastName)
        local path = AvatarIO.getAvatarPath(getPlayer():getUsername() .. '//' .. fileName)
        if path then
            return File.getTexture(path)
        end
        start = space + 1
    end
end

local function SetColor(color)
    return color.r, color.g, color.b
end

---------------------------------------------------------------------------- layout

function JournalWindow:computeLayout()
    local fontHeight = getTextManager():getFontHeight(FONT)
    self.fontHeight = fontHeight
    self.headerHeight = fontHeight + 10
    self.sideWidth = math.floor(self.width * 0.34)
    self.rowHeight = fontHeight * 2 + 8
    self.groupHeight = fontHeight + 10

    local x = 10
    local y = self.headerHeight + 10
    local width = self.sideWidth - 20
    self.searchArea = { x = x, y = y, width = width, height = fontHeight + 10 }
    y = y + self.searchArea.height + 6
    self.filterAreas = {}
    for index, filter in ipairs(FILTERS) do
        local left = x + math.floor(width * (index - 1) / #FILTERS)
        local right = x + math.floor(width * index / #FILTERS)
        table.insert(self.filterAreas, { x = left, y = y, width = right - left, height = fontHeight + 6, value = filter.value, text = filter.text, first = index == 1 })
    end
    y = y + fontHeight + 6 + 6
    self.countY = y
    y = y + fontHeight + 4
    self.listArea = { x = 0, y = y, width = self.sideWidth, height = self.height - y - 1 }

    local mainX = self.sideWidth + 1
    self.mainX = mainX
    local nameHeight = getTextManager():getFontHeight(NAME_FONT)
    self.whoY = self.headerHeight + 12
    self.whoHeight = math.max(PORTRAIT_HEIGHT, nameHeight + 2 + fontHeight * 3 + 4)
    self.portraitArea = { x = mainX + 14, y = self.whoY, width = PORTRAIT_WIDTH, height = PORTRAIT_HEIGHT }
    self.starArea = { x = self.width - 14 - 24, y = self.whoY, width = 24, height = 24 }
    local tabsY = self.whoY + self.whoHeight + 10
    self.tabAreas = {}
    local tabX = mainX + 14
    for _, tab in ipairs(TABS) do
        local tabWidth = Measure(getText(tab.text))
        table.insert(self.tabAreas, { x = tabX, y = tabsY, width = tabWidth, height = fontHeight + 10, value = tab.value, text = tab.text })
        tabX = tabX + tabWidth + 18
    end
    local paneY = tabsY + fontHeight + 10 + 1
    self.paneArea = { x = mainX + 14, y = paneY, width = self.width - mainX - 28, height = self.height - paneY - 1 }
end

function JournalWindow:createChildren()
    self:computeLayout()
    local search = self.searchArea
    local entry = ISTextEntryBox:new('', search.x + ICON_SIZE + 14, search.y + 1, search.width - ICON_SIZE - 16, search.height - 2)
    entry.font = FONT
    entry:initialise()
    entry:instantiate()
    entry.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    entry.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    entry:setMaxTextLength(60)
    entry.target = self
    entry.onTextChangeFunction = JournalWindow.onSearchChange
    self:addChild(entry)
    self.searchEntry = entry

    local pane = self.paneArea
    local notes = ISTextEntryBox:new('', pane.x, pane.y + 8, pane.width, pane.height - 8 - self.fontHeight - 16)
    notes.font = FONT
    notes:initialise()
    notes:instantiate()
    notes:setMultipleLine(true)
    notes:setMaxLines(500)
    notes:setMaxTextLength(4000)
    notes:addScrollBars()
    notes.backgroundColor = { r = 0, g = 0, b = 0, a = 0.35 }
    notes.borderColor = { r = ChatTheme.inputBorder.r, g = ChatTheme.inputBorder.g, b = ChatTheme.inputBorder.b, a = 1 }
    notes:setVisible(false)
    self:addChild(notes)
    self.notesEntry = notes

    local portrait = self.portraitArea
    local model = ISUI3DModel:new(portrait.x, portrait.y, portrait.width, portrait.height)
    model:initialise()
    model:instantiate()
    model:setVisible(false)
    self:addChild(model)
    self.model = model
end

-- Portrait of the selected person, in order: custom avatar, their 3D model when they are
-- loaded around, their saved appearance rebuilt in 3D, initials.
function JournalWindow:updatePortrait()
    local person = self.selected
    self.avatar = nil
    self.livePlayer = nil
    self.portraitMode = 'initials'
    if person then
        self.avatar = FindAvatar(person)
        if self.avatar then
            self.portraitMode = 'avatar'
        else
            local live = Journal.getLivePlayer(person)
            if live then
                self.model:setCharacter(live)
                ConfigureModel(self.model)
                self.livePlayer = live
                self.portraitMode = 'model'
                Journal.captureAppearance(person, live)
            else
                local data = Journal.getAppearance(person)
                if data then
                    local ok, desc = pcall(Appearance.buildDesc, data)
                    if ok and desc then
                        self.model:setSurvivorDesc(desc)
                        ConfigureModel(self.model)
                        self.portraitMode = 'model'
                    else
                        print('TICS error: Journal: cannot rebuild the appearance of ' .. person.name .. ': ' .. tostring(desc))
                    end
                end
            end
        end
    end
    self.model:setVisible(self.portraitMode == 'model')
    self.portraitCheckedAt = getTimestampMs()
end

---------------------------------------------------------------------------- list

function JournalWindow:onSearchChange()
    local query = self.searchEntry:getInternalText() or ''
    if query ~= '' then
        Journal.loadAllSheets()
    end
    self.query = query:lower()
    self.listScroll = 0
    self:buildList()
end

local function Matches(person, query)
    if query == '' then
        return true
    end
    local function Has(text)
        return text ~= nil and text:lower():find(query, 1, true) ~= nil
    end
    return Has(person.name) or Has(person.title) or Has(person.background) or Has(person.ooc)
end

-- rows of the list: { group = text } and { person = person }, with their y position
function JournalWindow:buildList()
    local now = getTimestampMs()
    local today = Journal.formatDate(now):sub(1, 10)
    local favorites, groups = {}, { {}, {}, {} }
    local total, shown = 0, 0
    local byId = {}
    for _, person in ipairs(Journal.getPeople()) do
        total = total + 1
        byId[person.id] = person
        local seenToday = Journal.formatDate(person.lastSeen):sub(1, 10) == today
        local visible = Matches(person, self.query)
            and (self.filter ~= 'favorites' or person.favorite)
            and (self.filter ~= 'today' or seenToday)
        if visible then
            shown = shown + 1
            if person.favorite then
                table.insert(favorites, person)
            elseif seenToday then
                table.insert(groups[1], person)
            elseif now - person.lastSeen < 7 * DAY_MS then
                table.insert(groups[2], person)
            else
                table.insert(groups[3], person)
            end
        end
    end
    local function ByLastSeen(a, b)
        return a.lastSeen > b.lastSeen
    end
    local rows = {}
    local y = 0
    local function AddGroup(title, list)
        if #list == 0 then
            return
        end
        table.sort(list, ByLastSeen)
        table.insert(rows, { group = title, y = y })
        y = y + self.groupHeight
        for _, person in ipairs(list) do
            table.insert(rows, { person = person, y = y })
            y = y + self.rowHeight
        end
    end
    AddGroup(getText('UI_TICS_Journal_favorites'), favorites)
    AddGroup(getText('UI_TICS_Journal_today'), groups[1])
    AddGroup(getText('UI_TICS_Journal_this_week'), groups[2])
    AddGroup(getText('UI_TICS_Journal_earlier'), groups[3])
    self.rows = rows
    self.listHeight = y
    self.total = total
    self.shown = shown
    self.now = now
    self:clampScroll()

    -- keep the selection on a person of the journal (the journal of a new character has
    -- other people), the first one shown by default
    local current = self.selected and byId[self.selected.id] or nil
    if current ~= self.selected then
        self.selected = nil
    end
    if current then
        self:select(current)
    else
        for _, row in ipairs(rows) do
            if row.person then
                self:select(row.person)
                break
            end
        end
    end
end

function JournalWindow:clampScroll()
    local maxList = math.max(0, (self.listHeight or 0) - self.listArea.height)
    self.listScroll = math.max(0, math.min(self.listScroll or 0, maxList))
    local maxPane = math.max(0, (self.paneHeight or 0) - self.paneArea.height)
    self.paneScroll = math.max(0, math.min(self.paneScroll or 0, maxPane))
end

---------------------------------------------------------------------------- selected person

function JournalWindow:saveNotes()
    if self.notesPerson and self.notesText ~= nil then
        local text = self.notesEntry:getText() or ''
        if text ~= self.notesText then
            Journal.setNotes(self.notesPerson, text)
            self.notesText = text
        end
    end
end

function JournalWindow:select(person)
    if person == self.selected then
        return
    end
    self:saveNotes()
    self.selected = person
    self:updatePortrait()
    self.notesPerson = person
    self.notesText = person and Journal.getNotes(person) or nil
    self.notesEntry:setText(self.notesText or '')
    self.notesEntry:setVisible(self.tab == 'notes' and person ~= nil)
    self:buildPane(true)
end

function JournalWindow:setTab(tab)
    if tab == self.tab then
        return
    end
    self:saveNotes()
    self.tab = tab
    self.notesEntry:setVisible(tab == 'notes' and self.selected ~= nil)
    self:buildPane(true)
end

-- places the text of the sheet or scenes tab: self.paneItems, self.paneHeight
function JournalWindow:buildPane(resetScroll)
    local items = {}
    local y = 6
    local width = self.paneArea.width
    local fontHeight = self.fontHeight
    local person = self.selected

    local function Paragraphs(text)
        for paragraph in (text .. '\n'):gmatch('([^\n]*)\n') do
            for _, line in ipairs(WrapText(paragraph, width)) do
                table.insert(items, { text = line, x = 0, y = y })
                y = y + fontHeight
            end
            y = y + 6
        end
    end

    if person == nil then
        -- nothing to show
    elseif self.tab == 'sheet' then
        if person.hasSheet then
            local background, ooc = Journal.getSheetText(person)
            table.insert(items, { text = getText('UI_TICS_Sheet_field_background'), x = 0, y = y + 4, muted = true })
            y = y + fontHeight + 10
            Paragraphs(background ~= '' and background or '-')
            table.insert(items, { text = getText('UI_TICS_Sheet_field_ooc'), x = 0, y = y + 4, muted = true })
            y = y + fontHeight + 10
            Paragraphs(ooc ~= '' and ooc or '-')
        else
            y = y + 4
            for _, line in ipairs(WrapText(getText('UI_TICS_Journal_no_sheet_text', person.name), width)) do
                table.insert(items, { text = line, x = 0, y = y, muted = true })
                y = y + fontHeight
            end
        end
    elseif self.tab == 'scenes' then
        local entries = Journal.getScenes(person)
        if #entries == 0 then
            table.insert(items, { text = getText('UI_TICS_Journal_no_scenes'), x = 0, y = y + 4, muted = true })
            y = y + fontHeight + 8
        end
        local timeWidth = Measure('00:00') + 10
        for _, entry in ipairs(entries) do
            if entry.header then
                y = y + 8
                table.insert(items, { separator = getText('UI_TICS_Journal_scene', Journal.formatDate(entry.time), entry.gameDate), y = y })
                y = y + fontHeight + 6
            else
                local lines = WrapText(entry.text, width - timeWidth - 6)
                local height = #lines * fontHeight + 2
                if entry.fromThem then
                    table.insert(items, { highlight = true, y = y, height = height })
                end
                table.insert(items, { text = Journal.formatDate(entry.time):sub(12), x = 0, y = y + 1, muted = true })
                for index, line in ipairs(lines) do
                    table.insert(items, { text = line, x = timeWidth, y = y + 1 + (index - 1) * fontHeight })
                end
                y = y + height
            end
        end
    end
    self.paneItems = items
    self.paneHeight = y + 8
    if resetScroll then
        -- the scenes open on the latest lines, like the chat
        self.paneScroll = self.tab == 'scenes' and self.paneHeight or 0
    end
    self:clampScroll()
end

---------------------------------------------------------------------------- rendering

function JournalWindow:getCloseArea()
    return { x = self.width - self.headerHeight, y = 0, width = self.headerHeight, height = self.headerHeight }
end

function JournalWindow:drawIcon(path, x, y, size, color, alpha)
    local texture = getTexture(path)
    if texture then
        self:drawTextureScaled(texture, x, y, size, size, alpha or 1, color.r, color.g, color.b)
    end
end

function JournalWindow:renderHeader(mouseX, mouseY)
    local titleBar = ChatTheme.titleBar
    local separator = ChatTheme.separator
    self:drawRect(1, 1, self.width - 2, self.headerHeight - 1, 1, SetColor(titleBar))
    self:drawRect(1, self.headerHeight, self.width - 2, 1, 1, SetColor(separator))
    local active = ChatTheme.textActive
    self:drawText(getText('UI_TICS_Journal_title'), 12, (self.headerHeight - self.fontHeight) / 2, active.r, active.g, active.b, 1, FONT)
    local close = self:getCloseArea()
    local color = IsInside(close, mouseX or -1, mouseY or -1) and ChatTheme.textActive or ChatTheme.iconIdle
    self:drawIcon(ChatTheme.icons.close, close.x + (close.width - CLOSE_ICON_SIZE) / 2, close.y + (close.height - CLOSE_ICON_SIZE) / 2, CLOSE_ICON_SIZE, color)
end

function JournalWindow:renderSide(mouseX, mouseY)
    local fontHeight = self.fontHeight
    local separator = ChatTheme.separator
    local muted = ChatTheme.textMuted
    self:drawRect(self.sideWidth, self.headerHeight + 1, 1, self.height - self.headerHeight - 2, 1, SetColor(separator))

    -- search box
    local search = self.searchArea
    self:drawRect(search.x, search.y, search.width, search.height, 0.35, 0, 0, 0)
    local focused = self.searchEntry:isFocused()
    local border = focused and ChatTheme.accent or ChatTheme.inputBorder
    self:drawRectBorder(search.x, search.y, search.width, search.height, 1, SetColor(border))
    self:drawIcon(ChatTheme.icons.search, search.x + 8, search.y + (search.height - ICON_SIZE) / 2, ICON_SIZE, ChatTheme.textMuted)
    if (self.searchEntry:getInternalText() or '') == '' and not focused then
        local hint = Truncate(getText('UI_TICS_Journal_search'), search.width - ICON_SIZE - 20)
        self:drawText(hint, search.x + ICON_SIZE + 16, search.y + (search.height - fontHeight) / 2, muted.r, muted.g, muted.b, 1, FONT)
    end

    -- filters
    local inputBorder = ChatTheme.inputBorder
    for _, area in ipairs(self.filterAreas) do
        local current = area.value == self.filter
        local hovered = IsInside(area, mouseX or -1, mouseY or -1)
        if current then
            self:drawRect(area.x, area.y, area.width, area.height, 1, SetColor(ChatTheme.chip))
            self:drawRect(area.x, area.y + area.height - 2, area.width, 2, 1, SetColor(ChatTheme.accent))
        elseif hovered then
            self:drawRect(area.x, area.y, area.width, area.height, 1, SetColor(ChatTheme.rowHover))
        end
        self:drawRect(area.x, area.y, area.width, 1, 1, SetColor(inputBorder))
        self:drawRect(area.x, area.y + area.height - 1, area.width, 1, 1, SetColor(inputBorder))
        self:drawRect(area.x + area.width - 1, area.y, 1, area.height, 1, SetColor(inputBorder))
        if area.first then
            self:drawRect(area.x, area.y, 1, area.height, 1, SetColor(inputBorder))
        end
        local color = (current or hovered) and ChatTheme.textActive or ChatTheme.textMuted
        local label = Truncate(getText(area.text), area.width - 6)
        self:drawTextCentre(label, area.x + area.width / 2, area.y + (area.height - fontHeight) / 2, color.r, color.g, color.b, 1, FONT)
    end

    -- count
    self:drawText(getText('UI_TICS_Journal_count', self.shown or 0, self.total or 0), 10, self.countY, muted.r, muted.g, muted.b, 1, FONT)
    self:drawTextRight(getText('UI_TICS_Journal_last_seen'), self.sideWidth - 10, self.countY, muted.r, muted.g, muted.b, 1, FONT)

    -- list, only the visible rows
    local list = self.listArea
    self:setStencilRect(list.x, list.y, list.width, list.height)
    if self.total == 0 then
        local y = list.y + 8
        for _, line in ipairs(WrapText(getText('UI_TICS_Journal_empty'), list.width - 20)) do
            self:drawText(line, 10, y, muted.r, muted.g, muted.b, 1, FONT)
            y = y + fontHeight
        end
    elseif self.shown == 0 then
        self:drawText(getText('UI_TICS_Journal_no_match'), 10, list.y + 8, muted.r, muted.g, muted.b, 1, FONT)
    end
    local top = list.y - self.listScroll
    local hoveredRow = nil
    if mouseX and IsInside(list, mouseX, mouseY) then
        hoveredRow = mouseY - top
    end
    for _, row in ipairs(self.rows or {}) do
        local y = top + row.y
        local height = row.group and self.groupHeight or self.rowHeight
        if y + height >= list.y and y <= list.y + list.height then
            if row.group then
                self:drawText(row.group, 10, y + self.groupHeight - fontHeight - 3, muted.r, muted.g, muted.b, 1, FONT)
            else
                self:renderRow(row.person, y, hoveredRow ~= nil and hoveredRow >= row.y and hoveredRow < row.y + self.rowHeight, mouseX)
            end
        end
    end
    self:renderScrollBar(list, self.listScroll, self.listHeight or 0)
    self:clearStencilRect()
end

function JournalWindow:renderRow(person, y, hovered, mouseX)
    local fontHeight = self.fontHeight
    if person == self.selected then
        self:drawRect(0, y, self.sideWidth, self.rowHeight, 1, SetColor(ChatTheme.chip))
        self:drawRect(0, y, 2, self.rowHeight, 1, SetColor(ChatTheme.accent))
    elseif hovered then
        self:drawRect(0, y, self.sideWidth, self.rowHeight, 1, SetColor(ChatTheme.rowHover))
    end
    local starHovered = hovered and mouseX ~= nil and mouseX < 26
    local starColor = person.favorite and ChatTheme.accent or (starHovered and ChatTheme.textHover or ChatTheme.inputBorder)
    self:drawIcon(ChatTheme.icons.star, 8, y + (self.rowHeight - ICON_SIZE) / 2, ICON_SIZE, starColor)

    local muted = ChatTheme.textMuted
    local seen = TimeAgo(person.lastSeen, self.now)
    local seenWidth = Measure(seen)
    self:drawTextRight(seen, self.sideWidth - 10, y + 4, muted.r, muted.g, muted.b, 1, FONT)
    local textX = 28
    local active = ChatTheme.textActive
    self:drawText(Truncate(person.name, self.sideWidth - textX - seenWidth - 18), textX, y + 4, active.r, active.g, active.b, 1, FONT)
    local title = person.hasSheet and (person.title ~= '' and person.title or '-') or getText('UI_TICS_Journal_no_sheet_row')
    self:drawText(Truncate(title, self.sideWidth - textX - 10), textX, y + 4 + fontHeight, muted.r, muted.g, muted.b, 1, FONT)
end

function JournalWindow:renderScrollBar(area, scroll, contentHeight)
    if contentHeight <= area.height then
        return
    end
    local height = math.max(20, area.height * area.height / contentHeight)
    local y = area.y + (area.height - height) * scroll / (contentHeight - area.height)
    self:drawRect(area.x + area.width - 4, y, 3, height, 1, SetColor(ChatTheme.chip))
end

function JournalWindow:renderMain(mouseX, mouseY)
    local person = self.selected
    local fontHeight = self.fontHeight
    local muted = ChatTheme.textMuted
    if person == nil then
        return
    end

    -- who: portrait, name, title, dates, favorite star
    local portrait = self.portraitArea
    if self.portraitMode == 'avatar' then
        self:drawTextureScaled(self.avatar, portrait.x, portrait.y, portrait.width, portrait.height, 1, 1, 1, 1)
    elseif self.portraitMode == 'initials' then
        self:drawRect(portrait.x, portrait.y, portrait.width, portrait.height, 1, SetColor(ChatTheme.chip))
        self:drawTextCentre(Initials(person.name), portrait.x + portrait.width / 2, portrait.y + (portrait.height - getTextManager():getFontHeight(NAME_FONT)) / 2,
            muted.r, muted.g, muted.b, 1, NAME_FONT)
    end
    local x = portrait.x + portrait.width + 12
    local width = self.starArea.x - x - 8
    local y = self.whoY
    local active = ChatTheme.textActive
    self:drawText(Truncate(person.name, width, NAME_FONT), x, y, active.r, active.g, active.b, 1, NAME_FONT)
    y = y + getTextManager():getFontHeight(NAME_FONT) + 2
    if person.hasSheet and person.title ~= '' then
        local hover = ChatTheme.textHover
        self:drawText(Truncate(person.title, width), x, y, hover.r, hover.g, hover.b, 1, FONT)
    end
    y = y + fontHeight + 4
    local sheetLine = person.hasSheet
        and getText('UI_TICS_Journal_sheet_updated', Journal.formatDate(person.sheetUpdated), person.sheetGameDate:sub(1, 10))
        or getText('UI_TICS_Journal_no_sheet')
    self:drawText(Truncate(sheetLine, width), x, y, muted.r, muted.g, muted.b, 1, FONT)
    y = y + fontHeight
    local metLine = getText('UI_TICS_Journal_met', Journal.formatDate(person.firstSeen), TimeAgo(person.lastSeen, self.now))
    self:drawText(Truncate(metLine, width), x, y, muted.r, muted.g, muted.b, 1, FONT)
    local star = self.starArea
    local starHovered = IsInside(star, mouseX or -1, mouseY or -1)
    local starColor = person.favorite and ChatTheme.accent or (starHovered and ChatTheme.textHover or ChatTheme.inputBorder)
    self:drawIcon(ChatTheme.icons.star, star.x + 4, star.y + 4, 16, starColor)

    -- tabs
    local separator = ChatTheme.separator
    local lineY = self.tabAreas[1].y + self.tabAreas[1].height
    self:drawRect(self.mainX, lineY, self.width - self.mainX - 1, 1, 1, SetColor(separator))
    for _, tab in ipairs(self.tabAreas) do
        local current = tab.value == self.tab
        local hovered = IsInside(tab, mouseX or -1, mouseY or -1)
        local color = (current or hovered) and ChatTheme.textActive or ChatTheme.textMuted
        self:drawText(getText(tab.text), tab.x, tab.y + 4, color.r, color.g, color.b, 1, FONT)
        if current then
            self:drawRect(tab.x, lineY - 1, tab.width, 2, 1, SetColor(ChatTheme.accent))
        end
    end

    -- pane
    local pane = self.paneArea
    if self.tab == 'notes' then
        self:drawText(Truncate(getText('UI_TICS_Journal_notes_hint'), pane.width), pane.x, pane.y + pane.height - fontHeight - 6,
            muted.r, muted.g, muted.b, 1, FONT)
        return
    end
    self:setStencilRect(pane.x - 8, pane.y, pane.width + 12, pane.height)
    local top = pane.y - self.paneScroll
    local hover = ChatTheme.textHover
    local accent = ChatTheme.accent
    for _, item in ipairs(self.paneItems or {}) do
        local itemY = top + item.y
        local height = item.height or fontHeight
        if itemY + height >= pane.y and itemY <= pane.y + pane.height then
            if item.highlight then
                self:drawRect(pane.x - 6, itemY, pane.width + 6, item.height, 0.07, accent.r, accent.g, accent.b)
                self:drawRect(pane.x - 6, itemY, 2, item.height, 0.5, accent.r, accent.g, accent.b)
            elseif item.separator then
                local textWidth = Measure(item.separator)
                local middle = pane.x + pane.width / 2
                local lineY2 = itemY + fontHeight / 2
                self:drawRect(pane.x, lineY2, math.max(0, pane.width / 2 - textWidth / 2 - 8), 1, 1, SetColor(separator))
                self:drawRect(middle + textWidth / 2 + 8, lineY2, math.max(0, pane.width / 2 - textWidth / 2 - 8), 1, 1, SetColor(separator))
                self:drawTextCentre(item.separator, middle, itemY, muted.r, muted.g, muted.b, 1, FONT)
            else
                local color = item.muted and muted or hover
                self:drawText(item.text, pane.x + item.x, itemY, color.r, color.g, color.b, 1, FONT)
            end
        end
    end
    self:renderScrollBar({ x = pane.x, y = pane.y, width = pane.width + 4, height = pane.height }, self.paneScroll, self.paneHeight or 0)
    self:clearStencilRect()
end

function JournalWindow:prerender()
    local body = ChatTheme.body
    self:drawRect(0, 0, self.width, self.height, ChatTheme.popupOpacity, SetColor(body))
    self:drawRectBorder(0, 0, self.width, self.height, 1, SetColor(ChatTheme.inputBorder))
    -- background of the 3D portrait, drawn before the model (a child of the window)
    if self.portraitMode == 'model' then
        local portrait = self.portraitArea
        self:drawRect(portrait.x, portrait.y, portrait.width, portrait.height, 1, SetColor(ChatTheme.chip))
    end
end

function JournalWindow:render()
    local now = getTimestampMs()
    if self.needsRefresh and now - (self.refreshedAt or 0) >= REFRESH_MS then
        self.needsRefresh = false
        self.refreshedAt = now
        self:buildList()
        if self.tab == 'scenes' then
            local atBottom = self.paneScroll >= (self.paneHeight or 0) - self.paneArea.height - 4
            self:buildPane(false)
            if atBottom then
                self.paneScroll = self.paneHeight
                self:clampScroll()
            end
        end
    end
    -- a live portrait falls back to the saved appearance when the person leaves
    if self.livePlayer and now - (self.portraitCheckedAt or 0) >= REFRESH_MS then
        if self.selected == nil or Journal.getLivePlayer(self.selected) ~= self.livePlayer then
            self:updatePortrait()
        else
            self.portraitCheckedAt = now
        end
    end
    if self.tab == 'notes' and now - (self.notesSavedAt or 0) >= NOTES_SAVE_MS then
        self.notesSavedAt = now
        self:saveNotes()
    end

    local mouseX, mouseY
    if self:isMouseOver() then
        mouseX, mouseY = self:getMouseX(), self:getMouseY()
    end
    self:renderHeader(mouseX, mouseY)
    self:renderSide(mouseX, mouseY)
    self:renderMain(mouseX, mouseY)
end

---------------------------------------------------------------------------- mouse

function JournalWindow:onMouseDown(x, y)
    if y < self.headerHeight and not IsInside(self:getCloseArea(), x, y) then
        return ISPanel.onMouseDown(self, x, y) -- drag the window by its title bar
    end
    return true
end

function JournalWindow:onMouseUp(x, y)
    local wasMoving = self.moving
    ISPanel.onMouseUp(self, x, y)
    if wasMoving then
        return true
    end
    if IsInside(self:getCloseArea(), x, y) then
        self:close()
        return true
    end
    for _, area in ipairs(self.filterAreas) do
        if IsInside(area, x, y) then
            self.filter = area.value
            self.listScroll = 0
            self:buildList()
            return true
        end
    end
    if IsInside(self.listArea, x, y) then
        local offset = y - self.listArea.y + self.listScroll
        for _, row in ipairs(self.rows or {}) do
            if row.person and offset >= row.y and offset < row.y + self.rowHeight then
                if x < 26 then
                    Journal.setFavorite(row.person, not row.person.favorite)
                    self:buildList()
                else
                    self:select(row.person)
                end
                return true
            end
        end
        return true
    end
    if self.selected and IsInside(self.starArea, x, y) then
        Journal.setFavorite(self.selected, not self.selected.favorite)
        self:buildList()
        return true
    end
    for _, tab in ipairs(self.tabAreas) do
        if IsInside(tab, x, y) then
            self:setTab(tab.value)
            return true
        end
    end
    return true
end

function JournalWindow:onMouseWheel(del)
    local x, y = self:getMouseX(), self:getMouseY()
    if IsInside(self.listArea, x, y) then
        self.listScroll = (self.listScroll or 0) + del * self.rowHeight
    elseif IsInside(self.paneArea, x, y) and self.tab ~= 'notes' then
        self.paneScroll = (self.paneScroll or 0) + del * self.fontHeight * 3
    end
    self:clampScroll()
    return true
end

---------------------------------------------------------------------------- open / close

function JournalWindow:close()
    self:saveNotes()
    Journal.removeListener(self.listener)
    Journal.save()
    self:setVisible(false)
    self:removeFromUIManager()
    if instance == self then
        instance = nil
    end
end

function JournalWindow:new()
    local fontHeight = getTextManager():getFontHeight(FONT)
    local width = math.max(720, fontHeight * 46)
    local height = math.max(480, fontHeight * 30)
    local x = getCore():getScreenWidth() / 2 - width / 2
    local y = getCore():getScreenHeight() / 2 - height / 2
    local o = ISPanel.new(self, x, y, width, height)
    o.moveWithMouse = true
    o.background = false
    o.filter = 'all'
    o.tab = 'sheet'
    o.query = ''
    o.listScroll = 0
    o.paneScroll = 0
    return o
end

function JournalWindow.isOpen()
    return instance ~= nil
end

function JournalWindow.toggle()
    if instance then
        instance:close()
        return
    end
    local window = JournalWindow:new()
    window:initialise()
    window:addToUIManager()
    window:setVisible(true)
    window:bringToTop()
    window.listener = function()
        window.needsRefresh = true
    end
    Journal.addListener(window.listener)
    window:buildList()
    instance = window
    return window
end

Events.OnKeyPressed.Add(function(key)
    if key == Keyboard.KEY_ESCAPE and instance then
        instance:close()
    end
end)

return JournalWindow
