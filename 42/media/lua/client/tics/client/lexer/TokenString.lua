local TokenString = {}

function TokenString:new(message)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.message = message
    return o
end

function TokenString.getName()
    return 'string'
end

function TokenString:getLength()
    return #self.message
end

-- wrapWords: words longer than that are cut with '- ' (nil: kept whole, the bubbles break long
-- words themselves where the line ends, ISTicsRichTextPanel). lengthLeft: the text is cut after
-- that many characters (the bubble writing its message), nil for the whole text.
function TokenString:formatCustom(wrapWords, _, _, lengthLeft)
    local newMessage = ''
    if wrapWords == nil or wrapWords <= 0 then
        newMessage = self.message
    else
        local wordSize = 0
        for i = 1, #self.message do
            local c = self.message:sub(i, i)
            if c == ' ' then
                wordSize = 0
            else
                wordSize = wordSize + 1
            end
            if wordSize == wrapWords + 1 then
                wordSize = 2
                local lastC = newMessage:sub(#newMessage, #newMessage)
                newMessage = newMessage:sub(1, #newMessage - 1) .. '- ' .. lastC
            end
            newMessage = newMessage .. c
        end
    end
    if lengthLeft ~= nil then
        if lengthLeft - #newMessage < 0 then
            newMessage = newMessage:sub(1, lengthLeft)
            newMessage = newMessage .. '...'
        end
        lengthLeft = lengthLeft - #newMessage
    end
    return newMessage, newMessage, lengthLeft
end

function TokenString:formatBubble(keepTags)
    return self:formatCustom()
end

function TokenString:format()
    return self:formatCustom()
end

return TokenString
