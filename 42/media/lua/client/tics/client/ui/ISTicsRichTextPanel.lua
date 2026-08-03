local ISTicsRichTextPanel = ISRichTextPanel:derive("ISTicsRichTextPanel");

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
				x, y, lineImageHeight = self:processCommand(escSeq, x, y, lineImageHeight, lineHeight);
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
					chunkText = ' ' .. string.trim(token)
				elseif string.trim(token) ~= '' then
					chunkText = chunkText .. ' ' .. string.trim(token)
				end
				local pixLen = getTextManager():MeasureStringX(self.font, chunkText);
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
					self.lines[lines] = string.trim(token)
					if self.lines[lines] ~= "" then
						x = self.indent
					end
					self.lineX[lines] = x
					self.lineY[lines] = y
					x = x + getTextManager():MeasureStringX(self.font, self.lines[lines])
				else
					if not self.lines[lines] then
						self.lines[lines] = ''
						self.lineX[lines] = x
						self.lineY[lines] = y
					end
					self.lines[lines] = chunkText
					if self.lineX[lines] == 0 and self.lines[lines] ~= "" then
						self.lineX[lines] = self.indent
					end
					x = self.lineX[lines] + pixLen
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
