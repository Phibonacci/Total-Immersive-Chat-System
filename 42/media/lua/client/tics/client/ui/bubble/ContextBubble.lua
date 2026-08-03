local ABubble       = require('tics/client/ui/bubble/ABubble')
local Coordinates   = require('tics/client/utils/Coordinates')
local Parser        = require('tics/client/parser/Parser')
local StringBuilder = require('tics/client/parser/StringBuilder')

local KeyboardSound = require('tics/client/voice/KeyboardSound')

local ContextBubble = ISUIElement:derive('ContextBubble')

function ContextBubble:loadTextures()
    self.bubbleTopLeft     = getTexture('media/ui/tics/bubble/simple/bubble-top-left-square.png')
    self.bubbleTopRight    = getTexture('media/ui/tics/bubble/simple/bubble-top-right-square.png')
    self.bubbleBotLeft     = getTexture('media/ui/tics/bubble/simple/bubble-bot-left-square.png')
    self.bubbleBotRight    = getTexture('media/ui/tics/bubble/simple/bubble-bot-right-square.png')
    self.bubbleTop         = getTexture('media/ui/tics/bubble/simple/bubble-top.png')
    self.bubbleCenter      = getTexture('media/ui/tics/bubble/simple/bubble-center.png')
    self.bubbleCenterLeft  = getTexture('media/ui/tics/bubble/simple/bubble-left.png')
    self.bubbleCenterRight = getTexture('media/ui/tics/bubble/simple/bubble-right.png')
    self.bubbleBot         = getTexture('media/ui/tics/bubble/simple/bubble-bot.png')
end

function ContextBubble:setY(y)
    local ys = y
    if self:getKeepOnScreen() then
        local maxY = getCore():getScreenHeight();
        local topSpace = self.topSpace
        ys = math.max(topSpace, math.min(y, maxY - self.height));
    end

    self.y = ys;
    if self.javaObject ~= nil then
        self.javaObject:setY(ys);
    end
end

local function Lerp(start, target, progression)
    if progression < 0.0 then
        progression = 0.0
    elseif progression >= 1.0 then
        progression = 1.0
    end
    local distance = target - start
    distance = distance * progression
    return start + distance
end

function ContextBubble:parseMessage(length)
    local parsedMessages = Parser.ParseTicsMessage(self.message, self.color, 20, length)
    return parsedMessages['rawMessage'], parsedMessages['bubble']
end

function ContextBubble:updateText(x, y)
    if not self.isBubbleReady then
        return
    end
    local time = Calendar.getInstance():getTimeInMillis()
    local elapsedTime = time - self.startTime

    local length = nil
    if self.voice ~= nil then
        length = self.voice:currentMessageIndex()
        if not self.messageFinishedScrolling and length == self.fullMessageLength then
            self.messageFinishedScrolling = true
            -- if the bubble is following the voice speed we want it to stay alive at least
            -- until 2s after all the text appeared
            self.timer = math.max(elapsedTime + 2000, self.timer)
        end
    else
        self.messageFinishedScrolling = true
    end
    local rawMessage, bubbleMessage = self:parseMessage(length)

    self.text = StringBuilder.BuildFontSizeString('medium') .. bubbleMessage
    self.rawText = rawMessage

    self:paginate()

    if self.voice then
        self.voice:subscribe()
    end
    if not self.texturesLoaded then
        self:loadTextures()
        self.texturesLoaded = true
    end
    self:setX(x)
    self:setY(y)
    self.currentHeight = self:getHeight()
end

function ContextBubble:drawBubble()
    if self.dead then
        return
    end

    local time = Calendar.getInstance():getTimeInMillis()
    local elapsedTime = time - self.startTime
    local delta = time - self.previousTime

    if not self.isBubbleReady then
        if elapsedTime > self.introAnimationTime then
            self.isBubbleReady = true
            self.currentX = self.targetX
            self.currentWidth = self.targetWidth
        else
            local newProgression = delta / (2 * 100)
            self.currentProgression = self.currentProgression + newProgression
            self.currentWidth = Lerp(0, self.targetWidth, self.currentProgression)
            self.currentX = self.startingX - self.currentWidth / 2
        end
        self:setWidth(self.currentWidth)
        self:setX(self.currentX)
    end

    local scale = 1
    if self.timer - elapsedTime > 1000 or not self.messageFinishedScrolling then
        self.alpha = self.opacity
    elseif self.timer - elapsedTime > 0 then
        local fadingTime = elapsedTime - (self.timer - 1000)
        self.fadingProgression = (1000 - fadingTime) / 1000
        self.alpha = self.fadingProgression * self.opacity
    else
        self.dead = true
        if self.voice then
            self.voice:unsubscribe()
        end
        return
    end

    local leftX = 0
    local leftW = math.floor(10 * 1 / scale)
    local rightW = math.floor(10 * 1 / scale)
    local centerW = math.floor(self.currentWidth) - rightW - leftW
    local centerX = leftX + leftW
    local rightX = centerX + centerW
    local topH = math.floor(10 * 1 / scale)
    self:drawTextureScaled(self.bubbleTopLeft, leftX, 0, leftW, topH, self.alpha)
    self:drawTextureScaled(self.bubbleTop, centerX, 0, centerW, topH, self.alpha)
    self:drawTextureScaled(self.bubbleTopRight, rightX, 0, rightW, topH, self.alpha)

    local centerY = topH
    local botH = math.floor(10 * 1 / scale)
    local centerH = math.floor(self.currentHeight) - botH - topH
    local botY = centerY + centerH

    self:drawTextureScaled(self.bubbleCenterLeft, leftX, centerY, leftW, centerH, self.alpha)
    self:drawTextureScaled(self.bubbleCenter, centerX, centerY, centerW, centerH, self.alpha)
    self:drawTextureScaled(self.bubbleCenterRight, rightX, centerY, rightW, centerH, self.alpha)

    if self.playerAvatar or self.playerModel then
        self:drawTextureScaled(self.bubbleBotLeftSquare, leftX, botY, leftW, botH, self.alpha)
    else
        self:drawTextureScaled(self.bubbleBotLeft, leftX, botY, leftW, botH, self.alpha)
    end
    self:drawTextureScaled(self.bubbleBot, centerX, botY, centerW, botH, self.alpha)
    self:drawTextureScaled(self.bubbleBotRight, rightX, botY, rightW, botH, self.alpha)

    ISRichTextPanel.render(self)
    self.previousTime = time
end

function ContextBubble:render()
    if self.dead then
        return
    end
    if not self.texturesLoaded then
        self:loadTextures()
        self.texturesLoaded = true
    end

    self.marginLeft = self.defaultLeftMargin
    self:setWidth(self.targetWidth)

    local screenWidth = getCore():getScreenWidth()
    local x, y = screenWidth / 2 - self:getWidth() / 2, 150 - self:getHeight() / 2
    -- print('TICS debug: x:' .. x .. ', y:' .. y)
    self:updateText(x, y)
    self:drawBubble()
end

function ContextBubble:new(message, messageColor, timer, opacity, isVoiceEnabled, voicePitch)
    local parsedMessages = Parser.ParseTicsMessage(message, messageColor, 40, 200)
    local rawMessage = parsedMessages['rawMessage']
    local bubbleMessage = parsedMessages['bubble']

    local textLength = getTextManager():MeasureStringX(UIFont.medium, rawMessage)
    local width = math.min(textLength * 1.25, 364) + 40
    local height = 40
    local screenWidth = getCore():getScreenWidth()
    local x, y = screenWidth / 2 - width / 2, 150 - height / 2

    self.__index = self
    setmetatable(self, { __index = ISRichTextPanel })
    local o = ISRichTextPanel:new(x, y, width, height)
    setmetatable(o, self)

    if isVoiceEnabled then
        o.voice = KeyboardSound:new(rawMessage, getPlayer(), voicePitch)
    end
    o.text = ''
    o.timer = timer * 1000
    o.opacity = opacity / 100
    o.message = message
    o.color = messageColor
    o.rawText = rawMessage
    o.fullMessageLength = #rawMessage
    o.messageFinishedScrolling = false
    o.background = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }

    o.anchorLeft = true
    o.anchorRight = false
    o.anchorTop = true
    o.anchorBottom = false

    o.moveWithMouse = false

    o.startTime = Calendar.getInstance():getTimeInMillis()
    o.previousTime = o.startTime
    o.dead = false

    ISUIElement.initialise(o)
    o:paginate()
    o:setHeight(height)

    o.introAnimationTime = 300
    o.texturesLoaded = false
    o.alpha = o.opacity
    o.fadingProgression = 1
    o.defaultLeftMargin = 20
    o.defaultTopMargin = 10
    o.topSpace = 0

    o.isBubbleReady = false
    o.startingX = screenWidth / 2
    o.currentX = o.startingX
    o.targetX = x
    o.currentWidth = 0
    o.targetWidth = width
    o.currentHeight = height
    o.currentProgression = 0
    return o
end

return ContextBubble
