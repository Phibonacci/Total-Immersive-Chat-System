-- Avatar management window (admins and moderators), two tabs:
-- - Pending: every avatar request waiting for approval, each can be approved or rejected
-- - Approved: every approved avatar of the server with its username and character name, each
--   can be deleted. The list comes from the server, the images are asked for the visible rows.

require 'ISUI/ISPanel'
require 'ISUI/ISButton'
require 'ISUI/ISModalDialog'

local AvatarManager = require('tics/client/AvatarManager')
local AvatarIO = require('tics/shared/utils/AvatarIO')
local ChatTheme = require('tics/client/ui/ChatTheme')
local ClientSend = require('tics/client/network/ClientSend')


local AvatarValidationWindow = ISPanel:derive('AvatarValidationWindow')

local AVATAR_WIDTH = 60
local AVATAR_HEIGHT = 80
local FONT = UIFont.Small
local FONT_HGT = getTextManager():getFontHeight(FONT)
local PADDING = 12
local TITLE_HGT = FONT_HGT + 10
local TAB_HGT = FONT_HGT + 12
local BUTTON_HGT = FONT_HGT + 8
local ROW_PADDING = 8
local ROW_HGT = AVATAR_HEIGHT + ROW_PADDING * 2
local VISIBLE_ROWS = 4
local LIST_WIDTH = 440
local LIST_HGT = ROW_HGT * VISIBLE_ROWS
local WIDTH = LIST_WIDTH + PADDING * 2
local HEIGHT = TITLE_HGT + TAB_HGT + PADDING + LIST_HGT + PADDING + BUTTON_HGT + PADDING
local LIST_REFRESH_MS = 5000

local REJECT_COLOR = { r = 0.9, g = 0.45, b = 0.35 }

local TAB_PENDING = 'pending'
local TAB_APPROVED = 'approved'

local function CharacterName(row)
    return row.firstName .. ' ' .. row.lastName
end

-- list -----------------------------------------------------------------------------------

local AvatarList = ISPanel:derive('TicsAvatarList')

-- buttons of a row, right aligned: { text, x, y, width, height, color, action }
function AvatarList:getRowButtons(row, rowY)
    local window = self.window
    local specs
    if window.tab == TAB_PENDING then
        specs = {
            { text = getText('UI_TICS_AvatarAdmin_reject'), color = REJECT_COLOR, action = 'reject' },
            { text = getText('UI_TICS_AvatarAdmin_approve'), color = ChatTheme.accent, action = 'approve' },
        }
    else
        specs = {
            { text = getText('UI_TICS_Avatar_delete'), color = REJECT_COLOR, action = 'delete' },
        }
    end
    local x = self.width - ROW_PADDING - 13 -- scrollbar
    local y = rowY + (ROW_HGT - BUTTON_HGT) / 2
    for i = #specs, 1, -1 do
        local spec = specs[i]
        spec.width = getTextManager():MeasureStringX(FONT, spec.text) + 20
        spec.height = BUTTON_HGT
        x = x - spec.width
        spec.x = x
        spec.y = y
        x = x - 6
    end
    return specs
end

function AvatarList:prerender()
    local body = ChatTheme.pill
    self:drawRect(0, -self:getYScroll(), self.width, self.height, 0.25, body.r, body.g, body.b)
    local border = ChatTheme.separator
    self:drawRectBorder(0, -self:getYScroll(), self.width, self.height, 1, border.r, border.g, border.b)
end

function AvatarList:render()
    local window = self.window
    local rows = window:getRows()
    self:setScrollHeight(math.max(#rows * ROW_HGT, self.height))
    self:setStencilRect(0, 0, self.width, self.height)

    local muted = ChatTheme.textMuted
    local active = ChatTheme.textActive
    if #rows == 0 then
        local text = window:getEmptyText()
        self:drawTextCentre(text, self.width / 2, PADDING, muted.r, muted.g, muted.b, 1, FONT)
    end

    local mouseX, mouseY = self:getMouseX(), self:getMouseY()
    local isMouseOver = self:isMouseOver()
    for index, row in ipairs(rows) do
        local rowY = (index - 1) * ROW_HGT
        if rowY + ROW_HGT + self:getYScroll() >= 0 and rowY + self:getYScroll() <= self.height then
            if index % 2 == 0 then
                self:drawRect(0, rowY, self.width, ROW_HGT, ChatTheme.stripeOpacity, 1, 1, 1)
            end
            local avatarX = ROW_PADDING
            local avatarY = rowY + ROW_PADDING
            local texture = window:getRowTexture(row)
            self:drawRect(avatarX, avatarY, AVATAR_WIDTH, AVATAR_HEIGHT, 0.5, 0, 0, 0)
            if texture then
                self:drawTextureScaled(texture, avatarX, avatarY, AVATAR_WIDTH, AVATAR_HEIGHT, 1, 1, 1, 1)
            else
                self:drawTextCentre('...', avatarX + AVATAR_WIDTH / 2, avatarY + (AVATAR_HEIGHT - FONT_HGT) / 2,
                    muted.r, muted.g, muted.b, 1, FONT)
            end

            local textX = avatarX + AVATAR_WIDTH + PADDING
            local textY = rowY + (ROW_HGT - FONT_HGT * 2 - 2) / 2
            self:drawText(row.username, textX, textY, active.r, active.g, active.b, 1, FONT)
            self:drawText(CharacterName(row), textX, textY + FONT_HGT + 2, muted.r, muted.g, muted.b, 1, FONT)

            for _, button in ipairs(self:getRowButtons(row, rowY)) do
                local hovered = isMouseOver and mouseX >= button.x and mouseX < button.x + button.width
                    and mouseY >= button.y and mouseY < button.y + button.height
                local color = button.color
                self:drawRect(button.x, button.y, button.width, button.height, hovered and 0.35 or 0.18,
                    color.r, color.g, color.b)
                self:drawRectBorder(button.x, button.y, button.width, button.height, 0.8, color.r, color.g, color.b)
                self:drawTextCentre(button.text, button.x + button.width / 2, button.y + (button.height - FONT_HGT) / 2,
                    active.r, active.g, active.b, 1, FONT)
            end
        end
    end
    self:clearStencilRect()
end

function AvatarList:onMouseDown(x, y)
    local rows = self.window:getRows()
    local index = math.floor(y / ROW_HGT) + 1
    local row = rows[index]
    if row then
        for _, button in ipairs(self:getRowButtons(row, (index - 1) * ROW_HGT)) do
            if x >= button.x and x < button.x + button.width and y >= button.y and y < button.y + button.height then
                self.window:onRowAction(row, button.action)
                break
            end
        end
    end
    return true
end

function AvatarList:onMouseWheel(del)
    self:setYScroll(self:getYScroll() - del * ROW_HGT / 2)
    return true
end

function AvatarList:new(x, y, width, height, window)
    local o = ISPanel.new(self, x, y, width, height)
    o.window = window
    o.background = false
    return o
end

-- window ---------------------------------------------------------------------------------

function AvatarValidationWindow:getRows()
    if self.tab == TAB_PENDING then
        local pending = AvatarManager:getAvatarsPending()
        return pending
    end
    return AvatarManager:getApprovedAvatarList() or {}
end

function AvatarValidationWindow:getEmptyText()
    if self.tab == TAB_PENDING then
        return getText('UI_TICS_AvatarAdmin_no_pending')
    elseif AvatarManager:getApprovedAvatarList() == nil then
        return getText('UI_TICS_AvatarAdmin_loading')
    end
    return getText('UI_TICS_AvatarAdmin_no_approved')
end

-- pending rows come with their texture, approved ones are asked to the server once
function AvatarValidationWindow:getRowTexture(row)
    if self.tab == TAB_PENDING then
        return row.texture
    end
    local texture = AvatarManager:getAvatar(row.username, row.firstName, row.lastName)
    if texture == nil then
        local key = AvatarIO.createFileName(row.username, row.firstName, row.lastName)
        if not self.requestedImages[key] then
            self.requestedImages[key] = true
            ClientSend.sendAskApprovedAvatarImage(row.username, row.firstName, row.lastName)
        end
    end
    return texture
end

function AvatarValidationWindow:onDeleteConfirmed(button, row)
    if button.internal ~= 'YES' then
        return
    end
    ClientSend.sendAdminDeleteAvatar(row.username, row.firstName, row.lastName)
end

function AvatarValidationWindow:onRowAction(row, action)
    if action == 'approve' then
        print('TICS info: avatar approved: ' .. row.username .. ' "' .. CharacterName(row) .. '" (' .. row.checksum .. ')')
        ClientSend.sendApprovePendingAvatar(row.username, row.firstName, row.lastName, row.checksum)
        AvatarManager:removeAvatarPending(row.username, row.firstName, row.lastName, row.checksum)
        self.nextListRefresh = 0 -- the approved list changed
    elseif action == 'reject' then
        print('TICS info: avatar rejected: ' .. row.username .. ' "' .. CharacterName(row) .. '" (' .. row.checksum .. ')')
        ClientSend.sendRejectPendingAvatar(row.username, row.firstName, row.lastName, row.checksum)
        AvatarManager:removeAvatarPending(row.username, row.firstName, row.lastName, row.checksum)
    elseif action == 'delete' then
        local text = getText('UI_TICS_AvatarAdmin_delete_confirm', row.username, CharacterName(row))
        local dialog = ISModalDialog:new(0, 0, 300, 120, text, true, self,
            AvatarValidationWindow.onDeleteConfirmed, nil, row)
        dialog:initialise()
        dialog:addToUIManager()
        dialog:setAlwaysOnTop(true)
    end
end

function AvatarValidationWindow:getTabs()
    local pendingCount = #AvatarManager:getAvatarsPending()
    local approved = AvatarManager:getApprovedAvatarList()
    local approvedCount = approved and #approved or 0
    local tabs = {
        { id = TAB_PENDING, text = getText('UI_TICS_AvatarAdmin_pending', pendingCount) },
        { id = TAB_APPROVED, text = getText('UI_TICS_AvatarAdmin_approved', approvedCount) },
    }
    local x = PADDING
    for _, tab in ipairs(tabs) do
        tab.x = x
        tab.width = getTextManager():MeasureStringX(FONT, tab.text) + 24
        x = x + tab.width + 2
    end
    return tabs
end

function AvatarValidationWindow:setTab(tab)
    if self.tab == tab then
        return
    end
    self.tab = tab
    self.list:setYScroll(0)
    if tab == TAB_APPROVED then
        self.nextListRefresh = 0
    end
end

function AvatarValidationWindow:onMouseDown(x, y)
    if y >= TITLE_HGT and y < TITLE_HGT + TAB_HGT then
        for _, tab in ipairs(self:getTabs()) do
            if x >= tab.x and x < tab.x + tab.width then
                self:setTab(tab.id)
                return true
            end
        end
    end
    return ISPanel.onMouseDown(self, x, y)
end

function AvatarValidationWindow:update()
    ISPanel.update(self)
    -- the approved list (and the tab counter) is kept up to date while the window is open;
    -- the server handles the requests of a client in order, so a request sent right after an
    -- approval gets the updated list
    if getTimestampMs() >= self.nextListRefresh then
        self.nextListRefresh = getTimestampMs() + LIST_REFRESH_MS
        ClientSend.sendAskApprovedAvatarList()
    end
end

function AvatarValidationWindow:prerender()
    local body = ChatTheme.body
    local titleBar = ChatTheme.titleBar
    local border = ChatTheme.separator
    local active = ChatTheme.textActive
    local muted = ChatTheme.textMuted
    self:drawRect(0, 0, self.width, self.height, 0.95, body.r, body.g, body.b)
    self:drawRect(0, 0, self.width, TITLE_HGT, 1, titleBar.r, titleBar.g, titleBar.b)
    self:drawRect(0, TITLE_HGT - 1, self.width, 1, 1, border.r, border.g, border.b)
    self:drawRectBorder(0, 0, self.width, self.height, 1, border.r, border.g, border.b)
    self:drawText(getText('UI_TICS_AvatarAdmin_title'), PADDING, (TITLE_HGT - FONT_HGT) / 2,
        active.r, active.g, active.b, 1, FONT)

    -- tabs, the active one underlined like the chat tabs
    local strip = ChatTheme.tabStrip
    self:drawRect(0, TITLE_HGT, self.width, TAB_HGT, 1, strip.r, strip.g, strip.b)
    self:drawRect(0, TITLE_HGT + TAB_HGT - 1, self.width, 1, 1, border.r, border.g, border.b)
    for _, tab in ipairs(self:getTabs()) do
        local isActive = tab.id == self.tab
        local color = isActive and active or muted
        self:drawTextCentre(tab.text, tab.x + tab.width / 2, TITLE_HGT + (TAB_HGT - FONT_HGT) / 2,
            color.r, color.g, color.b, 1, FONT)
        if isActive then
            local accent = ChatTheme.accent
            self:drawRect(tab.x, TITLE_HGT + TAB_HGT - 2, tab.width, 2, 1, accent.r, accent.g, accent.b)
        end
    end
end

function AvatarValidationWindow:createChildren()
    self.list = AvatarList:new(PADDING, TITLE_HGT + TAB_HGT + PADDING, LIST_WIDTH, LIST_HGT, self)
    self.list:initialise()
    self.list:instantiate()
    self:addChild(self.list)
    self.list:addScrollBars()

    local text = getText('UI_Close')
    local width = getTextManager():MeasureStringX(FONT, text) + 20
    local close = ISButton:new(self.width - PADDING - width, self.height - PADDING - BUTTON_HGT, width, BUTTON_HGT,
        text, self, AvatarValidationWindow.unsubscribe)
    close:initialise()
    close:instantiate()
    close.borderColor = { r = 1, g = 1, b = 1, a = 0.15 }
    close.backgroundColor = { r = 0.25, g = 0.25, b = 0.25, a = 0.8 }
    self:addChild(close)
end

function AvatarValidationWindow:subscribe()
    self:initialise()
    self:addToUIManager()
    self:setVisible(true)
    self:bringToTop()
end

function AvatarValidationWindow:unsubscribe()
    self:setVisible(false)
    self:removeFromUIManager()
end

function AvatarValidationWindow:new()
    local x = getCore():getScreenWidth() / 2 - WIDTH / 2
    local y = getCore():getScreenHeight() / 2 - HEIGHT / 2
    local o = ISPanel.new(self, x, y, WIDTH, HEIGHT)
    o.moveWithMouse = true
    o.background = false
    o.tab = TAB_PENDING
    o.requestedImages = {}
    o.nextListRefresh = 0
    return o
end

return AvatarValidationWindow
