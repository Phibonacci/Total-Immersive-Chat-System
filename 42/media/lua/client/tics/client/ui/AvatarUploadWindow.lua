-- Avatar window: shows the approved avatar of the current character (it can be deleted by
-- its owner without admin approval) and every image of the player's avatar folder, one of
-- them can be sent to the admins for approval.

require 'ISUI/ISPanel'
require 'ISUI/ISButton'
require 'ISUI/ISModalDialog'

local AvatarManager = require('tics/client/AvatarManager')
local ChatTheme = require('tics/client/ui/ChatTheme')
local ClientSend = require('tics/client/network/ClientSend')
local File = require('tics/shared/utils/File')


local AvatarUploadWindow = ISPanel:derive('AvatarUploadWindow')

local AVATAR_WIDTH = 60
local AVATAR_HEIGHT = 80
local FONT = UIFont.Small
local FONT_HGT = getTextManager():getFontHeight(FONT)
local PADDING = 12
local TITLE_HGT = FONT_HGT + 10
local BUTTON_HGT = FONT_HGT + 8
local CELL_PADDING = 8
local CELL_WIDTH = AVATAR_WIDTH + CELL_PADDING * 2
local CELL_HEIGHT = AVATAR_HEIGHT + FONT_HGT + CELL_PADDING * 2 + 2
local GRID_COLUMNS = 5
local GRID_ROWS = 2
local SCROLLBAR_WIDTH = 13
local WIDTH = PADDING * 2 + CELL_WIDTH * GRID_COLUMNS + SCROLLBAR_WIDTH
local CURRENT_SECTION_HGT = FONT_HGT + 6 + AVATAR_HEIGHT
local GRID_HGT = CELL_HEIGHT * GRID_ROWS
local HEIGHT = TITLE_HGT + PADDING + CURRENT_SECTION_HGT + PADDING + FONT_HGT + 6 + GRID_HGT
    + PADDING + BUTTON_HGT + PADDING

local WARNING = { r = 0.9, g = 0.45, b = 0.35 }

local function IsValidSize(texture)
    return texture ~= nil and texture:getWidth() == AVATAR_WIDTH and texture:getHeight() == AVATAR_HEIGHT
end

local function TruncateText(text, maxWidth)
    local textManager = getTextManager()
    if textManager:MeasureStringX(FONT, text) <= maxWidth then
        return text
    end
    while #text > 1 and textManager:MeasureStringX(FONT, text .. '...') > maxWidth do
        text = text:sub(1, #text - 1)
    end
    return text .. '...'
end

-- splits a text in lines fitting maxWidth, long words (like paths) are cut anywhere;
-- with maxLines the last line is truncated
local function WrapText(text, maxWidth, maxLines)
    local textManager = getTextManager()
    local function Fits(candidate)
        return textManager:MeasureStringX(FONT, candidate) <= maxWidth
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
    if maxLines and #lines > maxLines then
        local last = table.concat(lines, ' ', maxLines)
        lines = { unpack(lines, 1, maxLines - 1) }
        table.insert(lines, TruncateText(last, maxWidth))
    end
    return lines
end

local function DrawAvatarBox(panel, texture, x, y, alpha)
    local body = ChatTheme.pill
    panel:drawRect(x, y, AVATAR_WIDTH, AVATAR_HEIGHT, alpha * 0.5, body.r, body.g, body.b)
    if texture then
        panel:drawTextureScaled(texture, x, y, AVATAR_WIDTH, AVATAR_HEIGHT, alpha, 1, 1, 1)
    end
end

-- image grid -----------------------------------------------------------------------------

local AvatarGrid = ISPanel:derive('TicsAvatarGrid')

function AvatarGrid:getTexture(image)
    local texture = self.textures[image.path]
    if texture == nil then
        texture = File.getTexture(image.path)
        self.textures[image.path] = texture or false
    end
    return texture or nil
end

function AvatarGrid:setImages(images, reloadTextures)
    if reloadTextures then
        -- an image may have been replaced by another one with the same name
        for _, texture in pairs(self.textures) do
            if texture then
                Texture.reload(texture:getName())
            end
        end
    end
    self.images = images
    local rows = math.ceil(#images / GRID_COLUMNS)
    self:setScrollHeight(math.max(rows * CELL_HEIGHT, self.height))
    self:setYScroll(0)
end

function AvatarGrid:getCellPosition(index)
    local column = (index - 1) % GRID_COLUMNS
    local row = math.floor((index - 1) / GRID_COLUMNS)
    return column * CELL_WIDTH, row * CELL_HEIGHT
end

function AvatarGrid:prerender()
    local body = ChatTheme.pill
    self:drawRect(0, -self:getYScroll(), self.width, self.height, 0.25, body.r, body.g, body.b)
    local border = ChatTheme.separator
    self:drawRectBorder(0, -self:getYScroll(), self.width, self.height, 1, border.r, border.g, border.b)
end

function AvatarGrid:render()
    self:setStencilRect(0, 0, self.width, self.height)
    if #self.images == 0 then
        local text = getText('UI_TICS_Avatar_empty', AVATAR_WIDTH, AVATAR_HEIGHT)
        local muted = ChatTheme.textMuted
        local lines = WrapText(text, self.width - PADDING * 2)
        for i, textLine in ipairs(lines) do
            self:drawText(textLine, PADDING, PADDING + (i - 1) * FONT_HGT, muted.r, muted.g, muted.b, 1, FONT)
        end
    end
    local mouseIndex = self:isMouseOver() and self:getIndexAt(self:getMouseX(), self:getMouseY()) or nil
    for index, image in ipairs(self.images) do
        local x, y = self:getCellPosition(index)
        local visible = y + CELL_HEIGHT + self:getYScroll() >= 0 and y + self:getYScroll() <= self.height
        if visible then
            local texture = self:getTexture(image)
            local isSelected = self.window.selectedImage == image
            if isSelected or index == mouseIndex then
                local highlight = isSelected and 0.12 or 0.06
                self:drawRect(x + 2, y + 2, CELL_WIDTH - 4, CELL_HEIGHT - 4, highlight, 1, 1, 1)
            end
            local avatarX = x + CELL_PADDING
            local avatarY = y + CELL_PADDING
            DrawAvatarBox(self, texture, avatarX, avatarY, 1)
            local textColor = ChatTheme.textMuted
            if texture and texture:getWidth() > 0 and not IsValidSize(texture) then
                -- not usable: wrong size
                self:drawRectBorder(avatarX - 1, avatarY - 1, AVATAR_WIDTH + 2, AVATAR_HEIGHT + 2, 1,
                    WARNING.r, WARNING.g, WARNING.b)
                local sizeText = texture:getWidth() .. 'x' .. texture:getHeight()
                self:drawTextCentre(sizeText, avatarX + AVATAR_WIDTH / 2, avatarY + AVATAR_HEIGHT - FONT_HGT - 2,
                    WARNING.r, WARNING.g, WARNING.b, 1, FONT)
            end
            if isSelected then
                local accent = ChatTheme.accent
                self:drawRectBorder(avatarX - 2, avatarY - 2, AVATAR_WIDTH + 4, AVATAR_HEIGHT + 4, 1,
                    accent.r, accent.g, accent.b)
                textColor = ChatTheme.textActive
            end
            local name = TruncateText(image.fileName, CELL_WIDTH - 4)
            self:drawTextCentre(name, x + CELL_WIDTH / 2, avatarY + AVATAR_HEIGHT + 3,
                textColor.r, textColor.g, textColor.b, 1, FONT)
        end
    end
    self:clearStencilRect()
end

function AvatarGrid:getIndexAt(x, y)
    if x < 0 or x >= CELL_WIDTH * GRID_COLUMNS or y < 0 then
        return nil
    end
    local index = math.floor(y / CELL_HEIGHT) * GRID_COLUMNS + math.floor(x / CELL_WIDTH) + 1
    if index > #self.images then
        return nil
    end
    return index
end

function AvatarGrid:onMouseDown(x, y)
    local index = self:getIndexAt(x, y)
    if index then
        self.window:selectImage(self.images[index])
    end
    return true
end

function AvatarGrid:onMouseWheel(del)
    self:setYScroll(self:getYScroll() - del * CELL_HEIGHT / 2)
    return true
end

function AvatarGrid:new(x, y, width, height, window)
    local o = ISPanel.new(self, x, y, width, height)
    o.window = window
    o.images = {}
    o.textures = {}
    o.background = false
    return o
end

-- window ---------------------------------------------------------------------------------

function AvatarUploadWindow:createButton(x, y, text, onClick)
    local width = getTextManager():MeasureStringX(FONT, text) + 20
    local button = ISButton:new(x, y, width, BUTTON_HGT, text, self, onClick)
    button:initialise()
    button:instantiate()
    button.borderColor = { r = 1, g = 1, b = 1, a = 0.15 }
    button.backgroundColor = { r = 0.25, g = 0.25, b = 0.25, a = 0.8 }
    self:addChild(button)
    return button
end

function AvatarUploadWindow:createChildren()
    local currentY = TITLE_HGT + PADDING + FONT_HGT + 6
    self.deleteButton = self:createButton(PADDING + AVATAR_WIDTH + 8, currentY + AVATAR_HEIGHT - BUTTON_HGT,
        getText('UI_TICS_Avatar_delete'), AvatarUploadWindow.onDelete)
    -- second column: the request waiting for an admin, then the status messages
    self.pendingX = self.deleteButton:getRight() + PADDING * 2
    self.statusX = self.pendingX + AVATAR_WIDTH + PADDING

    local gridY = TITLE_HGT + PADDING + CURRENT_SECTION_HGT + PADDING + FONT_HGT + 6
    self.grid = AvatarGrid:new(PADDING, gridY, CELL_WIDTH * GRID_COLUMNS + SCROLLBAR_WIDTH, GRID_HGT, self)
    self.grid:initialise()
    self.grid:instantiate()
    self:addChild(self.grid)
    self.grid:addScrollBars()

    local buttonY = self.height - PADDING - BUTTON_HGT
    local openFolder = self:createButton(PADDING, buttonY, getText('UI_TICS_Avatar_open_folder'),
        AvatarUploadWindow.onOpenFolder)
    self:createButton(openFolder:getRight() + 6, buttonY, getText('UI_TICS_Avatar_refresh'),
        AvatarUploadWindow.onRefresh)
    local close = self:createButton(0, buttonY, getText('UI_Close'), AvatarUploadWindow.onClose)
    close:setX(self.width - PADDING - close:getWidth())
    self.sendButton = self:createButton(0, buttonY, getText('UI_TICS_Avatar_send'), AvatarUploadWindow.onSend)
    self.sendButton:setX(close:getX() - 6 - self.sendButton:getWidth())

    self:refresh(false)
    AvatarManager:askOwnPendingAvatar()
end

function AvatarUploadWindow:refresh(reloadTextures)
    AvatarManager:createRequestDirectory()
    local images = AvatarManager:listRequestImages()
    -- keep the selection if the image is still there
    local selectedName = self.selectedImage and self.selectedImage.fileName
    self.selectedImage = nil
    for _, image in ipairs(images) do
        if image.fileName == selectedName then
            self.selectedImage = image
        end
    end
    self.grid:setImages(images, reloadTextures)
end

function AvatarUploadWindow:selectImage(image)
    self.selectedImage = image
    self.status = nil
end

function AvatarUploadWindow:canSend()
    if self.selectedImage == nil then
        return false
    end
    return IsValidSize(self.grid:getTexture(self.selectedImage))
end

function AvatarUploadWindow:onSend()
    if not self:canSend() then
        return
    end
    local request = AvatarManager:loadRequestImage(self.selectedImage)
    if request == nil then
        self.status = { text = getText('UI_TICS_Avatar_read_error', self.selectedImage.fileName), color = WARNING }
        return
    end
    if request.checksum == self.lastSentChecksum then
        self.status = { text = getText('UI_TICS_Avatar_already_sent'), color = WARNING }
        return
    end
    ClientSend.sendAvatarRequest(request)
    self.lastSentChecksum = request.checksum
    self.status = { text = getText('UI_TICS_Avatar_sent', self.selectedImage.fileName), color = ChatTheme.textActive }
    ISChat.sendInfoToCurrentTab(getText('UI_TICS_Avatar_sent', self.selectedImage.fileName))
end

function AvatarUploadWindow:onDeleteConfirmed(button)
    if button.internal ~= 'YES' then
        return
    end
    ClientSend.sendDeleteAvatar()
    self.status = { text = getText('UI_TICS_Avatar_deleted'), color = ChatTheme.textActive }
end

function AvatarUploadWindow:onDelete()
    if AvatarManager:getCurrentAvatar() == nil then
        return
    end
    local dialog = ISModalDialog:new(0, 0, 300, 120, getText('UI_TICS_Avatar_delete_confirm'), true,
        self, AvatarUploadWindow.onDeleteConfirmed)
    dialog:initialise()
    dialog:addToUIManager()
    dialog:setAlwaysOnTop(true)
end

-- opening a folder does not work everywhere (e.g. Linux with the Steam runtime, the game
-- runs xdg-open and only logs failures), so the path is also copied and shown in the chat
function AvatarUploadWindow:onOpenFolder()
    AvatarManager:createRequestDirectory()
    local path = File.getAbsolutePath(AvatarManager:getRequestDirectory())
    showFolderInDesktop(path)
    Clipboard.setClipboard(path)
    local message = getText('UI_TICS_Avatar_path_copied', path)
    self.status = { text = message, color = ChatTheme.textActive }
    ISChat.sendInfoToCurrentTab(message)
end

function AvatarUploadWindow:onRefresh()
    self.status = nil
    self:refresh(true)
end

function AvatarUploadWindow:onClose()
    self:unsubscribe()
end

function AvatarUploadWindow:prerender()
    local body = ChatTheme.body
    local titleBar = ChatTheme.titleBar
    local border = ChatTheme.separator
    self:drawRect(0, 0, self.width, self.height, 0.95, body.r, body.g, body.b)
    self:drawRect(0, 0, self.width, TITLE_HGT, 1, titleBar.r, titleBar.g, titleBar.b)
    self:drawRect(0, TITLE_HGT - 1, self.width, 1, 1, border.r, border.g, border.b)
    self:drawRectBorder(0, 0, self.width, self.height, 1, border.r, border.g, border.b)
    local active = ChatTheme.textActive
    self:drawText(getText('UI_TICS_Avatar_title'), PADDING, (TITLE_HGT - FONT_HGT) / 2,
        active.r, active.g, active.b, 1, FONT)

    -- current avatar
    local muted = ChatTheme.textMuted
    local y = TITLE_HGT + PADDING
    self:drawText(getText('UI_TICS_Avatar_current'), PADDING, y, muted.r, muted.g, muted.b, 1, FONT)
    y = y + FONT_HGT + 6
    local current = AvatarManager:getCurrentAvatar()
    DrawAvatarBox(self, current, PADDING, y, 1)
    if current == nil then
        self:drawTextCentre(getText('UI_TICS_Avatar_none'), PADDING + AVATAR_WIDTH / 2,
            y + (AVATAR_HEIGHT - FONT_HGT) / 2, muted.r, muted.g, muted.b, 1, FONT)
    end
    self.deleteButton:setEnable(current ~= nil)

    -- request waiting for an admin
    self:drawText(getText('UI_TICS_Avatar_pending'), self.pendingX, y - FONT_HGT - 6,
        muted.r, muted.g, muted.b, 1, FONT)
    local pending = AvatarManager:getOwnPendingAvatar()
    DrawAvatarBox(self, pending, self.pendingX, y, 1)
    if pending == nil then
        self:drawTextCentre(getText('UI_TICS_Avatar_none'), self.pendingX + AVATAR_WIDTH / 2,
            y + (AVATAR_HEIGHT - FONT_HGT) / 2, muted.r, muted.g, muted.b, 1, FONT)
    end

    if self.status then
        local color = self.status.color
        local maxLines = math.floor(AVATAR_HEIGHT / FONT_HGT)
        local lines = WrapText(self.status.text, self.width - self.statusX - PADDING, maxLines)
        for i, line in ipairs(lines) do
            self:drawText(line, self.statusX, y + (i - 1) * FONT_HGT, color.r, color.g, color.b, 1, FONT)
        end
    end

    -- images of the folder
    y = TITLE_HGT + PADDING + CURRENT_SECTION_HGT + PADDING
    local imagesLabel = getText('UI_TICS_Avatar_images')
    self:drawText(imagesLabel, PADDING, y, muted.r, muted.g, muted.b, 1, FONT)
    -- on the right: the format the images must have, a warning when the selected one has not
    local selected = self.selectedImage
    local texture = selected and self.grid:getTexture(selected) or nil
    local text, color
    if selected and texture and texture:getWidth() > 0 and not IsValidSize(texture) then
        text, color = getText('UI_TICS_Avatar_wrong_size', AVATAR_WIDTH, AVATAR_HEIGHT), WARNING
    else
        text, color = getText('UI_TICS_Avatar_format', AVATAR_WIDTH, AVATAR_HEIGHT), muted
    end
    local maxWidth = self.width - PADDING * 3 - getTextManager():MeasureStringX(FONT, imagesLabel)
    text = TruncateText(text, maxWidth)
    local width = getTextManager():MeasureStringX(FONT, text)
    self:drawText(text, self.width - PADDING - width, y, color.r, color.g, color.b, 1, FONT)
    self.sendButton:setEnable(self:canSend())
end

function AvatarUploadWindow:subscribe()
    self:initialise()
    self:addToUIManager()
    self:setVisible(true)
    self:bringToTop()
end

function AvatarUploadWindow:unsubscribe()
    self:setVisible(false)
    self:removeFromUIManager()
end

function AvatarUploadWindow:new()
    local x = getCore():getScreenWidth() / 2 - WIDTH / 2
    local y = getCore():getScreenHeight() / 2 - HEIGHT / 2
    local o = ISPanel.new(self, x, y, WIDTH, HEIGHT)
    o.moveWithMouse = true
    o.background = false
    o.selectedImage = nil
    o.status = nil
    o.lastSentChecksum = nil
    return o
end

return AvatarUploadWindow
