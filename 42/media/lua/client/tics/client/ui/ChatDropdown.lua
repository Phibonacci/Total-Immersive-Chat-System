-- List of choices opened from a button of the chat (the language label of the input box),
-- above the button with the right edges aligned. Each item: { label, value, detail, checked, color }
-- (`detail` is drawn on the right in a muted color, `checked` shows a tick, `color` is the
-- color of the label, when the label is not hovered).
-- Closes on a choice, on Escape or on a click outside.

local ChatTheme = require('tics/client/ui/ChatTheme')
local ChatPopup = require('tics/client/ui/ChatPopup')

local ChatDropdown = ChatPopup:derive('TicsChatDropdown')

local FONT = UIFont.Small
local PADDING_Y = 4
local PADDING_LEFT = 8
local PADDING_RIGHT = 10
local CHECK_WIDTH = 18
local CHECK_SIZE = 12
local DETAIL_GAP = 16

function ChatDropdown:getRowAt(y)
    local index = math.floor((y - PADDING_Y) / self.rowHeight) + 1
    if index >= 1 and index <= #self.items then
        return index
    end
    return nil
end

function ChatDropdown:render()
    local hovered = self:isMouseOver() and self:getRowAt(self:getMouseY()) or nil
    local check = getTexture(ChatTheme.icons.check)
    for index, item in ipairs(self.items) do
        local y = PADDING_Y + (index - 1) * self.rowHeight
        if index == hovered then
            local hover = ChatTheme.rowHover
            self:drawRect(1, y, self.width - 2, self.rowHeight, 1, hover.r, hover.g, hover.b)
        end
        if item.checked and check then
            local accent = ChatTheme.accent
            self:drawTextureScaled(check, PADDING_LEFT + (CHECK_WIDTH - CHECK_SIZE) / 2 - 2,
                y + (self.rowHeight - CHECK_SIZE) / 2, CHECK_SIZE, CHECK_SIZE, 1, accent.r, accent.g, accent.b)
        end
        local textY = y + (self.rowHeight - self.fontHeight) / 2
        local color = index == hovered and ChatTheme.textActive or (item.color or ChatTheme.textHover)
        self:drawText(item.label, PADDING_LEFT + CHECK_WIDTH, textY, color.r, color.g, color.b, 1, FONT)
        if item.detail then
            local muted = ChatTheme.textMuted
            self:drawTextRight(item.detail, self.width - PADDING_RIGHT, textY, muted.r, muted.g, muted.b, 1, FONT)
        end
    end
end

function ChatDropdown:onMouseUp(x, y)
    local index = self:getRowAt(y)
    if index then
        local item = self.items[index]
        self:close()
        self.onSelect(item.value)
        ChatPopup.restoreChatFocus()
    end
    return true
end

function ChatDropdown:new(items, owner, onSelect)
    local textManager = getTextManager()
    local fontHeight = textManager:getFontHeight(FONT)
    local labelWidth, detailWidth = 0, 0
    for _, item in ipairs(items) do
        labelWidth = math.max(labelWidth, textManager:MeasureStringX(FONT, item.label))
        if item.detail then
            detailWidth = math.max(detailWidth, textManager:MeasureStringX(FONT, item.detail))
        end
    end
    local rowHeight = fontHeight + 8
    local width = PADDING_LEFT + CHECK_WIDTH + labelWidth + PADDING_RIGHT
    if detailWidth > 0 then
        width = width + DETAIL_GAP + detailWidth
    end
    width = math.max(width, owner:getWidth())
    local height = PADDING_Y * 2 + rowHeight * #items

    local o = ChatPopup.new(self, 0, 0, width, height, owner)
    o.items = items
    o.onSelect = onSelect
    o.fontHeight = fontHeight
    o.rowHeight = rowHeight
    return o
end

-- Opens the list above `button` (right edges aligned, left edges with alignLeft), below it
-- when there is no room above.
function ChatDropdown.open(button, items, onSelect, alignLeft)
    local dropdown = ChatDropdown:new(items, button, onSelect)
    dropdown:initialise()
    dropdown:show()
    local top = button:getAbsoluteY()
    local right = button:getAbsoluteX() + button:getWidth()
    if alignLeft then
        right = button:getAbsoluteX() + dropdown.width
    end
    dropdown:placeAbove(right, top, top + button:getHeight())
    return dropdown
end

return ChatDropdown
