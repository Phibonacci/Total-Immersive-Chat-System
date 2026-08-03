local ISTicsRichTextPanel = require('tics/client/ui/ISTicsRichTextPanel')

local ChatText = ISTicsRichTextPanel:derive("ChatText")

-- from ISRichTextPanel:render
function ChatText:render()
    local drawLineBackground = false
    self.r = 1
    self.g = 1
    self.b = 1

    if self.lines == nil then
        return
    end

    if self.keybinds then
        for binding, text in pairs(self.keybinds) do
            if getKeyName(getCore():getKey(binding)) ~= text then
                self.textDirty = true
                break
            end
        end
    end

    if self.clip then self:setStencilRect(0, 0, self.width, self.height) end
    if self.textDirty then
        self:paginate()
    end
    --ISPanel.render(self)
    for c, v in ipairs(self.images) do
        self:drawTextureScaled(v, self.imageX[c] + self.marginLeft, self.imageY[c] + self.marginTop, self.imageW[c],
            self.imageH[c], self.contentTransparency, 1, 1, 1)
    end
    self.font = self.defaultFont
    local orient = "left"
    local c = 1
    if self.lines[self.firstPrintableLine] ~= nil then
        c = self.firstPrintableLine
        if self.firstPrintableLineColor then
            self.r = self.firstPrintableLineColor.r
            self.g = self.firstPrintableLineColor.g
            self.b = self.firstPrintableLineColor.b
        end
        if self.firstPrintableLineOrient then
            orient = self.firstPrintableLineOrient
        end
    else
        self.firstPrintableLine = 1
    end
    local previousLineY = nil
    local printableLineFound = false
    while c <= #self.lines do
        local v = self.lines[c]

        if self.lineY[c] + self.marginTop + self:getYScroll() >= self:getHeight() then
            if not self.textHasReachedBottomOnce then
                self.textHasReachedBottomOnce = true
                self:scrollToBottom()
            end
            break
        end
        if self.rgb[c] then
            self.r = self.rgb[c].r
            self.g = self.rgb[c].g
            self.b = self.rgb[c].b
        end

        if self.orient[c] then
            orient = self.orient[c]
        end

        if self.fonts[c] then
            self.font = self.fonts[c]
        end

        if self.marginTop + self:getYScroll() + self.lineY[c] + getTextManager():getFontHeight(self.font) + self:getHeight() * 2 > 0 then
            if not printableLineFound then
                printableLineFound = true
                self.firstPrintableLine = c
                self.firstPrintableLineColor = {
                    r = self.r,
                    g = self.g,
                    b = self.b,
                }
                self.firstPrintableLineOrient = orient
            end
        end

        if self.marginTop + self:getYScroll() + self.lineY[c] + getTextManager():getFontHeight(self.font) > 0 then
            local r = self.r
            local b = self.b
            local g = self.g

            if v:contains("&lt") then
                v = v:gsub("&lt", "<")
            end
            if v:contains("&gt") then
                v = v:gsub("&gt", ">")
            end

            if string.trim(v) ~= "" then
                if orient == "centre" then
                    local lineY = self.lineY[c]
                    local lineLength = 0
                    local c2 = c
                    while (c2 <= #self.lines) and (self.lineY[c2] == lineY) do
                        local font = self.fonts[c2] or self.font
                        lineLength = lineLength + getTextManager():MeasureStringX(font, string.trim(self.lines[c2]))
                        c2 = c2 + 1
                    end
                    local lineX = self.marginLeft + (self.width - self.marginLeft - self.marginRight - lineLength) / 2
                    while (c <= #self.lines) and (self.lineY[c] == lineY) do
                        if self.rgb[c] then
                            self.r = self.rgb[c].r
                            self.g = self.rgb[c].g
                            self.b = self.rgb[c].b
                        end
                        local r = self.r
                        local b = self.b
                        local g = self.g
                        if self.orient[c] then
                            orient = self.orient[c]
                        end
                        if self.fonts[c] then
                            self.font = self.fonts[c]
                        end
                        self:drawText(string.trim(self.lines[c]), lineX + self.lineX[c], self.lineY[c] + self.marginTop,
                            r, g, b, self.contentTransparency, self.font)
                        --						lineX = lineX + getTextManager():MeasureStringX(self.font, self.lines[c])
                        c = c + 1
                    end
                    c = c - 1
                elseif orient == "right" then
                    self:drawTextRight(string.trim(v), self.lineX[c] + self.marginLeft, self.lineY[c] + self.marginTop, r,
                        g, b, self.contentTransparency, self.font)
                else
                    local lineHeight = getTextManager():getFontHeight(self.font)
                    if self.lineY[c] ~= previousLineY then
                        previousLineY = self.lineY[c]
                        if drawLineBackground then
                            self:drawRect(
                                0,
                                self.lineY[c] + 3,
                                self.width + self.marginLeft + self.marginRight,
                                lineHeight,
                                0.05, 0.5, 0.5, 0.5)
                        end
                        drawLineBackground = not drawLineBackground
                    end
                    self:drawText(string.trim(v), self.lineX[c] + self.marginLeft, self.lineY[c] + self.marginTop, r, g,
                        b, self.contentTransparency, self.font)
                end
            end
        else
            self.textHasReachedBottomOnce = true -- text was scrolled already
        end
        c = c + 1
    end

    if ISRichTextPanel.drawMargins then
        self:drawRectBorder(0, 0, self.width, self:getScrollHeight(), 0.5, 1, 1, 1)
        self:drawRect(self.marginLeft, 0, 1, self:getScrollHeight(), 1, 1, 1, 1)
        local maxLineWidth = self.maxLineWidth or (self.width - self.marginRight - self.marginLeft)
        --		self:drawRect(self.marginLeft + maxLineWidth, 0, 1, self:getScrollHeight(), 1,1,1,1)
        self:drawRect(self.width - self.marginRight, 0, 1, self:getScrollHeight(), 1, 1, 1, 1)
        self:drawRect(0, self.marginTop, self.width, 1, 1, 1, 1, 1)
        self:drawRect(0, self:getScrollHeight() - self.marginBottom, self.width, 1, 1, 1, 1, 1)
    end

    if self.clip then self:clearStencilRect() end
    --self:setScrollHeight(y)
end

-- function ChatText:paginate()
--     ChatText_paginate(self)
-- end

-- function ChatText_paginate(self)
-- 	local lines = 1;
-- 	self.textDirty = false;
-- 	self.imageCount = 1;
-- 	self.font = self.defaultFont;
-- 	self.fonts = {};
-- 	self.images = {}
-- 	self.imageX = {}
-- 	self.imageY = {}
-- 	self.rgb = {};
-- 	self.rgbCurrent = { r = 1, g = 1, b = 1 }
-- 	self.rgbStack = {}
-- 	self.orient = {}
-- 	self.indent = 0

-- 	self.imageW = {}
-- 	self.imageH = {}

-- 	self.lineY = {}
-- 	self.lineX = {}
-- 	self.lines = {}

-- 	self.keybinds = {}

--     self.videoCount = 1;
-- 	self.videos = {}
-- 	self.videoX = {}
--     self.videoY = {}
--     self.videoW = {}
--     self.videoH = {}

-- 	local bDone = false;
-- 	local leftText = self:replaceKeyNames(self.text) .. ' ';
-- 	local cur = 0;
-- 	local y = 0;
-- 	local x = 0;
-- 	local lineImageHeight = 0;
-- 	leftText = leftText:gsub("\n", " <LINE> ")
-- 	if self.maxLines > 0 then
-- 		local lines = leftText:split("<LINE>")
-- 		for i=1,(#lines - self.maxLines) do
-- 			table.remove(lines,1)
-- 		end
-- 		leftText = ' '
-- 		for k,v in ipairs(lines) do
-- 			leftText = leftText..v.." <LINE> "
-- 		end
-- 	end
-- 	local maxLineWidth = self.maxLineWidth or (self.width - self.marginRight - self.marginLeft)
-- 	-- Always go through at least once.
-- 	while not bDone do
--         local openingBracket = string.find(leftText, "<", cur+2)
-- 		cur = string.find(leftText, " ", cur+1);
--         if cur == nil and openingBracket ~= nil or (openingBracket and openingBracket < cur) then
--             cur = openingBracket - 1
--         end
-- 		if cur ~= nil then
-- 			local token = string.sub(leftText, 0, cur);
--             local leftTokenBracket = string.find(token, "<")
--             local rightTokenBracket = string.find(token, ">")
-- 			if leftTokenBracket and rightTokenBracket then -- handle missing ' ' after '>'
-- 				cur = rightTokenBracket + 1;
-- 				token = string.sub(leftText, 0, cur - 1);
-- 			end
-- 			leftText = string.sub(leftText, cur);
-- 			cur = 1
-- 			if string.find(token, "<") and string.find(token, ">") then
-- 				if not self.lines[lines] then
-- 					self.lines[lines] = ''
-- 					self.lineX[lines] = x
-- 					self.lineY[lines] = y
-- 				end
-- 				lines = lines + 1
-- 				local st = string.find(token, "<");
-- 				local en = string.find(token, ">");
-- 				local escSeq = string.sub(token, st+1, en-1);
-- 				local lineHeight = getTextManager():getFontFromEnum(self.font):getLineHeight();
-- 				if lineHeight < 10 then
-- 					lineHeight = 10;
-- 				end
-- 				if lineHeight < lineImageHeight then
-- 					lineHeight = lineImageHeight;
-- 				end
-- 				self.currentLine = lines;
-- 				x, y, lineImageHeight = self:processCommand(escSeq, x, y, lineImageHeight, lineHeight);
-- 			else
-- 				if token:contains("&lt;") then
-- 					token = token:gsub("&lt;", "<")
-- 				end
-- 				if token:contains("&gt;") then
-- 					token = token:gsub("&gt;", ">")
-- 				end
-- 				local chunkText = self.lines[lines] or ''
-- 				local chunkX = self.lineX[lines] or x
-- 				if chunkText == '' then
-- 					chunkText = ' ' .. string.trim(token)
-- 				elseif string.trim(token) ~= '' then
-- 					chunkText = chunkText .. ' ' .. string.trim(token)
-- 				end
-- 				local pixLen = getTextManager():MeasureStringX(self.font, chunkText);
-- 				if chunkX + pixLen > maxLineWidth then
-- 					if self.lines[lines] and self.lines[lines] ~= '' then
-- 						lines = lines + 1;
-- 					end
-- 					local lineHeight = getTextManager():getFontFromEnum(self.font):getLineHeight();
-- 					if lineHeight < lineImageHeight then
-- 						lineHeight = lineImageHeight;
-- 					end
-- 					lineImageHeight = 0;
-- 					y = y + lineHeight;
-- 					x = 0;
-- 					self.lines[lines] = string.trim(token)
-- 					if self.lines[lines] ~= "" then
-- 						x = self.indent
-- 					end
-- 					self.lineX[lines] = x
-- 					self.lineY[lines] = y
-- 					x = x + getTextManager():MeasureStringX(self.font, self.lines[lines])
-- 				else
-- 					if not self.lines[lines] then
-- 						self.lines[lines] = ''
-- 						self.lineX[lines] = x
-- 						self.lineY[lines] = y
-- 					end
-- 					self.lines[lines] = chunkText
-- 					if self.lineX[lines] == 0 and self.lines[lines] ~= "" then
-- 						self.lineX[lines] = self.indent
-- 					end
-- 					x = self.lineX[lines] + pixLen
-- 				end
-- 			end
-- 		else
-- 			if string.trim(leftText) ~= '' then
-- 				local str = leftText
-- 				if str:contains("&lt;") then
-- 					str = str:gsub("&lt;", "<")
-- 				end
-- 				if str:contains("&gt;") then
-- 					str = str:gsub("&gt;", ">")
-- 				end
-- 				self.lines[lines] = string.trim(str);
-- 				if x == 0 and self.lines[lines] ~= "" then
-- 					x = self.indent
-- 				end
-- 				self.lineX[lines] = x;
-- 				self.lineY[lines] = y;
-- 				local lineHeight = getTextManager():getFontFromEnum(self.font):getLineHeight();
-- 				y = y + lineHeight
-- 			elseif self.lines[lines] and self.lines[lines] ~= '' then
-- 				local lineHeight = getTextManager():getFontFromEnum(self.font):getLineHeight();
-- 				if lineHeight < lineImageHeight then
-- 					lineHeight = lineImageHeight;
-- 				end
-- 				y = y + lineHeight
-- 			end
-- 			bDone = true;
-- 		end
-- 	end

-- 	if self.autosetheight then
-- 		self:setHeight(self.marginTop + y + self.marginBottom);
-- 	end

-- 	self:setScrollHeight(self.marginTop + y + self.marginBottom);
-- end

function ChatText:setYScroll(y)
    self.firstPrintableLine = 1
    ISRichTextPanel.setYScroll(self, y)
end

function ChatText:updateScroll(value)
    self:setYScroll(self:getYScroll() - (value * 18))
    return true
end

function ChatText:scrollToTop()
    self:setYScroll(0)
    return true
end

function ChatText:scrollToBottom()
    self:setYScroll(-(self:getScrollHeight() - self:getScrollAreaHeight()))
    return true
end

function ChatText:onMouseMove(dx, dy)
    ISRichTextPanel.onMouseMove(self, dx, dy)
    self._isFocused = true
end

function ChatText:onMouseMoveOutside(dx, dy)
    ISRichTextPanel.onMouseMoveOutside(self, dx, dy)
    self._isFocused = false
end

local VK_PRIOR = 201 -- PAGE UP key
local VK_NEXT  = 209 -- PAGE DOWN key
local VK_HOME  = 199 -- HOME key
local VK_END   = 207 -- END key

function ChatText:onKey(key)
    if self._isFocused then
        if key == VK_PRIOR then
            self:updateScroll(-1)
        elseif key == VK_NEXT then
            self:updateScroll(1)
        elseif key == VK_HOME then
            self:scrollToTop()
        elseif key == VK_END then
            self:scrollToBottom()
        end
    end
end

function ChatText:new(x, y, width, height)
    -- setmetatable(self, { __index = ISRichTextPanel })
    local o = ISTicsRichTextPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    local lambda = function(key)
        o:onKey(key)
    end
    o._isFocused = false
    Events.OnKeyStartPressed.Add(lambda)
    Events.OnKeyKeepPressed.Add(lambda)
    return o
end

return ChatText
