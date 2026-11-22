local ISTicsRichTextPanel = ISRichTextPanel:derive("ISTicsRichTextPanel");

-- Width a chunk takes on its line. MeasureStringX counts the last character's glyph width
-- instead of its advance, a chunk ending with a narrow glyph ("1", "l"...) is then measured
-- too short and the next colored chunk is drawn against it. With a trailing space (no glyph)
-- every character of the text counts its full advance.
local function ChunkWidth(font, text)
	return getTextManager():MeasureStringX(font, text .. ' ')
end

function ISTicsRichTextPanel:paginate()
	local lines = 1;
	self.textDirty = false;
	self.imageCount = 1;
	self.font = self.defaultFont;
	self.fonts = {};
	self.images = {}
	self.imageX = {}
	self.imageY = {}
	self.rgb = {};
	self.rgbCurrent = { r = 1, g = 1, b = 1 }
	self.rgbStack = {}
	self.orient = {}
	self.indent = 0

	self.imageW = {}
	self.imageH = {}

	self.lineY = {}
	self.lineX = {}
	self.lines = {}
	-- index of the message (separated by <LINE>) each line belongs to
	self.lineMessage = {}
	local messageIndex = 1
	-- <TICSCOL:x> (chat): the rest of the message starts at x, its wrapped lines too
	self.currentWrapIndent = nil
	-- <TICSCHIP> (chat): the next text chunk is a label drawn on a box (ChatText), padding
	-- is reserved around it
	self.lineChip = {}
	local pendingChip = false
	local chipPadding = self.chipPadding or 4
	local chipFont = self.chipFont -- the label text is drawn smaller (ChatText)

	self.keybinds = {}

    self.videoCount = 1;
	self.videos = {}
	self.videoX = {}
    self.videoY = {}
    self.videoW = {}
    self.videoH = {}

	local bDone = false;
	local leftText = self:replaceKeyNames(self.text) .. ' ';
	local cur = 0;
	local y = 0;
	local x = 0;
	local lineImageHeight = 0;
	leftText = leftText:gsub("\n", " <LINE> ")
	if self.maxLines > 0 then
		local lines = leftText:split("<LINE>")
		for i=1,(#lines - self.maxLines) do
			table.remove(lines,1)
		end
		leftText = ' '
		for k,v in ipairs(lines) do
			leftText = leftText..v.." <LINE> "
		end
	end
	local maxLineWidth = self.maxLineWidth or (self.width - self.marginRight - self.marginLeft)
	-- Always go through at least once.
	while not bDone do
        local openingBracket = string.find(leftText, "<", cur+2)
		cur = string.find(leftText, " ", cur+1);
        if cur == nil and openingBracket ~= nil or (openingBracket and openingBracket < cur) then
            cur = openingBracket - 1
        end
		if cur ~= nil then
			local token = string.sub(leftText, 0, cur);
            local leftTokenBracket = string.find(token, "<")
            local rightTokenBracket = string.find(token, ">")
			if leftTokenBracket and rightTokenBracket then -- handle missing ' ' after '>'
				cur = rightTokenBracket + 1;
				token = string.sub(leftText, 0, cur - 1);
			end
			leftText = string.sub(leftText, cur);
			cur = 1
			if string.find(token, "<") and string.find(token, ">") then
				if not self.lines[lines] then
					self.lines[lines] = ''
					self.lineX[lines] = x
					self.lineY[lines] = y
					self.lineMessage[lines] = messageIndex
				end
				lines = lines + 1
				local st = string.find(token, "<");
				local en = string.find(token, ">");
				local escSeq = string.sub(token, st+1, en-1);
				local lineHeight = getTextManager():getFontFromEnum(self.font):getLineHeight();
				if lineHeight < 10 then
					lineHeight = 10;
				end
				if lineHeight < lineImageHeight then
					lineHeight = lineImageHeight;
				end
				self.currentLine = lines;
				local column = tonumber(escSeq:match('^TICSCOL:([%d%.]+)$') or '')
				if escSeq == 'TICSCHIP' then
					pendingChip = true
				elseif column then
					x = math.max(x, column)
					self.currentWrapIndent = column
				else
					x, y, lineImageHeight = self:processCommand(escSeq, x, y, lineImageHeight, lineHeight);
				end
				if escSeq == 'LINE' then
					messageIndex = messageIndex + 1
					self.currentWrapIndent = nil
				end
			else
				if token:contains("&lt;") then
					token = token:gsub("&lt;", "<")
				end
				if token:contains("&gt;") then
					token = token:gsub("&gt;", ">")
				end
				local chunkText = self.lines[lines] or ''
				local chunkX = self.lineX[lines] or x
				if chunkText == '' then
					-- a blank token starting a chunk takes no space (ChunkWidth would measure a space)
					if string.trim(token) ~= '' then
						chunkText = ' ' .. string.trim(token)
					end
				elseif string.trim(token) ~= '' then
					chunkText = chunkText .. ' ' .. string.trim(token)
				end
				-- a label chunk (current one, or the one this token starts) is measured in its font
				local isChipChunk = self.lineChip[lines]
					or (pendingChip and not self.lines[lines] and string.trim(token) ~= '')
				local pixLen = ChunkWidth((isChipChunk and chipFont) or self.font, chunkText);
				if chunkX + pixLen > maxLineWidth then
					if self.lines[lines] and self.lines[lines] ~= '' then
						lines = lines + 1;
					end
					local lineHeight = getTextManager():getFontFromEnum(self.font):getLineHeight();
					if lineHeight < lineImageHeight then
						lineHeight = lineImageHeight;
					end
					lineImageHeight = 0;
					y = y + lineHeight;
					x = 0;
					-- leading space like any chunk start: lines are drawn trimmed at a position measured
					-- with it, without it the next colored chunk on this line is glued to the text
					self.lines[lines] = string.trim(token)
					if self.lines[lines] ~= "" then
						self.lines[lines] = ' ' .. self.lines[lines]
					end
					if self.lines[lines] ~= "" then
						-- continuation of a wrapped message
						x = self.indent + (self.currentWrapIndent or self.wrapIndent or 0)
					end
					self.lineX[lines] = x
					self.lineY[lines] = y
					self.lineMessage[lines] = messageIndex
					x = x + ChunkWidth(self.font, self.lines[lines])
				else
					if not self.lines[lines] then
						self.lines[lines] = ''
						self.lineX[lines] = x
						self.lineY[lines] = y
						self.lineMessage[lines] = messageIndex
						if pendingChip and string.trim(token) ~= '' then
							pendingChip = false
							self.lineChip[lines] = true
							self.lineX[lines] = x + chipPadding
						end
					end
					self.lines[lines] = chunkText
					if self.lineX[lines] == 0 and self.lines[lines] ~= "" then
						self.lineX[lines] = self.indent
					end
					x = self.lineX[lines] + pixLen
					if self.lineChip[lines] then
						x = x + chipPadding
					end
				end
			end
		else
			if string.trim(leftText) ~= '' then
				local str = leftText
				if str:contains("&lt;") then
					str = str:gsub("&lt;", "<")
				end
				if str:contains("&gt;") then
					str = str:gsub("&gt;", ">")
				end
				self.lines[lines] = string.trim(str);
				if x == 0 and self.lines[lines] ~= "" then
					x = self.indent
				end
				self.lineX[lines] = x;
				self.lineY[lines] = y;
				self.lineMessage[lines] = messageIndex
				local lineHeight = getTextManager():getFontFromEnum(self.font):getLineHeight();
				y = y + lineHeight
			elseif self.lines[lines] and self.lines[lines] ~= '' then
				local lineHeight = getTextManager():getFontFromEnum(self.font):getLineHeight();
				if lineHeight < lineImageHeight then
					lineHeight = lineImageHeight;
				end
				y = y + lineHeight
			end
			bDone = true;
		end
	end

	if self.autosetheight then
		self:setHeight(self.marginTop + y + self.marginBottom);
	end

	self:setScrollHeight(self.marginTop + y + self.marginBottom);
end

function ISTicsRichTextPanel:new(x, y, width, height)
    local o = ISRichTextPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return ISTicsRichTextPanel
