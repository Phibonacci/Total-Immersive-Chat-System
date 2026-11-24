-- Base of the popups opened from the chat window (language list, settings panel):
-- drawn in the chat style, on top of everything, closed by a click outside or Escape.
-- A click on the element that opened the popup (its `owner`) does not close it, so the
-- owner can toggle it.

require 'ISUI/ISPanel'

local ChatTheme = require('tics/client/ui/ChatTheme')

local ChatPopup = ISPanel:derive('TicsChatPopup')

local openPopups = {}
local lastCloseMs = 0

function ChatPopup:show()
    self:addToUIManager()
    self:setAlwaysOnTop(true)
    self:bringToTop()
    openPopups[self] = true
end

function ChatPopup:close()
    if not openPopups[self] then
        return
    end
    openPopups[self] = nil
    lastCloseMs = getTimestampMs()
    self:removeFromUIManager()
    if self.onClose then
        self.onClose(self)
    end
end

function ChatPopup:isOpen()
    return openPopups[self] == true
end

-- Closes every open popup, returns true if there was one.
function ChatPopup.closeAll()
    local closed = false
    for popup in pairs(openPopups) do
        popup:close()
        closed = true
    end
    return closed
end

-- true when a popup was closed during the current key press or click (Escape is seen
-- both by the chat input and by the OnKeyPressed event, in an unknown order)
function ChatPopup.closedRecently()
    return getTimestampMs() - lastCloseMs < 150
end

-- clicking a popup takes the keyboard focus from the chat input: give it back while typing
function ChatPopup.restoreChatFocus()
    local chat = ISChat.instance
    if ISChat.focused and chat and chat.textEntry then
        chat.textEntry:focus()
    end
end

-- Position above `anchorY` (screen y of the top of what opened the popup), right edge on
-- `anchorRight`; below `belowY` when there is no room above. Kept on the screen.
function ChatPopup:placeAbove(anchorRight, anchorY, belowY)
    local gap = ChatTheme.popupGap
    local x = anchorRight - self.width
    local y = anchorY - gap - self.height
    if y < 0 and belowY then
        y = belowY + gap
    end
    x = math.max(0, math.min(x, getCore():getScreenWidth() - self.width))
    y = math.max(0, math.min(y, getCore():getScreenHeight() - self.height))
    self:setX(x)
    self:setY(y)
end

function ChatPopup:isOverOwner()
    return self.owner ~= nil and self.owner:isVisible() and self.owner:isMouseOver()
end

function ChatPopup:onMouseDownOutside(x, y)
    if not self:isOverOwner() then
        self:close()
    end
end

function ChatPopup:onRightMouseDownOutside(x, y)
    if not self:isOverOwner() then
        self:close()
    end
end

function ChatPopup:onMouseDown(x, y)
    return true
end

function ChatPopup:onRightMouseDown(x, y)
    return true
end

function ChatPopup:prerender()
    local body = ChatTheme.body
    local border = ChatTheme.inputBorder
    self:drawRect(0, 0, self.width, self.height, ChatTheme.popupOpacity, body.r, body.g, body.b)
    self:drawRectBorder(0, 0, self.width, self.height, 1, border.r, border.g, border.b)
end

function ChatPopup:new(x, y, width, height, owner)
    local o = ISPanel.new(self, x, y, width, height)
    o.owner = owner
    o.background = false
    o.moveWithMouse = false
    return o
end

Events.OnKeyPressed.Add(function(key)
    if key == Keyboard.KEY_ESCAPE then
        ChatPopup.closeAll()
    end
end)

return ChatPopup
