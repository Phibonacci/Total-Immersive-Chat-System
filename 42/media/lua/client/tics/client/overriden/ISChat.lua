

local ChatUI                 = require('tics/client/ui/ChatUI')
local ChatTheme              = require('tics/client/ui/ChatTheme')
local ChatPopup              = require('tics/client/ui/ChatPopup')
local ChatSettingsPanel      = require('tics/client/ui/ChatSettingsPanel')
local ChatHelpPanel          = require('tics/client/ui/ChatHelpPanel')
local RpLog                  = require('tics/client/RpLog')
local Journal                = require('tics/client/journal/Journal')
local JournalWindow          = require('tics/client/ui/JournalWindow')
local File                   = require('tics/shared/utils/File')
local CharacterSheetManager  = require('tics/client/CharacterSheetManager')
local CharacterSheetWindow   = require('tics/client/ui/CharacterSheetWindow')
local TicsColorPicker        = require('tics/client/ui/TicsColorPicker')
local ChatText               = require('tics/client/ui/Chat/ChatText')

local ContextBubble          = require('tics/client/ui/bubble/ContextBubble')
local PlayerBubble           = require('tics/client/ui/bubble/PlayerBubble')
local RadioBubble            = require('tics/client/ui/bubble/RadioBubble')

local AvatarManager          = require('tics/client/AvatarManager')
local AvatarUploadWindow     = require('tics/client/ui/AvatarUploadWindow')
local AvatarValidationWindow = require('tics/client/ui/AvatarValidationWindow')
local Character              = require('tics/shared/utils/Character')
local LanguageManager        = require('tics/client/languages/LanguageManager')
local FakeRadioPacket        = require('tics/client/FakeRadioPacket')
local Parser                 = require('tics/client/parser/Parser')
local RadioRangeIndicator    = require('tics/client/ui/RadioRangeIndicator')
local RangeIndicator         = require('tics/client/ui/RangeIndicator')
local ClientSend             = require('tics/client/network/ClientSend')
local ClientSettings         = require('tics/client/ClientSettings')
local StringBuilder          = require('tics/client/parser/StringBuilder')
local StringFormat           = require('tics/shared/utils/StringFormat')
local StringParser           = require('tics/shared/utils/StringParser')
local TypingDots             = require('tics/client/ui/TypingDots')
local World                  = require('tics/shared/utils/World')


ISChat.allChatStreams     = {}
ISChat.allChatStreams[1]  = { name = 'say', command = '/say ', shortCommand = '/s ', tabID = 1 }
ISChat.allChatStreams[2]  = { name = 'whisper', command = '/whisper ', shortCommand = '/w ', tabID = 1 }
ISChat.allChatStreams[3]  = { name = 'low', command = '/low ', shortCommand = '/l ', tabID = 1 }
ISChat.allChatStreams[4]  = { name = 'yell', command = '/yell ', shortCommand = '/y ', tabID = 1 }
ISChat.allChatStreams[5]  = { name = 'faction', command = '/faction ', shortCommand = '/f ', tabID = 1 }
ISChat.allChatStreams[6]  = { name = 'safehouse', command = '/safehouse ', shortCommand = '/sh ', tabID = 1 }
ISChat.allChatStreams[7]  = { name = 'general', command = '/all ', shortCommand = '/g ', tabID = 1 }
ISChat.allChatStreams[8]  = { name = 'scriptedRadio', command = nil, shortCommand = nil, tabID = 1 }
ISChat.allChatStreams[9]  = { name = 'ooc', command = '/ooc ', shortCommand = '/o ', tabID = 2 }
ISChat.allChatStreams[10] = { name = 'pm', command = '/pm ', shortCommand = '/p ', tabID = 3 }
ISChat.allChatStreams[11] = { name = 'admin', command = '/admin ', shortCommand = '/a ', tabID = 4 }
ISChat.allChatStreams[12] = { name = 'me', command = '/me ', shortCommand = nil, tabID = 1, forget = true }
ISChat.allChatStreams[13] = { name = 'do', command = '/do ', shortCommand = nil, tabID = 1, forget = true }


ISChat.ticsCommand    = {}
ISChat.ticsCommand[1] = { name = 'color', command = '/color', shortCommand = nil }
ISChat.ticsCommand[2] = { name = 'pitch', command = '/pitch', shortCommand = nil }
ISChat.ticsCommand[3] = { name = 'roll', command = '/roll', shortCommand = nil }
ISChat.ticsCommand[4] = { name = 'language', command = '/language', shortCommand = '/la' }


ISChat.defaultTabStream    = {}
ISChat.defaultTabStream[1] = ISChat.allChatStreams[1]
ISChat.defaultTabStream[2] = ISChat.allChatStreams[9]
ISChat.defaultTabStream[3] = ISChat.allChatStreams[10]
ISChat.defaultTabStream[4] = ISChat.allChatStreams[11]


ISChat.lastTabStream    = {}
ISChat.lastTabStream[1] = ISChat.defaultTabStream[1]
ISChat.lastTabStream[2] = ISChat.defaultTabStream[2]
ISChat.lastTabStream[3] = ISChat.defaultTabStream[3]
ISChat.lastTabStream[4] = ISChat.defaultTabStream[4]


local function IsOnlySpacesOrEmpty(command)
    local commandWithoutSpaces = command:gsub('%s+', '')
    return #commandWithoutSpaces == 0
end

local function GetCommandFromMessage(command)
    if not luautils.stringStarts(command, '/') then
        local defaultStream = ISChat.defaultTabStream[ISChat.instance.currentTabID]
        return defaultStream, '', false
    end
    if IsOnlySpacesOrEmpty(command) then
        return nil
    end
    for _, stream in ipairs(ISChat.allChatStreams) do
        if stream.command and luautils.stringStarts(command, stream.command) then
            return stream, stream.command, false
        elseif stream.shortCommand and luautils.stringStarts(command, stream.shortCommand) then
            return stream, stream.shortCommand, false
        end
    end
    return nil
end

local function GetTicsCommandFromMessage(command)
    if not luautils.stringStarts(command, '/') then
        return nil
    end
    if IsOnlySpacesOrEmpty(command) then
        return nil
    end
    for _, stream in ipairs(ISChat.ticsCommand) do
        if luautils.stringStarts(command, stream.command) then
            return stream, stream.command
        elseif stream.shortCommand and luautils.stringStarts(command, stream.shortCommand) then
            return stream, stream.shortCommand
        end
    end
    return nil
end

local function UpdateTabStreams(newTab, tabID)
    newTab.chatStreams = {}
    for _, stream in pairs(ISChat.allChatStreams) do
        local name = stream['name']
        if stream['tabID'] == tabID and TicsServerSettings and TicsServerSettings[name] and TicsServerSettings[name]['enabled'] then
            table.insert(newTab.chatStreams, stream)
        end
    end
    if #newTab.chatStreams >= 1 then
        ISChat.defaultTabStream[tabID] = newTab.chatStreams[1]
        newTab.lastChatCommand = newTab.chatStreams[1].command
    end
end

local function UpdateRangeIndicatorVisibility()
    if ISChat.instance.rangeButtonState == 'visible' then
        if ISChat.instance.rangeIndicator and ISChat.instance.focused then
            ISChat.instance.rangeIndicator:subscribe()
        end
    elseif ISChat.instance.rangeButtonState == 'hidden' then
        if ISChat.instance.rangeIndicator then
            ISChat.instance.rangeIndicator:unsubscribe()
        end
    else
        if ISChat.instance.rangeIndicator then
            ISChat.instance.rangeIndicator:subscribe()
        end
    end
end

local function UpdateRangeIndicator(stream)
    if TicsServerSettings ~= nil
        and TicsServerSettings[stream.name]['range'] ~= nil
        and TicsServerSettings[stream.name]['range'] ~= -1
        and TicsServerSettings[stream.name]['color'] ~= nil
    then
        if ISChat.instance.rangeIndicator then
            ISChat.instance.rangeIndicator:unsubscribe()
        end
        local range = TicsServerSettings[stream.name]['range']
        ISChat.instance.rangeIndicator = RangeIndicator:new(getPlayer(), range,
            TicsServerSettings[stream.name]['color'])
        UpdateRangeIndicatorVisibility()
    else
        if ISChat.instance.rangeIndicator then
            ISChat.instance.rangeIndicator:unsubscribe()
        end
        ISChat.instance.rangeIndicator = nil
    end
end

-- Input channel chip: typing a channel command followed by a space ("/s ", "/yell "...)
-- moves the command out of the text into a label on the left of the input box.
-- getInputText() always returns the full text, command included.
local function FindChipStream(text)
    for _, stream in ipairs(ISChat.allChatStreams) do
        if stream.command and luautils.stringStarts(text, stream.command) then
            return stream, stream.command
        elseif stream.shortCommand and luautils.stringStarts(text, stream.shortCommand) then
            return stream, stream.shortCommand
        end
    end
    return nil
end

function ISChat:getInputText()
    local prefix = self.inputChip and self.inputChip.prefix or ''
    return prefix .. self.textEntry:getInternalText()
end

function ISChat:setInputText(text)
    local stream, prefix = FindChipStream(text or '')
    if stream then
        self.inputChip = { stream = stream, prefix = prefix }
        text = text:sub(#prefix + 1)
    else
        self.inputChip = nil
    end
    self.textEntry:setText(text or '')
end

-- backspace in an empty input box puts the command back in the text so it can be edited
function ISChat:removeInputChip()
    if self.inputChip == nil then
        return
    end
    local command = self.inputChip.prefix:gsub('%s+$', '')
    self.inputChip = nil
    self.textEntry:setText(command .. self.textEntry:getInternalText())
    ISChat.onTextChange()
end

-- called every frame, the text box does not report a backspace on an empty text
-- and key events are not sent to Lua while typing
function ISChat:updateInputChipBackspace()
    local isEmpty = self.textEntry:getInternalText() == ''
    local backspaceDown = ISChat.focused and GameKeyboard.isKeyDownRaw(Keyboard.KEY_BACK)
    if backspaceDown and not self.backspaceWasDown and self.inputWasEmpty and isEmpty then
        self:removeInputChip()
        isEmpty = self.textEntry:getInternalText() == ''
    end
    self.backspaceWasDown = backspaceDown
    self.inputWasEmpty = isEmpty
end

-- Extra cursor shortcuts for the input box (the game text box only knows one character moves,
-- Home/End, Shift selections and Ctrl+A/C/V/X):
-- - Alt+Left/Right: previous word start / next word end
-- - Ctrl+Left/Right: start / end of the text
-- With Shift held the selection is extended, the moves use the text box's own key handlers.
-- Called every frame: key events are not sent to Lua while typing. The game already moved the
-- cursor by one character for the key press, the jump continues from there.
local KEY_LEFT, KEY_RIGHT = 203, 205
local KEY_LCONTROL, KEY_RCONTROL, KEY_LMENU, KEY_RMENU = 29, 157, 56, 184

local function IsSpace(text, index)
    local c = text:sub(index, index)
    return c == ' ' or c == ''
end

-- cursor positions are between characters: position p is after the p-th character
local function PreviousWordStart(text, cursor)
    local p = cursor
    while p > 0 and IsSpace(text, p) do p = p - 1 end
    while p > 0 and not IsSpace(text, p) do p = p - 1 end
    return p
end

local function NextWordEnd(text, cursor)
    local p = cursor
    while p < #text and IsSpace(text, p + 1) do p = p + 1 end
    while p < #text and not IsSpace(text, p + 1) do p = p + 1 end
    return p
end

-- The game selects all with Ctrl + the key at the position of A on a US keyboard (code 30),
-- with another layout (AZERTY...) the key typing "a" is elsewhere. Key names follow the
-- active layout, the key named "A" is looked up once.
local KEY_US_A = 30
local selectAllKey = nil
local function GetSelectAllKey()
    if selectAllKey == nil then
        selectAllKey = KEY_US_A
        for code = 1, 255 do
            local name = getKeyName(code)
            if type(name) == 'string' and name:upper() == 'A' then
                selectAllKey = code
                break
            end
        end
    end
    return selectAllKey
end

-- Alt+Backspace: delete the word before the cursor. The game already deleted one character
-- (or the selection) when this runs, so the text and cursor of the previous frame are used.
local KEY_BACK = 14
function ISChat:updateDeleteWord(box)
    local text = box:getInternalText()
    local cursor = box:getCursorPos()
    local backDown = ISChat.focused and GameKeyboard.isKeyDownRaw(KEY_BACK)
    local alt = GameKeyboard.isKeyDownRaw(KEY_LMENU) or GameKeyboard.isKeyDownRaw(KEY_RMENU)
    if backDown and not self.backKeyWasDownForWord and alt and self.lastInputText then
        local before, beforeCursor = self.lastInputText, self.lastInputCursor
        -- only when the game deleted one character (not a selection)
        if #text == #before - 1 and cursor == beforeCursor - 1 then
            local target = PreviousWordStart(before, beforeCursor)
            local newText = before:sub(1, target) .. before:sub(beforeCursor + 1)
            self.textEntry:setText(newText)
            box:setCursorPos(target)
            ISChat.onTextChange()
            text, cursor = box:getInternalText(), box:getCursorPos()
        end
    end
    self.backKeyWasDownForWord = backDown
    self.lastInputText = text
    self.lastInputCursor = cursor
end

function ISChat:updateInputShortcuts()
    self:updateDeleteWord(self.textEntry.javaObject)
    local selectAllKey = GetSelectAllKey()
    if selectAllKey ~= KEY_US_A then
        local selectAllDown = ISChat.focused and GameKeyboard.isKeyDownRaw(selectAllKey)
        local ctrlDown = GameKeyboard.isKeyDownRaw(29) or GameKeyboard.isKeyDownRaw(157)
        if selectAllDown and not self.selectAllKeyWasDown and ctrlDown then
            self.textEntry.javaObject:selectAll()
        end
        self.selectAllKeyWasDown = selectAllDown
    end

    local leftDown = ISChat.focused and GameKeyboard.isKeyDownRaw(KEY_LEFT)
    local rightDown = ISChat.focused and GameKeyboard.isKeyDownRaw(KEY_RIGHT)
    local leftPressed = leftDown and not self.leftKeyWasDown
    local rightPressed = rightDown and not self.rightKeyWasDown
    self.leftKeyWasDown = leftDown
    self.rightKeyWasDown = rightDown
    if not leftPressed and not rightPressed then
        return
    end
    local box = self.textEntry.javaObject
    local ctrl = GameKeyboard.isKeyDownRaw(KEY_LCONTROL) or GameKeyboard.isKeyDownRaw(KEY_RCONTROL)
    local alt = GameKeyboard.isKeyDownRaw(KEY_LMENU) or GameKeyboard.isKeyDownRaw(KEY_RMENU)
    if ctrl then
        if leftPressed then box:onKeyHome() else box:onKeyEnd() end
    elseif alt then
        local text = box:getInternalText()
        local cursor = box:getCursorPos()
        -- the jump is computed from the position before the game's one character move
        if leftPressed then
            local target = PreviousWordStart(text, math.min(cursor + 1, #text))
            for _ = 1, math.max(0, cursor - target) do box:onKeyLeft() end
        else
            local target = NextWordEnd(text, math.max(cursor - 1, 0))
            for _ = 1, math.max(0, target - cursor) do box:onKeyRight() end
        end
    end
end

ISChat.onSwitchStream = function()
    if ISChat.focused then
        local internalText = ISChat.instance:getInputText()
        local data = luautils.split(internalText, " ")
        local onlineUsers = getOnlinePlayers()
        for i = 0, onlineUsers:size() - 1 do
            local username = onlineUsers:get(i):getUsername()
            if #data > 1 and string.match(string.lower(username), string.lower(data[#data])) then
                local txt = ""
                for i = 1, #data - 1 do
                    txt = txt .. data[i] .. " "
                end
                txt = txt .. username
                ISChat.instance:setInputText(txt)
                return
            end
        end

        local curTxtPanel = ISChat.instance.chatText
        if curTxtPanel == nil then
            return
        end
        local chatStreams = curTxtPanel.chatStreams
        curTxtPanel.streamID = curTxtPanel.streamID % #chatStreams + 1
        local stream = chatStreams[curTxtPanel.streamID]
        ISChat.lastTabStream[ISChat.instance.currentTabID] = stream
        ISChat.instance:setInputText(stream.command)
        UpdateRangeIndicator(stream)
    end
end

local function AddTab(tabTitle, tabID)
    local chat = ISChat.instance
    if chat.tabs[tabID] ~= nil then
        return
    end
    local newTab = chat:createTab()
    newTab.parent = chat
    newTab.tabTitle = tabTitle
    newTab.tabID = tabID
    newTab.streamID = 1
    UpdateTabStreams(newTab, tabID)
    newTab:setUIName("chat text panel with title '" .. tabTitle .. "'")
    local pos = chat:calcTabPos()
    local size = chat:calcTabSize()
    newTab:setY(pos.y)
    newTab:setHeight(size.height)
    newTab:setWidth(size.width)
    if chat.tabCnt == 0 then
        chat:addChild(newTab)
        chat.chatText = newTab
        chat.chatText:setVisible(true)
        chat.currentTabID = tabID
    end
    if chat.tabCnt == 1 then
        chat.panel:setVisible(true)
        chat.chatText:setY(pos.y)
        chat.chatText:setHeight(size.height)
        chat.chatText:setWidth(size.width)
        chat:removeChild(chat.chatText)
        chat.panel:addView(chat.chatText.tabTitle, chat.chatText)
    end

    if chat.tabCnt >= 1 then
        chat.panel:addView(tabTitle, newTab)
        chat.minimumWidth = chat.panel:getWidthOfAllTabs() + 2 * chat.inset
    end
    chat.tabs[tabID] = newTab
    chat.tabCnt = chat.tabCnt + 1
end

Events.OnChatWindowInit.Remove(ISChat.initChat)

local function GetRandomInt(min, max)
    return ZombRand(max - min) + min
end

local function GenerateRandomColor()
    return { GetRandomInt(0, 254), GetRandomInt(0, 254), GetRandomInt(0, 254), }
end

local function SaveTicsModData()
    ModData.add('tics', ISChat.instance.ticsModData)
    -- global ModData is not saved to disk by multiplayer clients in build 42
    ClientSettings.save(ISChat.instance.ticsModData)
end

local function SetPlayerColor(color)
    ISChat.instance.ticsModData['playerColor'] = color
    SaveTicsModData()
end

local function SetPlayerPitch(pitch)
    ISChat.instance.ticsModData['voicePitch'] = pitch
    SaveTicsModData()
end

local function RandomVoicePitch(isFemale)
    local randomPitch = ZombRandFloat(0.85, 1.15)
    if isFemale == true then
        randomPitch = randomPitch + 0.30
    end
    return randomPitch
end

local function InitGlobalModData()
    local ticsModData = ModData.getOrCreate("tics")
    for key, value in pairs(ClientSettings.load()) do
        ticsModData[key] = value
    end
    ISChat.instance.ticsModData = ticsModData

    if ticsModData['playerColor'] == nil then
        SetPlayerColor(GenerateRandomColor())
    end
    if ticsModData['isVoiceEnabled'] == nil and ISChat.instance.isVoiceEnabled == nil then
        -- wait for the server settings to override this if voices are enabled by default
        ISChat.instance.isVoiceEnabled = false
    elseif ticsModData['isVoiceEnabled'] ~= nil then
        ISChat.instance.isVoiceEnabled = ticsModData['isVoiceEnabled']
    end
    if ticsModData['isRadioIconEnabled'] == nil and ISChat.instance.isRadioIconEnabled == nil then
        ISChat.instance.isRadioIconEnabled = true
    elseif ticsModData['isRadioIconEnabled'] ~= nil then
        ISChat.instance.isRadioIconEnabled = ticsModData['isRadioIconEnabled']
    end
    if ticsModData['isPortraitEnabled'] == nil and ISChat.instance.isPortraitEnabled == nil then
        ISChat.instance.isPortraitEnabled = true
    elseif ticsModData['isPortraitEnabled'] ~= nil then
        ISChat.instance.isPortraitEnabled = ticsModData['isPortraitEnabled']
    end
    -- personal RP log: enabled by default
    ISChat.instance.isRpLogEnabled = ticsModData['isRpLogEnabled'] ~= false
    -- timestamp and tags: enabled by default (the vanilla game options default to disabled),
    -- the player's choice is saved with the other TICS settings
    if ticsModData['showTimestamp'] == nil then
        ISChat.instance.showTimestamp = true
    else
        ISChat.instance.showTimestamp = ticsModData['showTimestamp']
    end
    if ticsModData['showTitle'] == nil then
        ISChat.instance.showTitle = true
    else
        ISChat.instance.showTitle = ticsModData['showTitle']
    end
    ISChat.instance:updateChatPrefixSettings()
    if ticsModData['isHudEnabled'] == nil then
        ISChat.instance.isHudEnabled = true
    else
        ISChat.instance.isHudEnabled = ticsModData['isHudEnabled']
    end
    if ticsModData['voicePitch'] == nil then
        local randomPitch = RandomVoicePitch(getPlayer():getVisual():isFemale())
        SetPlayerPitch(randomPitch)
    end
end

local lastAskedDataTime = Calendar.getInstance():getTimeInMillis() - 2000
local function AskServerData()
    local delta = Calendar.getInstance():getTimeInMillis() - lastAskedDataTime
    if delta < 2000 then
        return
    end
    lastAskedDataTime = Calendar.getInstance():getTimeInMillis()

    ClientSend.sendAskSandboxVars()
end

ISChat.initChat = function()
    TicsServerSettings = nil
    local instance = ISChat.instance
    if instance.tabCnt == 1 then
        instance.chatText:setVisible(false)
        instance:removeChild(instance.chatText)
        instance.chatText = nil
    elseif instance.tabCnt > 1 then
        instance.panel:setVisible(false)
        for tabId, tab in pairs(instance.tabs) do
            instance.panel:removeView(tab)
        end
    end
    instance.tabCnt = 0
    instance.tabs = {}
    instance.currentTabID = 0
    instance.rangeButtonState = 'hidden'
    instance.online = false
    instance.lastDiscordMessages = {}

    InitGlobalModData()
    AddTab('General', 1)
    AvatarManager:createRequestDirectory()
    Events.OnPostRender.Add(AskServerData)
end

Events.OnGameStart.Remove(ISChat.createChat)

local function CreateChat()
    if not isClient() then
        return
    end
    ISChat.chat = ISChat:new(15, getCore():getScreenHeight() - 400, 500, 200)
    ISChat.chat:initialise()
    ISChat.chat:addToUIManager()
    ISChat.chat:setVisible(true)
    ISChat.chat:bringToTop()
    ISLayoutManager.RegisterWindow('chat', ISChat, ISChat.chat)

    ISChat.instance:setVisible(true)

    Events.OnAddMessage.Add(ISChat.addLineInChat)
    Events.OnMouseDown.Add(ISChat.unfocusEvent)
    Events.OnKeyPressed.Add(ISChat.onToggleChatBox)
    Events.OnKeyKeepPressed.Add(ISChat.onKeyKeepPressed)
    Events.OnTabAdded.Add(ISChat.onTabAdded)
    Events.OnSetDefaultTab.Add(ISChat.onSetDefaultTab)
    Events.OnTabRemoved.Add(ISChat.onTabRemoved)
    Events.SwitchChatStream.Add(ISChat.onSwitchStream)
end

Events.OnGameStart.Add(CreateChat)

local function ProcessChatCommand(stream, command)
    if TicsServerSettings and TicsServerSettings[stream.name] == false then
        return false
    end
    local pitch = ISChat.instance.ticsModData['voicePitch']
    local ticsCommand = Parser.ParseTicsMessage(command)
    local playerColor = ISChat.instance.ticsModData['playerColor']
    if ticsCommand == nil then
        return false
    end
    local language = LanguageManager:getCurrentLanguage()
    if stream.name == 'yell' then
        ClientSend.sendChatMessage(command, language, playerColor, 'yell', pitch, false)
    elseif stream.name == 'say' then
        ClientSend.sendChatMessage(command, language, playerColor, 'say', pitch, false)
    elseif stream.name == 'low' then
        ClientSend.sendChatMessage(command, language, playerColor, 'low', pitch, false)
    elseif stream.name == 'whisper' then
        ClientSend.sendChatMessage(command, language, playerColor, 'whisper', pitch, false)
    elseif stream.name == 'me' then
        ClientSend.sendChatMessage(command, language, playerColor, 'me', pitch, true)
    elseif stream.name == 'do' then
        ClientSend.sendChatMessage(command, language, playerColor, 'do', pitch, true)
    elseif stream.name == 'pm' then
        local targetStart, targetEnd = command:find('^%s*"%a+%s?%a+"')
        if targetStart == nil then
            targetStart, targetEnd = command:find('^%s*%a+')
        end
        if targetStart == nil or targetEnd + 1 >= #command or command:sub(targetEnd + 1, targetEnd + 1) ~= ' ' then
            return false
        end
        local target = command:sub(targetStart, targetEnd)
        local pmBody = command:sub(targetEnd + 2)
        ClientSend.sendPrivateMessage(pmBody, language, playerColor, target, pitch)
        ISChat.instance.chatText.lastChatCommand = ISChat.instance.chatText.lastChatCommand .. target .. ' '
    elseif stream.name == 'faction' then
        ClientSend.sendChatMessage(command, language, playerColor, 'faction', pitch, false)
    elseif stream.name == 'safehouse' then
        ClientSend.sendChatMessage(command, language, playerColor, 'safehouse', pitch, false)
    elseif stream.name == 'general' then
        ClientSend.sendChatMessage(command, language, playerColor, 'general', pitch, false)
    elseif stream.name == 'admin' then
        ClientSend.sendChatMessage(command, language, playerColor, 'admin', pitch, false)
    elseif stream.name == 'ooc' then
        ClientSend.sendChatMessage(command, language, playerColor, 'ooc', pitch, false)
    else
        return false
    end
    if TicsServerSettings ~= nil
        and TicsServerSettings[stream.name] ~= nil
        and TicsServerSettings[stream.name]['zombieRange'] ~= nil
        and TicsServerSettings[stream.name]['zombieRange'] ~= -1
    then
        local zombieRange = TicsServerSettings[stream.name]['zombieRange']
        local square = getPlayer():getSquare()
        addSound(getPlayer(), square:getX(), square:getY(), square:getZ(), zombieRange, zombieRange)
    end
    return true
end

local function RemoveLeadingSpaces(text)
    local trailingCount = 0
    for index = 1, #text do
        if text:byte(index) ~= 32 then -- 32 is ASCII code for space ' '
            break
        end
        trailingCount = trailingCount + 1
    end
    return text:sub(trailingCount)
end

local function GetArgumentsFromMessage(ticsCommand, message)
    local command = message:match('^/%a+')
    if #message < #command + 2 then -- command + space + chars
        return nil
    end
    local arguments = message:sub(#command + 2)
    arguments = RemoveLeadingSpaces(arguments)
    if #arguments == 0 then
        return nil
    end
    return arguments
end

local function UpdatePlayerColor(newColor)
    local currentColor = ISChat.instance.ticsModData['playerColor']
    SetPlayerColor(newColor)
    ISChat.sendInfoToCurrentTab('player color updated to '
        .. StringFormat.color(newColor)
        .. ' from '
        .. StringFormat.color(currentColor))
end

-- "/color" without a value: color picker set to the current color, above the chat window
local function OpenPlayerColorPicker()
    local chat = ISChat.instance
    if chat.playerColorPicker then
        chat.playerColorPicker:removeSelf()
    end
    local current = chat.ticsModData['playerColor']
    local initial = ColorInfo.new()
    initial:set(current[1] / 255, current[2] / 255, current[3] / 255, 1.0)

    local picker = TicsColorPicker:new(0, 0, initial)
    picker:initialise()
    picker.keepOnScreen = true
    picker.pickedFunc = function(_, color)
        UpdatePlayerColor({
            math.floor(color.r * 255 + 0.5),
            math.floor(color.g * 255 + 0.5),
            math.floor(color.b * 255 + 0.5),
        })
        picker:removeSelf()
        chat.playerColorPicker = nil
    end
    picker:addToUIManager()
    picker:setX(chat:getAbsoluteX())
    picker:setY(math.max(0, chat:getAbsoluteY() - picker:getHeight() - 4))
    picker:setAlwaysOnTop(true)
    -- set once the sliders exist so they move to the current color too
    picker:setInitialColor(initial)
    chat.playerColorPicker = picker
end

local function ProcessColorCommand(arguments)
    local currentColor = ISChat.instance.ticsModData['playerColor']
    if arguments == nil then
        ISChat.sendInfoToCurrentTab('color value is ' .. StringFormat.color(currentColor))
        OpenPlayerColorPicker()
        return true
    end
    local newColor = StringParser.rgbStringToRGB(arguments) or StringParser.hexaStringToRGB(arguments)
    if newColor == nil then
        return false
    end
    UpdatePlayerColor(newColor)
    return true
end

local function ProcessPitchCommand(arguments)
    if arguments == nil then
        ISChat.sendInfoToCurrentTab('pitch value is ' .. ISChat.instance.ticsModData['voicePitch'])
        return true
    end
    local regex = '^(%d+.?%d*) *$'
    local valueAsText = arguments:match(regex)
    if valueAsText then
        local value = tonumber(valueAsText)
        if value ~= nil and value >= 0.85 and value <= 1.45 then
            local currentPitch = ISChat.instance.ticsModData['voicePitch']
            SetPlayerPitch(value)
            ISChat.sendInfoToCurrentTab('pitch value updated to ' .. value .. ' from ' .. currentPitch)
            return true
        end
    end
    return false
end

local function ProcessRollCommand(arguments)
    if arguments == nil then
        return false
    end
    local regex = '^(%d*)d(%d+)(%+?)(%d*) *$'
    local m1, m2, m3, m4 = arguments:match(regex)
    local diceCount = tonumber(m1)
    local diceType = tonumber(m2)
    local hasPlus = m3 == '+'
    local addCount = tonumber(m4)
    if diceType == nil or diceType < 1 then
        return false
    end
    if diceCount == nil then
        diceCount = 1
    end
    if diceCount < 1 or diceCount > 20 or (hasPlus and addCount == nil) then
        return false
    end
    ClientSend.sendRoll(diceCount, diceType, addCount)
    return true
end

local function ProcessLanguageCommand(arguments)
    if not TicsServerSettings or not TicsServerSettings['options']['languages'] then
        ISChat.sendErrorToCurrentTab(
            getText('UI_TICS_Messages_languages_disabled'))
        return true
    end
    if arguments == nil then
        local knownLanguages = LanguageManager:getKnownLanguages()
        local knownLanguagesFormatted = ''
        local first = true
        for _, languageCode in pairs(knownLanguages) do
            if not first then
                knownLanguagesFormatted = knownLanguagesFormatted .. ', '
            end
            knownLanguagesFormatted = knownLanguagesFormatted .. languageCode
            first = false
        end
        local currentLanguage = LanguageManager:getCurrentLanguage()
        local currentLanguageCode = LanguageManager.GetCodeFromLanguage(currentLanguage)
        local currentLanguageTranslated = LanguageManager.GetLanguageTranslated(currentLanguage)
        ISChat.sendInfoToCurrentTab(
            getText('UI_TICS_Messages_current_language',
                currentLanguageTranslated,
                currentLanguageCode))
        ISChat.sendInfoToCurrentTab(getText('UI_TICS_Messages_known_languages', knownLanguagesFormatted))
        return true
    end
    local regex = '^(%a%a) *$'
    local languageCode = arguments:match(regex)
    if languageCode == nil then
        return false
    end
    if not LanguageManager:isCodeKnown(languageCode) then
        ISChat.sendErrorToCurrentTab(getText('UI_TICS_Messages_unknown_language_code', languageCode))
        return true
    end
    LanguageManager:setCurrentLanguageFromCode(languageCode)
    local languageTranslated = LanguageManager.GetLanguageTranslatedFromCode(languageCode)
    ISChat.sendInfoToCurrentTab(getText('UI_TICS_Messages_language_set_to', languageTranslated))
    return true
end

local function ProcessTicsCommand(ticsCommand, message)
    local arguments = GetArgumentsFromMessage(ticsCommand, message)
    if ticsCommand['name'] == 'color' then
        if ProcessColorCommand(arguments) == false then
            ISChat.sendErrorToCurrentTab(
                'color command expects the format: "/color value" with value as 255, 255, 255 or #FFFFFF')
            return false
        end
    elseif ticsCommand['name'] == 'pitch' then
        if ProcessPitchCommand(arguments) == false then
            ISChat.sendErrorToCurrentTab('pitch command expects the format: "/pitch value" with value from 0.85 to 1.45')
            return false
        end
    elseif ticsCommand['name'] == 'roll' then
        if ProcessRollCommand(arguments) == false then
            ISChat.sendErrorToCurrentTab(
                'roll command expects the format: "/roll xdy" with x and y numbers and x from 1 to 20')
            return false
        end
    elseif ticsCommand['name'] == 'language' then
        if ProcessLanguageCommand(arguments) == false then
            ISChat.sendErrorToCurrentTab(
                'language command expects the format: "/language en" with "en" the language code')
            return false
        end
    end
end

function ISChat:onCommandEntered()
    local command = ISChat.instance:getInputText()
    local chat = ISChat.instance

    ISChat.instance:unfocus(true) -- the message is sent, nothing to keep
    if not command or command == '' then
        return
    end

    local fullCommand = command -- with the channel command, for the history
    local stream, commandName = GetCommandFromMessage(command)
    local ticsCommand = GetTicsCommandFromMessage(command)
    if stream then -- chat message
        if #commandName > 0 and #command >= #commandName then
            -- removing the command and trailing space '/command '
            command = string.sub(command, #commandName + 1)
        end
        if IsOnlySpacesOrEmpty(command) then
            return
        end
        if not ProcessChatCommand(stream, command) then
            return
        end
        chat.chatText.lastChatCommand = commandName
        chat:logChatCommand(fullCommand)
    elseif ticsCommand ~= nil then
        ProcessTicsCommand(ticsCommand, command)
    elseif luautils.stringStarts(command, '/') then -- server command
        SendCommandToServer(command)
        chat:logChatCommand(command)
    end

    doKeyPress(false)
    ISChat.instance.timerTextEntry = 20
end

-- same translated label as the channel label of the input box
local function GetChannelLabel(channel)
    local key = 'UI_TICS_chip_' .. channel
    local label = getText(key)
    if label == nil or label == key then
        label = channel:sub(1, 1):upper() .. channel:sub(2)
    end
    return label
end

-- Messages are aligned on a column after the timestamp: its x is given to the layout with a
-- <TICSCOL:x> marker (ISTicsRichTextPanel), wrapped lines are indented to it.
local columnCache = {}

local function GetChatColumnX(fontSize)
    local chat = ISChat.instance
    if not (chat and chat.showTimestamp) then
        return 0
    end
    local cacheKey = tostring(fontSize)
    if columnCache[cacheKey] then
        return columnCache[cacheKey]
    end
    -- same fonts as FontStringToEnum (defined further down)
    local font = UIFont.Large
    if fontSize == 'small' then
        font = UIFont.NewSmall
    elseif fontSize == 'medium' or fontSize == nil then
        font = UIFont.Medium
    end
    local textManager = getTextManager()
    -- measured like the layout measures chunks (leading space, full advance) plus a space
    local x = textManager:MeasureStringX(font, ' 00:00 ') + textManager:MeasureStringX(font, '  ')
    columnCache[cacheKey] = x
    return x
end

local function BuildColumnMarker(fontSize)
    local x = GetChatColumnX(fontSize)
    if x <= 0 then
        return ''
    end
    return '<TICSCOL:' .. x .. '>'
end

local function BuildChannelPrefixString(channel)
    if channel == nil then
        return ''
    end
    local color
    if TicsServerSettings ~= nil and TicsServerSettings[channel] and TicsServerSettings[channel]['color'] then
        color = TicsServerSettings[channel]['color']
    else
        color = { 255, 255, 255 }
    end
    -- drawn as a label (box behind the text) like the channel label of the input box,
    -- the <TICSCHIP> marker is handled by ISTicsRichTextPanel and ChatText
    return '<TICSCHIP>' .. StringBuilder.BuildBracketColorString(color) .. GetChannelLabel(channel) .. ' '
end


local function BuildLanguagePrefixString(languageCode)
    if languageCode == nil then
        return ''
    end
    local color = { 162, 162, 185 }
    return StringBuilder.BuildBracketColorString(color) .. '(' .. languageCode .. ') '
end

local function FontStringToEnum(fontString)
    if fontString == 'small' then
        return UIFont.NewSmall
    elseif fontString == 'medium' then
        return UIFont.Medium
    else
        return UIFont.Large
    end
end

function ISChat:updateChatPrefixSettings()
    updateChatSettings(self.chatFont, self.showTimestamp, self.showTitle)
    for tabNumber, chatText in pairs(self.tabs) do
        chatText.firstPrintableLine = 1
        chatText.text = ""
        local newText = ""
        chatText.chatTextLines = {}
        chatText.chatTextRawLines = chatText.chatTextRawLines or {}
        chatText.defaultFont = FontStringToEnum(self.chatFont or 'medium')
        for i, msg in ipairs(chatText.chatTextRawLines) do
            self.chatFont = self.chatFont or 'medium'
            local showLanguage = TicsServerSettings and TicsServerSettings['options']['languages']
            local line = BuildChatMessage(self.chatFont, self.showTimestamp, self.showTitle, showLanguage, msg.language,
                msg.line, msg.time, msg.channel)
            line = line .. StringBuilder.BuildNewLine()
            table.insert(chatText.chatTextLines, line)
            if i == #chatText.chatTextRawLines then
                line = string.gsub(line, "<LINE>$", "")
            end
            newText = newText .. line
        end
        chatText.text = newText
        chatText:paginate()
        chatText:scrollToBottom()
    end
end

local MessageTypeToColor = {
    ['whisper'] = { 130, 200, 200 },
    ['low'] = { 180, 230, 230 },
    ['say'] = { 255, 255, 255 },
    ['yell'] = { 230, 150, 150 },
    ['radio'] = { 144, 122, 176 },
    ['pm'] = { 255, 149, 211 },
    ['faction'] = { 100, 255, 66 },
    ['safehouse'] = { 220, 255, 80 },
    ['general'] = { 109, 111, 170 },
    ['admin'] = { 230, 130, 111 },
    ['ooc'] = { 146, 255, 148 },
}

function BuildColorFromMessageType(type)
    if TicsServerSettings ~= nil
        and TicsServerSettings[type]
        and TicsServerSettings[type]['color']
    then
        return TicsServerSettings[type]['color']
    elseif MessageTypeToColor[type] == nil then
        error('unknown message type "' .. type .. '"')
    end
    return MessageTypeToColor[type]
end

local MessageTypeToVerb = {
    ['whisper'] = ' whispers, ',
    ['low'] = ' says quietly, ',
    ['say'] = ' says, ',
    ['yell'] = ' yells, ',
    ['radio'] = ' over the radio, ',
    ['scriptedRadio'] = 'over the radio, ',
    ['pm'] = ' ',
    ['faction'] = ' ',
    ['safehouse'] = ' ',
    ['general'] = ' ',
    ['admin'] = ' ',
    ['ooc'] = ' ',
}

function BuildVerbString(type)
    if MessageTypeToVerb[type] == nil then
        error('unknown message type "' .. type .. '"')
    end
    return MessageTypeToVerb[type]
end

local NoQuoteTypes = {
    ['general'] = true,
    ['safehouse'] = true,
    ['faction'] = true,
    ['admin'] = true,
    ['pm'] = true,
    ['ooc'] = true,
}

function BuildQuote(type)
    if NoQuoteTypes[type] == true then
        return ''
    end
    return '"'
end

local function BuildPlayerNameString(playerName, playerColor)
    return StringBuilder.BuildBracketColorString(playerColor) .. playerName
end

function BuildMessageFromPacket(type, message, name, playerColor, frequency, disableVerb)
    local messageColor = BuildColorFromMessageType(type)
    local parsedMessage = Parser.ParseTicsMessage(message, messageColor, 20, 200)
    local radioPrefix = ''
    if frequency then
        radioPrefix = '(' .. string.format('%.1fMHz', frequency / 1000) .. ') '
    end
    local messageColorString = StringBuilder.BuildBracketColorString(messageColor)
    local quote
    local verbString
    if not disableVerb and (TicsServerSettings == nil or TicsServerSettings['options']['verb'] == true)
        and type ~= 'do' and type ~= 'me'
    then
        quote = BuildQuote(type)
        verbString = BuildVerbString(type)
    else
        quote = ''
        verbString = ' '
    end
    local formatedMessage = ''
    if type == 'do' then
        formatedMessage = formatedMessage .. '** '
    elseif type == 'me' then
        formatedMessage = formatedMessage .. '* '
    end
    if name ~= nil and type ~= 'do' then
        formatedMessage = formatedMessage .. BuildPlayerNameString(name, playerColor)
    end
    formatedMessage = formatedMessage ..
        StringBuilder.BuildBracketColorString({ 150, 150, 150 }) ..
        verbString ..
        radioPrefix .. messageColorString .. quote .. parsedMessage.body .. messageColorString .. quote
    return formatedMessage, parsedMessage
end

function BuildChatMessage(fontSize, showTimestamp, showTitle, showLanguage, language, rawMessage, time, channel)
    local line = StringBuilder.BuildFontSizeString(fontSize)
    if showTimestamp and time then
        line = line .. StringBuilder.BuildTimePrefixString(time)
    end
    line = line .. BuildColumnMarker(fontSize)
    if showTitle and channel ~= nil then
        line = line .. BuildChannelPrefixString(channel)
    end
    if showLanguage and language and language ~= LanguageManager.DefaultLanguage then
        local languageCode = LanguageManager.GetCodeFromLanguage(language)
        line = line .. BuildLanguagePrefixString(languageCode)
    end
    line = line .. rawMessage
    return line
end

function CreatePlayerBubble(author, type, message, color, voiceEnabled, voicePitch, showPlayerName, authorName,
                            authorColor, title)
    ISChat.instance.bubble = ISChat.instance.bubble or {}
    ISChat.instance.typingDots = ISChat.instance.typingDots or {}
    if author == nil then
        print('TICS error: CreatePlayerBubble: author is null')
        return
    end
    local authorObj = World.getPlayerByUsername(author)
    if authorObj == nil then
        print('TICS error: CreatePlayerBubble: author not found ' .. author)
        return
    end
    local timer = 10
    local opacity = 70
    if TicsServerSettings then
        timer = TicsServerSettings['options']['bubble']['timer']
        opacity = TicsServerSettings['options']['bubble']['opacity']
    end
    local portrait = (TicsServerSettings and ISChat.instance.isPortraitEnabled and TicsServerSettings['options']['portrait'])
        or 1
    local isAction = type == 'me'
    if type ~= 'do' then
        if ISChat.instance.bubble[author] then
            ISChat.instance.bubble[author].dead = true
        end
        ISChat.instance.bubble[author] = PlayerBubble:new(
            authorObj, isAction, message, color, timer, opacity, voiceEnabled, voicePitch, portrait, showPlayerName,
            authorName, authorColor, title)
    else
        if ISChat.instance.contextBubble then
            ISChat.instance.contextBubble.dead = true
        end
        ISChat.instance.contextBubble = ContextBubble:new(message, color, timer, opacity, voiceEnabled, voicePitch)
    end
    -- the player is not typing anymore if his bubble appears
    if ISChat.instance.typingDots[author] ~= nil then
        ISChat.instance.typingDots[author] = nil
    end
end

local function CreateSquareRadioBubble(position, message, messageColor, voicePitch)
    ISChat.instance.radioBubble = ISChat.instance.radioBubble or {}
    if position ~= nil then
        local x, y, z = position['x'], position['y'], position['z']
        if x == nil or y == nil or z == nil then
            print('TICS error: CreateSquareRadioBubble: nil position for a square radio')
            return
        end
        x, y, z = math.abs(x), math.abs(y), math.abs(z)
        if ISChat.instance.radioBubble['x' .. x .. 'y' .. y .. 'z' .. z] ~= nil then
            ISChat.instance.radioBubble['x' .. x .. 'y' .. y .. 'z' .. z].dead = true
        end
        local timer = 10
        local opacity = 70
        local square = getSquare(x, y, z)
        local radios = World.getSquareItemsByGroup(square, 'IsoRadio')
        local offsetY = 0
        if radios ~= nil and #radios > 0 then
            local radio = radios[1]
            offsetY = radio:getRenderYOffset()
        end
        local bubble = RadioBubble:new(
            square, message, messageColor, timer, opacity, RadioBubble.types.square,
            ISChat.instance.isVoiceEnabled, voicePitch, offsetY)
        ISChat.instance.radioBubble['x' .. x .. 'y' .. y .. 'z' .. z] = bubble
    end
end

function CreatePlayerRadioBubble(author, message, messageColor, voicePitch)
    ISChat.instance.playerRadioBubble = ISChat.instance.playerRadioBubble or {}
    if author == nil then
        print('TICS error: CreatePlayerRadioBubble: author is null')
        return
    end
    local authorObj = World.getPlayerByUsername(author)
    if authorObj == nil then
        print('TICS error: CreatePlayerRadioBubble: author not found ' .. author)
        return
    end
    local timer = 10
    local opacity = 70
    if TicsServerSettings then
        timer = TicsServerSettings['options']['bubble']['timer']
        opacity = TicsServerSettings['options']['bubble']['opacity']
    end
    local bubble = RadioBubble:new(authorObj, message, messageColor, timer, opacity,
        RadioBubble.types.player, ISChat.instance.isVoiceEnabled, voicePitch)
    ISChat.instance.playerRadioBubble[author] = bubble
end

function CreateVehicleRadioBubble(vehicle, message, messageColor, voicePitch)
    ISChat.instance.vehicleRadioBubble = ISChat.instance.vehicleRadioBubble or {}
    local timer = 10
    local opacity = 70
    if TicsServerSettings then
        timer = TicsServerSettings['options']['bubble']['timer']
        opacity = TicsServerSettings['options']['bubble']['opacity']
    end
    local keyId = vehicle:getKeyId()
    if keyId == nil then
        print('TICS error: CreateVehicleBubble: key id is null')
        return
    end
    local bubble = RadioBubble:new(vehicle, message, messageColor, timer, opacity,
        RadioBubble.types.vehicle, ISChat.instance.isVoiceEnabled, voicePitch)
    ISChat.instance.vehicleRadioBubble[keyId] = bubble
end

function ISChat.onTypingPacket(author, type)
    ISChat.instance.typingDots = ISChat.instance.typingDots or {}
    local onlineUsers = getOnlinePlayers()
    local authorObj = nil
    for i = 0, onlineUsers:size() - 1 do
        local user = onlineUsers:get(i)
        if user:getUsername() == author then
            authorObj = onlineUsers:get(i)
            break
        end
    end
    if authorObj == nil then
        return
    end
    if ISChat.instance.typingDots[author] then
        ISChat.instance.typingDots[author]:refresh()
    else
        ISChat.instance.typingDots[author] = TypingDots:new(authorObj, 1)
    end
end

local function GetStreamFromType(type)
    for _, stream in ipairs(ISChat.allChatStreams) do
        if type == stream['name'] then
            return stream
        end
    end
    return nil
end

-- in-character lines go to the RP log and to the journal (scenes of the people around)
local function RecordInCharacterLine(channel, language, formattedMessage, author, characterName, isRadio)
    local text = RpLog.inCharacterText(channel, language, formattedMessage)
    if text == nil then
        return
    end
    local ok, err = pcall(RpLog.write, text)
    if not ok then
        print('TICS error: RpLog: ' .. tostring(err))
    end
    ok, err = pcall(Journal.addLine, text, author, characterName, isRadio)
    if not ok then
        print('TICS error: Journal: ' .. tostring(err))
    end
end

local function AddMessageToTab(tabID, language, time, formattedMessage, line, channel, author, characterName, isRadio)
    RecordInCharacterLine(channel, language, formattedMessage, author, characterName, isRadio)
    if not ISChat.instance.chatText then
        ISChat.instance.chatText = ISChat.instance.defaultTab
        ISChat.instance:onActivateView()
    end
    local chatText = ISChat.instance.tabs[tabID]

    chatText.chatTextRawLines = chatText.chatTextRawLines or {}
    table.insert(chatText.chatTextRawLines,
        {
            time = time,
            line = formattedMessage,
            channel = channel,
            language = language,
        })
    local chatTextRawLinesSize = #chatText.chatTextRawLines
    local maxRawMessages = chatText.maxLines
    if chatTextRawLinesSize > maxRawMessages then
        local newRawLines = {}
        for i = chatTextRawLinesSize - maxRawMessages, chatTextRawLinesSize do
            table.insert(newRawLines, chatText.chatTextRawLines[i])
        end
        chatText.chatTextRawLines = newRawLines
    end
    if chatText.tabTitle ~= ISChat.instance.chatText.tabTitle then
        local alreadyExist = false
        for _, blinkedTab in pairs(ISChat.instance.panel.blinkTabs) do
            if blinkedTab == chatText.tabTitle then
                alreadyExist = true
                break
            end
        end
        if alreadyExist == false then
            table.insert(ISChat.instance.panel.blinkTabs, chatText.tabTitle)
        end
    end
    -- follow the new messages only if the player did not scroll up
    local scrolledToBottom = chatText.followBottom ~= false
    if #chatText.chatTextLines > ISChat.maxLine then
        local newLines = {}
        for i, v in ipairs(chatText.chatTextLines) do
            if i ~= 1 then
                table.insert(newLines, v)
            end
        end
        table.insert(newLines, line .. StringBuilder.BuildNewLine())
        chatText.chatTextLines = newLines
    else
        table.insert(chatText.chatTextLines, line .. StringBuilder.BuildNewLine())
    end
    chatText.text = ''
    local newText = ''
    local chatTextLinesCount = #chatText.chatTextLines
    for i, v in ipairs(chatText.chatTextLines) do
        if i == chatTextLinesCount then
            v = string.gsub(v, '<LINE>$', '')
        end
        newText = newText .. v
    end
    chatText.text = newText
    chatText:paginate()
    if scrolledToBottom then
        chatText:scrollToBottom()
    end
end

local function ReduceBoredom()
    local player = getPlayer()
    if player:getStats() == nil then
        return
    end
    local boredom = player:getStats():get(CharacterStat.BOREDOM)
    local boredomReduction = 0
    if TicsServerSettings then
        boredomReduction = TicsServerSettings['options']['boredomReduction']
    end
    player:getStats():add(CharacterStat.BOREDOM, boredom - boredomReduction)
    if getCore():getDebug() then
            player:setHaloNote("Boredom " .. tostring(player:getStats():get(CharacterStat.BOREDOM)));
    end
end

function ISChat.onDiceResult(author, characterName, diceCount, diceType, addCount, diceResults, finalResult)
    local name = characterName
    if TicsServerSettings and not TicsServerSettings['options']['showCharacterName'] then
        name = author
    end
    local message = name .. ' rolled ' .. diceCount .. 'd' .. diceType
    if addCount ~= nil then
        message = message .. '+' .. addCount
    end
    message = message .. ' ('
    local first = true
    for _, r in pairs(diceResults) do
        if first then
            first = false
        else
            message = message .. ', '
        end
        message = message .. r
    end
    message = message .. ')'
    if addCount ~= nil then
        message = message .. '+' .. addCount
    end
    message = message .. ' = ' .. finalResult
    RecordInCharacterLine('roll', nil, message, author, characterName)
    ISChat.sendInfoToCurrentTab(message)
end

local function CapitalizeAndPonctuate(message)
    message = message:gsub("^%l", string.upper)
    local lastChar = string.sub(message, message:len())
    if not (lastChar == "." or lastChar == "!" or lastChar == "?") then
        message = message .. "."
    end
    return message
end

function ISChat.onMessagePacket(type, author, characterName, message, language, color, hideInChat, target, isFromDiscord,
                                voicePitch, disableVerb, title)
    if author ~= getPlayer():getUsername() then
        ReduceBoredom()
    end
    local name = characterName
    if TicsServerSettings and not TicsServerSettings['options']['showCharacterName'] then
        name = author
    end

    local updatedMessage = message
    if TicsServerSettings ~= nil and TicsServerSettings['options']['capitalize'] == true then
        updatedMessage = CapitalizeAndPonctuate(updatedMessage)
    end
    if type == 'pm' and target:lower() == getPlayer():getUsername():lower() then
        ISChat.instance.lastPrivateMessageAuthor = author
    end
    ISChat.instance.chatFont = ISChat.instance.chatFont or 'medium'
    local showLanguage = TicsServerSettings and TicsServerSettings['options']['languages']
    local showBubble = TicsServerSettings and TicsServerSettings[type] and TicsServerSettings[type]['bubble']
    if not isFromDiscord and voicePitch ~= nil and showBubble then
        if showLanguage and not LanguageManager:isKnown(language) and type ~= 'me' and type ~= 'do' then
            updatedMessage = LanguageManager:getRandomMessage(updatedMessage)
        end
        -- ooc should not distract the RP with voices
        local voiceEnabled = ISChat.instance.isVoiceEnabled and type ~= 'ooc'
        CreatePlayerBubble(author, type, updatedMessage, BuildColorFromMessageType(type), voiceEnabled, voicePitch,
            type == 'me', name, color, title)
    end
    local formattedMessage, parsedMessage = BuildMessageFromPacket(type, updatedMessage, name, color, nil, disableVerb)
    local time = Calendar.getInstance():getTimeInMillis()
    local line = BuildChatMessage(ISChat.instance.chatFont, ISChat.instance.showTimestamp, ISChat.instance.showTitle,
        showLanguage, language, formattedMessage, time, type)
    local stream = GetStreamFromType(type)
    if stream == nil then
        print('TICS error: onMessagePacket: stream not found')
        return
    end
    if not hideInChat then
        AddMessageToTab(stream['tabID'], language, time, formattedMessage, line, stream['name'], author, characterName)
    end
end

function BuildServerMessage(fontSize, showTimestamp, showTitle, rawMessage, time, channel)
    local line = StringBuilder.BuildFontSizeString(fontSize)
    if showTimestamp then
        line = line .. StringBuilder.BuildTimePrefixString(time)
    end
    line = line .. BuildColumnMarker(fontSize)
    if showTitle and channel ~= nil then
        line = line .. BuildChannelPrefixString(channel)
    end
    line = line .. rawMessage
    return line
end

function ISChat.onServerMessage(message)
    local color = (TicsServerSettings and TicsServerSettings['server']['color']) or { 255, 86, 64 }
    local time = Calendar.getInstance():getTimeInMillis()
    local stream = GetStreamFromType('general')
    if stream == nil then
        print('TICS error: onServerMessage: stream not found')
        return
    end
    local parsedMessage = Parser.ParseTicsMessage(message, color, 20, 200)
    local line = BuildChatMessage(ISChat.instance.chatFont, ISChat.instance.showTimestamp, ISChat.instance.showTitle,
        false, nil, parsedMessage.body, time, 'server')
    AddMessageToTab(stream['tabID'], nil, time, parsedMessage.body, line, 'server')
end

local function CreateSquaresRadiosBubbles(message, messageColor, squaresInfo, voicePitch)
    if squaresInfo == nil then
        print('TICS error: CreateSquaresRadiosBubbles: squaresInfo table is null')
        return
    end
    for _, info in pairs(squaresInfo) do
        local position = info['position']
        if position ~= nil then
            CreateSquareRadioBubble(position, message, messageColor, voicePitch)
            local square = getSquare(position['x'], position['y'], position['z'])
            if square ~= nil then
                local radio = World.getFirstSquareItem(square, 'IsoRadio')
                if radio ~= nil then
                    local radioData = radio:getDeviceData()
                    if radioData ~= nil then
                        local distance = info['distance']
                        if distance ~= nil then
                            radioData:doReceiveSignal(distance)
                        else
                            print('TICS error: received radio packet for a square radio without distance')
                        end
                    else
                        print('TICS error: received radio packet for a square radio without data')
                    end
                else
                    print('TICS error: received radio packet for a square with no radio')
                end
            else
                print('TICS error: received radio packet for a null square')
            end
        else
            print('TICS error: received radio packet for a square without position')
        end
    end
end

local function CreatePlayersRadiosBubbles(message, messageColor, playersInfo, voicePitch)
    if playersInfo == nil then
        print('TICS error: CreatePlayersRadiosBubbles: playersInfo table is null')
        return
    end
    for _, info in pairs(playersInfo) do
        local username = info['username']
        if username ~= nil then
            CreatePlayerRadioBubble(
                getPlayer():getUsername(), message, messageColor, voicePitch)
            if username:upper() == getPlayer():getUsername():upper() then
                local radio = Character.getFirstHandOrBeltItemByGroup(getPlayer(), 'Radio')
                if radio ~= nil then
                    local radioData = radio:getDeviceData()
                    if radioData ~= nil then
                        local distance = info['distance']
                        if distance ~= nil then
                            radioData:doReceiveSignal(distance)
                        else
                            print('TICS error: received radio packet for a player radio without distance')
                        end
                    else
                        print('TICS error: received radio packet for a player radio without data')
                    end
                else
                    print('TICS error: received radio packet for a player with no radio in hand')
                end
            end
        else
            print('TICS error: received radio packet for a player without username')
        end
    end
end

local function CreateVehiclesRadiosBubbles(message, messageColor, vehiclesInfo, voicePitch)
    if vehiclesInfo == nil then
        print('TICS error: CreateVehiclesRadiosBubbles: vehiclesKeyIds table is null')
        return
    end
    local range = (TicsServerSettings and TicsServerSettings['say']['range']) or 15
    local vehicles = World.getVehiclesInRange(getPlayer(), range)
    for _, info in pairs(vehiclesInfo) do
        local vehicleKeyId = info['key']
        if vehicleKeyId ~= nil then
            local vehicle = vehicles[vehicleKeyId]
            if vehicle ~= nil then
                CreateVehicleRadioBubble(vehicle, message, messageColor, voicePitch)
                local radio = vehicle:getPartById('Radio')
                if radio ~= nil then
                    local radioData = radio:getDeviceData()
                    if radioData ~= nil then
                        local distance = info['distance']
                        if distance ~= nil then
                            radioData:doReceiveSignal(distance)
                        else
                            print('TICS error: received radio packet for a vehicle radio without distance')
                        end
                    else
                        print('TICS error: received radio packet for a vehicle radio without data')
                    end
                else
                    print('TICS error: received radio packet for a vehicle with no radio')
                end
            else
                print('TICS error: CreateVehiclesRadiosBubble: vehicle not found for key id ' .. vehicleKeyId)
            end
        else
            print('TICS error: received vehicle packet for a vehicle with no key')
        end
    end
end

function ISChat.onDiscordPacket(message)
    processGeneralMessage(message)
end

function ISChat.onRadioEmittingPacket(type, author, characterName, message, language, color, frequency, disableVerb)
    local time = Calendar.getInstance():getTimeInMillis()
    local stream = GetStreamFromType(type)
    if stream == nil then
        print('TICS error: onRadioEmittingPacket: stream not found')
        return
    end
    local name = characterName
    if TicsServerSettings and not TicsServerSettings['options']['showCharacterName'] then
        name = author
    end
    local cleanMessage = message
    if TicsServerSettings ~= nil and TicsServerSettings['options']['capitalize'] == true then
        cleanMessage = CapitalizeAndPonctuate(message)
    end
    local formattedMessage, parsedMessages = BuildMessageFromPacket(type, cleanMessage, name, color, frequency,
        disableVerb)
    local showLanguage = TicsServerSettings and TicsServerSettings['options']['languages']
    local line = BuildChatMessage(ISChat.instance.chatFont, ISChat.instance.showTimestamp, ISChat.instance.showTitle,
        showLanguage, language, formattedMessage, time, type)
    AddMessageToTab(stream['tabID'], language, time, formattedMessage, line, stream['name'], author, characterName, true)
end

function ISChat.onRadioPacket(type, author, characterName, message, language, color, radiosInfo, voicePitch, disableVerb)
    local time = Calendar.getInstance():getTimeInMillis()
    local stream = GetStreamFromType(type)
    if stream == nil then
        print('TICS error: onRadioPacket: stream not found')
        return
    end

    local playerName = getPlayer():getUsername()
    if author ~= playerName then
        ReduceBoredom()
    end
    local name = characterName
    if TicsServerSettings and not TicsServerSettings['options']['showCharacterName'] then
        name = author
    end
    local updatedMessage = message
    if TicsServerSettings ~= nil and TicsServerSettings['options']['capitalize'] == true then
        updatedMessage = CapitalizeAndPonctuate(updatedMessage)
    end
    local showLanguage = TicsServerSettings and TicsServerSettings['options']['languages']
    for frequency, radios in pairs(radiosInfo) do
        if showLanguage and not LanguageManager:isKnown(language) then
            updatedMessage = LanguageManager:getRandomMessage(updatedMessage)
        end
        local messageColor = BuildColorFromMessageType(type)
        CreateSquaresRadiosBubbles(updatedMessage, messageColor, radios['squares'], voicePitch)
        CreatePlayersRadiosBubbles(updatedMessage, messageColor, radios['players'], voicePitch)
        CreateVehiclesRadiosBubbles(updatedMessage, messageColor, radios['vehicles'], voicePitch)

        local formattedMessage, parsedMessages = BuildMessageFromPacket(type, updatedMessage, name, color, frequency,
            disableVerb)
        local line = BuildChatMessage(ISChat.instance.chatFont, ISChat.instance.showTimestamp, ISChat.instance.showTitle,
            showLanguage, language, formattedMessage, time, type)
        -- a special packet is making sure the author always has a radio feedback in the chat
        -- useful in case the listening range and emitting range of the radio differs
        -- this is to avoid any confusion from players thinking the radios mights not work
        if author ~= playerName then
            AddMessageToTab(stream['tabID'], language, time, formattedMessage, line, stream['name'], author,
                characterName, true)
        end
    end
end

function ISChat.sendInfoToCurrentTab(message)
    local time = Calendar.getInstance():getTimeInMillis()
    local formattedMessage = StringBuilder.BuildBracketColorString({ 70, 70, 255 }) .. message
    local line = BuildChatMessage(ISChat.instance.chatFont, ISChat.instance.showTimestamp, false,
        false, nil, formattedMessage, time, nil)
    local tabID = ISChat.defaultTabStream[ISChat.instance.currentTabID]['tabID']
    AddMessageToTab(tabID, nil, time, formattedMessage, line, nil)
end

function ISChat.sendErrorToCurrentTab(message)
    local time = Calendar.getInstance():getTimeInMillis()
    local formattedMessage = StringBuilder.BuildBracketColorString({ 255, 40, 40 }) ..
        'error: ' .. StringBuilder.BuildBracketColorString({ 255, 70, 70 }) .. message
    local line = BuildChatMessage(ISChat.instance.chatFont, ISChat.instance.showTimestamp, false,
        false, nil, formattedMessage, time, nil)
    local tabID = ISChat.defaultTabStream[ISChat.instance.currentTabID]['tabID']
    AddMessageToTab(tabID, nil, time, formattedMessage, line, nil)
end

function ISChat.onChatErrorPacket(type, message)
    local time = Calendar.getInstance():getTimeInMillis()
    local formattedMessage = StringBuilder.BuildBracketColorString({ 255, 50, 50 }) ..
        'error: ' .. StringBuilder.BuildBracketColorString({ 255, 60, 60 }) .. message
    local line = BuildChatMessage(ISChat.instance.chatFont, ISChat.instance.showTimestamp, ISChat.instance.showTitle,
        false, nil, formattedMessage, time, type)
    local stream
    if type == nil then
        stream = ISChat.defaultTabStream[ISChat.instance.currentTabID]
    else
        stream = GetStreamFromType(type)
        if stream == nil then
            stream = ISChat.defaultTabStream[ISChat.instance.currentTabID]
        end
    end
    AddMessageToTab(stream['tabID'], nil, time, formattedMessage, line)
end

local function GetMessageType(message)
    if message.toString == nil then
        return nil
    end
    local stringRep = message:toString()
    return stringRep:match('^ChatMessage{chat=(%a*),')
end

local function GenerateRadiosPacketFromListeningRadiosInRange(frequency)
    if TicsServerSettings == nil then
        return nil
    end
    local maxSoundRange = TicsServerSettings['options']['radio']['soundMaxRange']
    local radios = FakeRadioPacket.getListeningRadiosPositions(getPlayer(), maxSoundRange, frequency)
    if radios == nil then
        return nil
    end
    return {
        [frequency] = radios
    }
end

local function RemoveDiscordMessagePrefix(message)
    local regex = '<@%d+>(.*)'
    return message:match(regex)
end

-- TODO: try to clean this mess copied from the base game
ISChat.addLineInChat = function(message, tabID)
    if UdderlyUpToDate and
        message.setOverHeadSpeech == nil and
        message.isFromDiscord == nil and
        message.getDatetimeStr == nil
    then -- probably a fake message from UdderlyUpToDate mod
        ISChat.sendErrorToCurrentTab(message:getText())
        return
    end

    local messageType = GetMessageType(message)
    local line = message:getText()
    if messageType == nil then
        ISChat.sendInfoToCurrentTab(line)
        return
    end

    if message:getAuthor() == 'Server' then
        ISChat.sendInfoToCurrentTab(line)
    elseif message:getRadioChannel() ~= -1 then -- scripted radio message
        local messageWithoutColorPrefix = message:getText():gsub('*%d+,%d+,%d+*', '')
        message:setText(messageWithoutColorPrefix)
        local color = (TicsServerSettings and TicsServerSettings['scriptedRadio']['color']) or {
            171, 240, 140,
        }
        ISChat.onRadioPacket(
            'scriptedRadio',
            nil,
            nil,
            messageWithoutColorPrefix,
            'en',
            color,
            {}, -- todo find a way to locate the radio
            message:getRadioChannel(),
            false
        )
    else
        message:setOverHeadSpeech(false)
    end

    if messageType == 'Local' then -- when pressing Q to shout
        local player = World.getPlayerByUsername(message:getAuthor())
        local firstName, lastName = Character.getFirstAndLastName(player)
        local characterName = firstName .. ' ' .. lastName
        ISChat.onMessagePacket(
            'yell',
            message:getAuthor(),
            characterName,
            line,
            LanguageManager.DefaultLanguage,
            { 255, 255, 255 },
            TicsServerSettings and TicsServerSettings['options'] and
            TicsServerSettings['options']['hideCallout'] or nil,
            nil,
            false,
            ISChat.instance.ticsModData['voicePitch'],
            false
        )
    end

    if message:isFromDiscord() then
        local currentDiscordMessage = message:getDatetimeStr() .. message:getText()
        local currentTime = Calendar.getInstance():getTimeInMillis()
        local isDuplicate = false
        local toRemove = {}
        for key, discordMessageInfo in pairs(ISChat.instance.lastDiscordMessages) do
            local discordMessage = discordMessageInfo['message']
            local discordMessageTime = discordMessageInfo['time']
            if currentTime - discordMessageTime < 2000 then
                if discordMessage == currentDiscordMessage then
                    isDuplicate = true
                end
            else
                table.insert(toRemove, key)
            end
        end
        for _, key in pairs(toRemove) do
            ISChat.instance.lastDiscordMessages[key] = nil
        end
        if isDuplicate then
            return
        end
        table.insert(ISChat.instance.lastDiscordMessages, {
            message = currentDiscordMessage,
            time = currentTime
        })
        local discordColor = { 88, 101, 242 } -- discord logo color
        local messageWithoutPrefix = RemoveDiscordMessagePrefix(line)
        if messageWithoutPrefix == nil then
            -- for some reason some servers receive discord messages without the @discord-id-of-bot prefix
            messageWithoutPrefix = line
        end
        if TicsServerSettings and TicsServerSettings['general']
            and TicsServerSettings['general']['discord']
            and TicsServerSettings['general']['enabled']
        then
            ISChat.onMessagePacket(
                'general',
                message:getAuthor(),
                message:getAuthor(),
                messageWithoutPrefix,
                'en',
                discordColor,
                false,
                nil,
                true,
                1.15, -- voice pitch, should not be used anyway
                false
            )
        end
        if TicsServerSettings and TicsServerSettings['options']
            and TicsServerSettings['options']['radio']
            and TicsServerSettings['options']['radio']['discord']
        then
            local frequency = TicsServerSettings['options']['radio']['frequency']
            if frequency then
                local radiosInfo = GenerateRadiosPacketFromListeningRadiosInRange(frequency)
                if radiosInfo ~= nil then
                    ISChat.onRadioPacket(
                        'say',
                        message:getAuthor(),
                        message:getAuthor(),
                        messageWithoutPrefix,
                        'en',
                        discordColor,
                        radiosInfo,
                        1.15,
                        false
                    )
                end
            end
        end
        return
    elseif message:isServerAlert() then
        ISChat.instance.servermsg = ''
        if message:isShowAuthor() then
            ISChat.instance.servermsg = message:getAuthor() .. ': '
        end
        ISChat.instance.servermsg = ISChat.instance.servermsg .. message:getText()
        ISChat.instance.servermsgTimer = 5000
        ISChat.instance.onServerMessage(line)
        return
    else
        return
    end
end

function ISChat:render()
    ChatUI.render(self)
end

function ISChat:makeFade(fraction)
    ChatUI.makeFade(self, fraction)
end

function ISChat:prerender()
    local instance = ISChat.instance

    instance:createValidationWindowButton()
    instance:createCharacterSheetButton()
    instance:updateInputChipBackspace()
    instance:updateInputShortcuts()

    if instance.rangeIndicator ~= nil then
        if instance.rangeButtonState == 'visible' then
            if ISChat.instance.focused then
                instance.rangeIndicator:subscribe()
            else
                instance.rangeIndicator:unsubscribe()
            end
        elseif instance.rangeButtonState == 'hidden' then
            instance.rangeIndicator:unsubscribe()
        else
            instance.rangeIndicator:subscribe()
        end
    end

    local allBubbles = {
        instance.radioBubble,
        instance.vehicleRadioBubble,
        instance.playerRadioBubble,
        instance.bubble,
        instance.typingDots
    }
    for _, bubbles in pairs(allBubbles) do
        local indexToDelete = {}
        for index, bubble in pairs(bubbles) do
            if bubble.dead then
                table.insert(indexToDelete, index)
            else
                bubble:render()
            end
        end
        for _, index in pairs(indexToDelete) do
            bubbles[index] = nil
        end
    end
    if instance.contextBubble then
        instance.contextBubble:render()
    end
    ChatUI.prerender(self)
end

function IsOnlyCommand(text)
    return text:match('/%a* *') == text
end

function ISChat.onTextChange()
    local chat = ISChat.instance
    local t = chat.textEntry
    local typed = t:getInternalText()
    -- "/command " at the start of the text becomes the channel chip
    local chipStream, chipPrefix = FindChipStream(typed)
    if chipStream then
        chat.inputChip = { stream = chipStream, prefix = chipPrefix }
        t:setText(typed:sub(#chipPrefix + 1))
    end
    local internalText = chat:getInputText()
    if #internalText > 1
        and IsOnlyCommand(internalText:sub(1, #internalText - 1))
        and internalText:sub(#internalText) == '/'
    then
        chat:setInputText("/")
        if ISChat.instance.rangeIndicator then
            ISChat.instance.rangeIndicator:unsubscribe()
        end
        ISChat.instance.rangeIndicator = nil
        ISChat.instance.lastStream = nil
        return
    end

    if internalText == '/r' and ISChat.instance.lastPrivateMessageAuthor ~= nil
        and ISChat.instance.currentTabID == 3
    then
        chat:setInputText('/pm ' .. ISChat.instance.lastPrivateMessageAuthor .. ' ')
        return
    end
    local stream = GetCommandFromMessage(internalText)
    if stream ~= nil then
        if ISChat.instance.lastStream ~= stream then
            UpdateRangeIndicator(stream)
        end
        -- you are allowed to use a command from another tab but it wont be remembered for the next message
        -- /me* commands are also not remembered as they should be occasional
        if ISChat.instance.currentTabID == stream['tabID'] and not stream['forget'] then
            ISChat.lastTabStream[ISChat.instance.currentTabID] = stream
        end
        local streamName = stream['name']
        ClientSend.sendTyping(getPlayer():getUsername(), streamName)
    else
        if ISChat.instance.rangeIndicator then
            ISChat.instance.rangeIndicator:unsubscribe()
        end
        ISChat.instance.rangeIndicator = nil
    end
    ISChat.instance.lastStream = stream
end

function ISChat:onActivateView()
    if self.tabCnt > 1 then
        self.chatText = self.panel.activeView.view
    end
    for i, blinkedTab in ipairs(self.panel.blinkTabs) do
        if self.chatText.tabTitle and self.chatText.tabTitle == blinkedTab then
            table.remove(self.panel.blinkTabs, i)
            break
        end
    end
end

local function RenderChatText(chat)
    chat:setStencilRect(0, 0, chat.width, chat.height)
    ChatText.render(chat)
    chat:clearStencilRect()
end

function ISChat:createTab()
    local chatY = self:titleBarHeight() + self.btnHeight + 2 * self.inset
    local chatHeight = self.textEntry:getY() - chatY
    local chatText = ChatText:new(0, chatY, self:getWidth(), chatHeight)
    chatText.maxLines = 100
    chatText:initialise()
    chatText.background = false
    chatText:setAnchorBottom(true)
    chatText:setAnchorRight(true)
    chatText:setAnchorTop(true)
    chatText:setAnchorLeft(true)
    chatText.log = {}
    chatText.logIndex = 0
    chatText.marginTop = ChatTheme.textPaddingTop
    chatText.marginBottom = 0
    chatText.marginLeft = ChatTheme.textPaddingX
    chatText.marginRight = ChatTheme.textPaddingX
    chatText.wrapIndent = ChatTheme.wrapIndent
    chatText.chipPadding = ChatTheme.tagChipPadding
    chatText.chipFont = UIFont.Small
    chatText.onRightMouseUp = nil
    chatText.render = RenderChatText
    chatText.autosetheight = false
    chatText:addScrollBars()
    chatText.vscroll:setVisible(false)
    chatText.vscroll.background = false
    chatText:ignoreHeightChange()
    chatText:setVisible(false)
    chatText.chatTextLines = {}
    chatText.chatMessages = {}
    chatText.onRightMouseUp = ISChat.onRightMouseUp
    chatText.onRightMouseDown = ISChat.onRightMouseDown
    chatText.onMouseUp = ISChat.onMouseUp
    chatText.onMouseDown = ISChat.onMouseDown
    return chatText
end

ISChat.onTabAdded = function(tabTitle, tabID)
    -- callback from the Java
    -- 0 is General
    -- 1 is Admin
    if tabID == 1 then
        if TicsServerSettings ~= nil and TicsServerSettings['admin']['enabled']
            and ISChat.instance.tabs[4] == nil then
            AddTab('Admin', 4)
        end
    end
end

local function GetFirstTab()
    if ISChat.instance.tabs == nil then
        return nil
    end
    for tabId, tab in pairs(ISChat.instance.tabs) do
        return tabId, tab
    end
end

local function HasAtLeastOneChanelEnabled(tabId)
    if TicsServerSettings == nil then
        return false
    end
    for _, stream in pairs(ISChat.allChatStreams) do
        local name = stream['name']
        if stream['tabID'] == tabId and TicsServerSettings[name] and TicsServerSettings[name]['enabled'] then
            return true
        end
    end
    return false
end

local function RemoveTab(tabTitle, tabID)
    local foundTab
    if ISChat.instance.tabs[tabID] ~= nil then
        foundTab = ISChat.instance.tabs[tabID]
        ISChat.instance.tabs[tabID] = nil
    else
        return
    end
    if ISChat.instance.tabCnt > 1 then
        for i, blinkedTab in ipairs(ISChat.instance.panel.blinkTabs) do
            if tabTitle == blinkedTab then
                table.remove(ISChat.instance.panel.blinkTabs, i)
                break
            end
        end
        ISChat.instance.panel:removeView(foundTab)
        ISChat.instance.minimumWidth = ISChat.instance.panel:getWidthOfAllTabs() + 2 * ISChat.instance.inset
    end
    ISChat.instance.tabCnt = ISChat.instance.tabCnt - 1
    local firstTabId, firstTab = GetFirstTab()
    if firstTabId == nil then
        return
    end
    if ISChat.instance.currentTabID == tabID then
        ISChat.instance.currentTabID = firstTabId
        local chat = ISChat.instance
        chat.panel:activateView(chat.tabs[chat.currentTabID].tabTitle)
    end
    if ISChat.instance.tabCnt == 1 then
        local lastTab = firstTab
        ISChat.instance.panel:setVisible(false)
        ISChat.instance.panel:removeView(lastTab)
        ISChat.instance.chatText = lastTab
        ISChat.instance:addChild(ISChat.instance.chatText)
        ISChat.instance.chatText:setVisible(true)
    end
    ISChat.instance:onActivateView()
end

ISChat.onRecvSandboxVars = function(messageTypeSettings)
    if TicsServerSettings == nil then
        Events.OnPostRender.Remove(AskServerData)
    end

    local knownAvatars = AvatarManager:getKnownAvatars()
    ClientSend.sendKnownAvatars(knownAvatars)
    -- the server answered, it is ready to receive commands
    LanguageManager:askKnownLanguages()

    TicsServerSettings = messageTypeSettings -- a global

    if HasAtLeastOneChanelEnabled(2) == true then
        AddTab('Out Of Character', 2)
    elseif ISChat.instance.tabs[2] ~= nil then
        RemoveTab('Out Of Character', 2)
    end
    if HasAtLeastOneChanelEnabled(3) == true then
        AddTab('Private Message', 3)
    elseif ISChat.instance.tabs[3] ~= nil then
        RemoveTab('Private Message', 3)
    end
    if Character.isAdmin(getPlayer()) and messageTypeSettings['admin']['enabled'] then
        AddTab('Admin', 4)
    elseif ISChat.instance.tabs[4] ~= nil then
        RemoveTab('Admin', 4)
    end
    if ISChat.instance.tabCnt > 1 and not HasAtLeastOneChanelEnabled(1) then
        RemoveTab('General', 1)
    else
        UpdateTabStreams(ISChat.instance.tabs[1], 1)
    end

    UpdateRangeIndicator(ISChat.defaultTabStream[ISChat.instance.currentTabID])
    if ISChat.instance.ticsModData == nil or ISChat.instance.ticsModData['isVoiceEnabled'] == nil then
        ISChat.instance.isVoiceEnabled = messageTypeSettings['options']['isVoiceEnabled']
    end
    local radioMaxRange = TicsServerSettings['options']['radio']['soundMaxRange']
    if ISChat.instance.radioRangeIndicator then
        ISChat.instance.radioRangeIndicator:unsubscribe()
    end
    ISChat.instance.radioRangeIndicator = RadioRangeIndicator:new(25, radioMaxRange, ISChat.instance.isRadioIconEnabled)
    if ISChat.instance.radioButtonState == true then
        ISChat.instance.radioRangeIndicator:subscribe()
    end
    ISChat.instance.online = true
end

ISChat.onTabRemoved = function(tabTitle, tabID)
    if tabID ~= 1 then -- Admin tab is 1 in the Java code
        return
    end
    RemoveTab('Admin', 4) -- Admin tab is 4 in our table
end

ISChat.onSetDefaultTab = function(defaultTabTitle)
end

local function GetNextTabId(currentTabId)
    local firstId = nil
    local found = false
    for tabId, _ in pairs(ISChat.instance.tabs) do
        if firstId == nil then
            firstId = tabId
        end
        if currentTabId == tabId then
            found = true
        elseif found == true then
            return tabId
        end
    end
    return firstId
end

ISChat.onToggleChatBox = function(key)
    if ISChat.instance == nil then return end
    if key == getCore():getKey("Toggle chat") or key == getCore():getKey("Alt toggle chat") then
        ISChat.instance:focus()
    end
    local chat = ISChat.instance
    if key == getCore():getKey("Switch chat stream") then
        local nextTabId = GetNextTabId(chat.currentTabID)
        if nextTabId == nil then
            print('TICS error: onToggleChatBox: next tab ID not found')
            return
        end
        chat.currentTabID = nextTabId
        chat.panel:activateView(chat.tabs[chat.currentTabID].tabTitle)
        ISChat.instance:onActivateView()
    end
end

local function GetTabFromOrder(tabIndex)
    local index = 1
    for tabId, tab in pairs(ISChat.instance.tabs) do
        if tabIndex == index then
            return tabId
        end
        index = index + 1
    end
    return nil
end

ISChat.ISTabPanelOnMouseDown = function(target, x, y)
    if target:getMouseY() >= 0 and target:getMouseY() < target.tabHeight then
        if target:getScrollButtonAtX(x) == "left" then
            target:onMouseWheel(-1)
            return true
        end
        if target:getScrollButtonAtX(x) == "right" then
            target:onMouseWheel(1)
            return true
        end
        local tabIndex = target:getTabIndexAtX(target:getMouseX())
        local tabId = GetTabFromOrder(tabIndex)
        if tabId ~= nil then
            ISChat.instance.currentTabID = tabId
        end
        -- if we clicked on a tab, the first time we set up the x,y of the mouse, so next time we can see if the player moved the mouse (moved the tab)
        if tabIndex >= 1 and tabIndex <= #target.viewList and ISTabPanel.xMouse == -1 and ISTabPanel.yMouse == -1 then
            ISTabPanel.xMouse = target:getMouseX()
            ISTabPanel.yMouse = target:getMouseY()
            target.draggingTab = tabIndex - 1
            local clickedTab = target.viewList[target.draggingTab + 1]
            target:activateView(clickedTab.name)
        end
    end
    return false
end

local function OnRangeButtonClick()
    if TicsServerSettings == nil then
        return
    end
    if ISChat.instance.rangeButtonState == 'visible' then
        ISChat.instance.rangeButtonState = 'always-visible'
        ISChat.instance.rangeButton:setImage(getTexture(ChatTheme.icons.eyePlus))
    elseif ISChat.instance.rangeButtonState == 'always-visible' then
        ISChat.instance.rangeButtonState = 'hidden'
        ISChat.instance.rangeButton:setImage(getTexture(ChatTheme.icons.eyeOff))
    else
        ISChat.instance.rangeButtonState = 'visible'
        ISChat.instance.rangeButton:setImage(getTexture(ChatTheme.icons.eye))
    end
    UpdateRangeIndicator(ISChat.lastTabStream[ISChat.instance.currentTabID])
end

local function OnRadioButtonClick()
    if TicsServerSettings == nil or ISChat.instance.radioRangeIndicator == nil then
        return
    end
    ISChat.instance.radioButtonState = not ISChat.instance.radioButtonState
    if ISChat.instance.radioButtonState == true then
        ISChat.instance.radioRangeIndicator:subscribe()
        ISChat.instance.radioButton:setImage(getTexture(ChatTheme.icons.mic))
    else
        ISChat.instance.radioRangeIndicator:unsubscribe()
        ISChat.instance.radioButton:setImage(getTexture(ChatTheme.icons.micOff))
    end
end

local function OnAvatarUploadButtonClick()
    if ISChat.instance.avatarUploadWindow then
        ISChat.instance.avatarUploadWindow:unsubscribe()
    end
    ISChat.instance.avatarUploadWindow = AvatarUploadWindow:new()
    ISChat.instance.avatarUploadWindow:subscribe()
end

local function OnAvatarValidationWindowButtonClick()
    if ISChat.instance.avatarValidationWindow then
        ISChat.instance.avatarValidationWindow:unsubscribe()
    end
    ISChat.instance.avatarValidationWindow = AvatarValidationWindow:new()
    ISChat.instance.avatarValidationWindow:subscribe()
end

-- redefining ISTabPanel:activateView to remove the update of the info button
local function PanelActivateView(panel, viewName)
    local self = panel
    for ind, value in ipairs(self.viewList) do
        -- we get the view we want to display
        if value.name == viewName then
            self.activeView.view:setVisible(false)
            value.view:setVisible(true)
            self.activeView = value
            self:ensureVisible(ind)

            if self.onActivateView and self.target then
                self.onActivateView(self.target, self)
            end

            return true
        end
    end
    return false
end

-- title bar button opening the player's character sheet, while the server enables them
function ISChat:createCharacterSheetButton()
    if not CharacterSheetManager.isEnabled() then
        if self.characterSheetButton then
            self:removeChild(self.characterSheetButton)
            self.characterSheetButton = nil
        end
        return
    end
    if self.characterSheetButton == nil then
        local th = self:titleBarHeight()
        local button = ISButton:new(0, 0, th, th, '', self, function()
            CharacterSheetWindow.open(getPlayer():getUsername())
        end)
        button.anchorRight = true
        button.anchorLeft = false
        button:initialise()
        button:setImage(getTexture(ChatTheme.icons.sheet))
        button:setUIName('character sheet button')
        self:addChild(button)
        self.characterSheetButton = button
    end
end

function ISChat:createValidationWindowButton()
    if TicsServerSettings == nil or TicsServerSettings['options']['portrait'] ~= 2 then
        if self.avatarUploadButton then
            self:removeChild(self.avatarUploadButton)
            self.avatarUploadButton = nil
        end
        if self.avatarValidationWindowButton then
            self:removeChild(self.avatarValidationWindowButton)
            self.avatarValidationWindowButton = nil
        end
        return
    end

    local th = self:titleBarHeight()
    if self.avatarUploadButton == nil then
        --avatar upload button
        ISChat.avatarUploadButtonName = "avatar upload"
        self.avatarUploadButton = ISButton:new(self.radioButton:getX() - th / 2 - th, 1, th, th, "", self,
            OnAvatarUploadButtonClick)
        self.avatarUploadButton.anchorRight = true
        self.avatarUploadButton.anchorLeft = false
        self.avatarUploadButton:initialise()
        self.avatarUploadButton.borderColor.a = 0.0
        self.avatarUploadButton.backgroundColor.a = 0
        self.avatarUploadButton.backgroundColorMouseOver.a = 0.5
        self.avatarUploadButton:setImage(getTexture(ChatTheme.icons.upload))
        self.avatarUploadButton:setUIName(ISChat.avatarUploadButtonName)
        self:addChild(self.avatarUploadButton)
        self.avatarUploadButton:setVisible(true)
    end

    if self.avatarValidationWindowButton == nil then
        if Character.isAdminOrModerator(getPlayer()) then
            ISChat.avatarValidationWindowButtonName = 'avatar validation window button'
            self.avatarValidationWindowButton = ISButton:new(self.avatarUploadButton:getX() - th / 2 - th, 1, th, th,
                '', self, OnAvatarValidationWindowButtonClick)
            self.avatarValidationWindowButton.anchorRight = true
            self.avatarValidationWindowButton.anchorLeft = false
            self.avatarValidationWindowButton:initialise()
            self.avatarValidationWindowButton.borderColor.a = 0.0
            self.avatarValidationWindowButton.backgroundColor.a = 0
            self.avatarValidationWindowButton.backgroundColorMouseOver.a = 0.5
            self.avatarValidationWindowButton:setImage(getTexture(ChatTheme.icons.portrait))
            self.avatarValidationWindowButton:setUIName(ISChat.avatarValidationWindowButtonName)
            self:addChild(self.avatarValidationWindowButton)
            self.avatarValidationWindowButton:setVisible(true)
        end
    end
end

function ISChat:createChildren()
    --window stuff
    -- Do corner x + y widget
    local rh = self:resizeWidgetHeight()
    local resizeWidget = ISResizeWidget:new(self.width - rh, self.height - rh, rh, rh, self)
    resizeWidget:initialise()
    resizeWidget.onMouseDown = ISChat.onMouseDown
    resizeWidget.onMouseUp = ISChat.onMouseUp
    resizeWidget:setVisible(self.resizable)
    resizeWidget:bringToTop()
    resizeWidget:setUIName(ISChat.xyResizeWidgetName)
    self:addChild(resizeWidget)
    self.resizeWidget = resizeWidget

    -- Do bottom y widget
    local resizeWidget2 = ISResizeWidget:new(0, self.height - rh, self.width - rh, rh, self, true)
    resizeWidget2.anchorLeft = true
    resizeWidget2.anchorRight = true
    resizeWidget2:initialise()
    resizeWidget2.onMouseDown = ISChat.onMouseDown
    resizeWidget2.onMouseUp = ISChat.onMouseUp
    resizeWidget2:setVisible(self.resizable)
    resizeWidget2:setUIName(ISChat.yResizeWidgetName)
    self:addChild(resizeWidget2)
    self.resizeWidget2 = resizeWidget2

    -- close button
    local th = self:titleBarHeight()
    self.closeButtonTexture = getTexture(ChatTheme.icons.close)
    self.chatLockedButtonTexture = getTexture(ChatTheme.icons.lock)
    self.chatUnLockedButtonTexture = getTexture(ChatTheme.icons.unlock)
    self.closeButton = ISButton:new(3, 0, th, th, "", self, self.close)
    self.closeButton:initialise()
    self.closeButton.borderColor.a = 0.0
    self.closeButton.backgroundColor.a = 0
    self.closeButton.backgroundColorMouseOver.a = 0.5
    self.closeButton:setImage(self.closeButtonTexture)
    self.closeButton:setUIName(ISChat.closeButtonName)
    self:addChild(self.closeButton)

    -- lock button
    self.lockButton = ISButton:new(self.width - 19, 0, th, th, "", self, ISChat.pin)
    self.lockButton.anchorRight = true
    self.lockButton.anchorLeft = false
    self.lockButton:initialise()
    self.lockButton.borderColor.a = 0.0
    self.lockButton.backgroundColor.a = 0
    self.lockButton.backgroundColorMouseOver.a = 0.5
    if self.locked then
        self.lockButton:setImage(self.chatLockedButtonTexture)
    else
        self.lockButton:setImage(self.chatUnLockedButtonTexture)
    end
    self.lockButton:setUIName(ISChat.lockButtonName)
    self:addChild(self.lockButton)
    self.lockButton:setVisible(true)

    --gear button
    self.gearButton = ISButton:new(self.lockButton:getX() - th / 2 - th, 1, th, th, "", self, ISChat.onGearButtonClick)
    self.gearButton.anchorRight = true
    self.gearButton.anchorLeft = false
    self.gearButton:initialise()
    self.gearButton.borderColor.a = 0.0
    self.gearButton.backgroundColor.a = 0
    self.gearButton.backgroundColorMouseOver.a = 0.5
    self.gearButton:setImage(getTexture(ChatTheme.icons.gear))
    self.gearButton:setUIName(ISChat.gearButtonName)
    self:addChild(self.gearButton)
    self.gearButton:setVisible(true)

    --info button
    ISChat.infoButtonName = "chat info button"
    self.infoButton = ISButton:new(self.gearButton:getX() - th / 2 - th, 1, th, th, "", self, ISChat.onInfoButtonClick)
    self.infoButton.anchorRight = true
    self.infoButton.anchorLeft = false
    self.infoButton:initialise()
    self.infoButton.borderColor.a = 0.0
    self.infoButton.backgroundColor.a = 0
    self.infoButton.backgroundColorMouseOver.a = 0.5
    self.infoButton:setImage(getTexture(ChatTheme.icons.info))
    self.infoButton:setUIName(ISChat.infoButtonName)
    self:addChild(self.infoButton)
    self.infoButton:setVisible(true)


    --range button
    ISChat.rangeButtonName = "chat range button"
    self.rangeButton = ISButton:new(self.infoButton:getX() - th / 2 - th, 1, th, th, "", self, OnRangeButtonClick)
    self.rangeButton.anchorRight = true
    self.rangeButton.anchorLeft = false
    self.rangeButton:initialise()
    self.rangeButton.borderColor.a = 0.0
    self.rangeButton.backgroundColor.a = 0
    self.rangeButton.backgroundColorMouseOver.a = 0.5
    self.rangeButton:setImage(getTexture(ChatTheme.icons.eyeOff))
    self.rangeButton:setUIName(ISChat.rangeButtonName)
    self:addChild(self.rangeButton)
    self.rangeButton:setVisible(true)

    --radio button
    ISChat.radioButtonName = "radio button"
    self.radioButton = ISButton:new(self.rangeButton:getX() - th / 2 - th, 1, th, th, "", self, OnRadioButtonClick)
    self.radioButton.anchorRight = true
    self.radioButton.anchorLeft = false
    self.radioButton:initialise()
    self.radioButton.borderColor.a = 0.0
    self.radioButton.backgroundColor.a = 0
    self.radioButton.backgroundColorMouseOver.a = 0.5
    self.radioButton:setImage(getTexture(ChatTheme.icons.micOff))
    self.radioButton:setUIName(ISChat.radioButtonName)
    self:addChild(self.radioButton)
    self.radioButton:setVisible(true)

    --journal button
    self.journalButton = ISButton:new(0, 1, th, th, "", self, function() JournalWindow.toggle() end)
    self.journalButton.anchorRight = true
    self.journalButton.anchorLeft = false
    self.journalButton:initialise()
    self.journalButton:setImage(getTexture(ChatTheme.icons.book))
    self.journalButton:setUIName('chat journal button')
    self:addChild(self.journalButton)

    --avatar validation window button
    self:createValidationWindowButton()

    --general stuff
    self.minimumHeight = 90
    self.minimumWidth = 200
    self:setResizable(true)
    self:setDrawFrame(true)
    self:addToUIManager()

    self.tabs = {}
    self.tabCnt = 0
    self.btnHeight = 25
    self.currentTabID = 0
    self.inset = 2
    self.fontHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()

    --text entry stuff
    local inset, EdgeSize, fontHgt = self.inset, 5, self.fontHgt

    -- EdgeSize must match UITextBox2.EdgeSize
    local height = EdgeSize * 2 + fontHgt
    local entryPadding = 6
    self.textEntry = ISTextEntryBox:new("", entryPadding, self:getHeight() - 8 - inset - height,
        self:getWidth() - entryPadding * 2, height)
    self.textEntry.font = UIFont.Medium
    self.textEntry:initialise()
    -- self.textEntry:instantiate()
    ChatUI.textEntry.instantiate(self.textEntry)
    self.textEntry.backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 }
    self.textEntry.borderColor = { r = 1, g = 1, b = 1, a = 0.0 }
    self.textEntry:setHasFrame(true)
    self.textEntry:setAnchorTop(false)
    self.textEntry:setAnchorBottom(true)
    self.textEntry:setAnchorRight(true)
    self.textEntry.onCommandEntered = ISChat.onCommandEntered
    self.textEntry.onTextChange = ISChat.onTextChange
    self.textEntry.onPressDown = ISChat.onPressDown
    self.textEntry.onPressUp = ISChat.onPressUp
    self.textEntry.onOtherKey = ISChat.onOtherKey
    self.textEntry.onClick = ISChat.onMouseDown
    self.textEntry:setUIName(ISChat.textEntryName) -- need to be right this. If it will empty or another then focus will lost on click in chat
    self.textEntry:setHasFrame(true)
    self:addChild(self.textEntry)
    self.textEntry.prerender = ChatUI.textEntry.prerender
    ISChat.maxTextEntryOpaque = self.textEntry:getFrameAlpha()

    --tab panel stuff
    local panelHeight = self.textEntry:getY() - self:titleBarHeight() - self.inset
    self.panel = ISTabPanel:new(0, self:titleBarHeight(), self.width - inset, panelHeight)
    self.panel:initialise()
    self.panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.panel.onActivateView = ISChat.onActivateView
    self.panel.target = self
    self.panel:setAnchorTop(true)
    self.panel:setAnchorLeft(true)
    self.panel:setAnchorRight(true)
    self.panel:setAnchorBottom(true)
    self.panel:setEqualTabWidth(false)
    self.panel.tabPadX = 28
    self.panel:setVisible(false)
    self.panel.onRightMouseUp = ISChat.onRightMouseUp
    self.panel.onRightMouseDown = ISChat.onRightMouseDown
    self.panel.onMouseUp = ISChat.onMouseUp
    self.panel.onMouseDown = ISChat.ISTabPanelOnMouseDown
    self.panel:setUIName(ISChat.tabPanelName)
    self:addChild(self.panel)
    self.panel.activateView = PanelActivateView
    self.panel.render = ChatUI.tabPanel.render
    self.panel.prerender = ChatUI.tabPanel.prerender

    self:bringToTop()
    self.textEntry:bringToTop()
    self.minimumWidth = self.panel:getWidthOfAllTabs() + 2 * inset
    self.minimumHeight = self.textEntry:getHeight() + self:titleBarHeight() + 2 * inset + self.panel.tabHeight +
        fontHgt * 4
    self:unfocus()

    self.mutedUsers = {}
end

function ISChat:focus()
    self:setVisible(true)
    ISChat.focused = true
    self.textEntry:setEditable(true)
    self.textEntry:focus()
    self.textEntry:ignoreFirstInput()
    local stream = ISChat.lastTabStream[ISChat.instance.currentTabID]
    if self.draftText then
        -- restore what the player was writing before the chat was unfocused
        self:setInputText(self.draftText)
        stream = GetCommandFromMessage(self.draftText) or stream
        self.draftText = nil
    else
        self:setInputText(stream['command'])
    end
    UpdateRangeIndicator(stream)
    self.fade:reset()
    self.fade:update() --reset fraction to start value
end

-- `clearText`: true to discard what was written (escape, message sent), otherwise
-- the text is kept as a draft and restored by the next focus()
function ISChat:unfocus(clearText)
    if clearText then
        self.draftText = nil
    elseif ISChat.focused then
        local text = self:getInputText()
        if text ~= nil and string.trim(text) ~= '' and not IsOnlyCommand(text) then
            self.draftText = text
        end
    end
    self.textEntry:unfocus()
    -- the box is emptied either way, the text would be drawn over the unfocused chat
    self.inputChip = nil
    self.textEntry:setText("")
    if ISChat.focused then
        self.fade:reset() -- to begin fade. unfocus called when element was unfocused also.
    end
    ISChat.focused = false
    self.textEntry:setEditable(false)
end

-- message history (up / down arrows): setInputText restores the channel label of the message
function ISChat:onPressUp()
    local chat = ISChat.instance
    local chatText = chat.chatText
    chatText.logIndex = math.min(chatText.logIndex + 1, #chatText.log)
    if chatText.log[chatText.logIndex] then
        chat:setInputText(chatText.log[chatText.logIndex])
        ISChat.onTextChange() -- range indicator of the recalled channel
    end
end

function ISChat:onPressDown()
    local chat = ISChat.instance
    local chatText = chat.chatText
    chatText.logIndex = math.max(chatText.logIndex - 1, 0)
    if chatText.log[chatText.logIndex] then
        chat:setInputText(chatText.log[chatText.logIndex])
    else
        -- back below the most recent message: empty input on the tab channel
        local stream = ISChat.lastTabStream[chat.currentTabID]
        chat:setInputText(stream and stream['command'] or '')
    end
    ISChat.onTextChange() -- range indicator of the recalled channel
end

-- escape discards the text, any other way of unfocusing the chat keeps it as a draft
function ISChat:onOtherKey(key)
    if key == Keyboard.KEY_ESCAPE then
        -- a popup of the chat (language list, settings) is closed first, the player keeps typing
        if ChatPopup.closeAll() or ChatPopup.closedRecently() then
            ChatPopup.restoreChatFocus()
            return
        end
        ISChat.instance:unfocus(true)
    end
end

-- Clicking the input box of the unfocused chat focuses it, like the "Toggle chat" key.
-- While unfocused the input box is not editable so the click goes through to the window,
-- which uses ISChat.onMouseDown as its own mouse handler (target is then the window).
local VanillaOnMouseDown = ISChat.onMouseDown
function ISChat.onMouseDown(target, x, y)
    local chat = ISChat.instance
    if target == chat and chat ~= nil and not ISChat.focused and chat.textEntry ~= nil then
        local entry = chat.textEntry
        if x >= entry:getX() and x < entry:getX() + entry:getWidth()
            and y >= entry:getY() and y < entry:getY() + entry:getHeight()
        then
            chat:focus()
            -- focus() ignores the next typed character because it is usually the "Toggle chat"
            -- key, here the player used the mouse so the first character must be kept
            entry.javaObject:setIgnoreFirst(false)
            return true
        end
    end
    return VanillaOnMouseDown(target, x, y)
end

-- the gear button opens the chat settings panel (a second click closes it)
function ISChat:onGearButtonClick()
    ChatSettingsPanel.toggle(self)
end

function ISChat:onInfoButtonClick()
    ChatHelpPanel.toggle(self)
end

function ISChat.onToggleVoice()
    ISChat.instance.isVoiceEnabled = not ISChat.instance.isVoiceEnabled

    -- the player has set this option at least once, that means he is aware of its existence
    -- we'll use this settings in the future instead of the server default behavior
    ISChat.instance.ticsModData['isVoiceEnabled'] = ISChat.instance.isVoiceEnabled
    SaveTicsModData()
end

ISChat.onToggleTimestampPrefix = function()
    local chat = ISChat.instance
    chat.showTimestamp = not chat.showTimestamp
    chat.ticsModData['showTimestamp'] = chat.showTimestamp
    SaveTicsModData()
    chat:updateChatPrefixSettings()
end

ISChat.onToggleTagPrefix = function()
    local chat = ISChat.instance
    chat.showTitle = not chat.showTitle
    chat.ticsModData['showTitle'] = chat.showTitle
    SaveTicsModData()
    chat:updateChatPrefixSettings()
end

function ISChat.onToggleHud()
    ISChat.instance.isHudEnabled = not ISChat.instance.isHudEnabled
    ISChat.instance.ticsModData['isHudEnabled'] = ISChat.instance.isHudEnabled
    SaveTicsModData()
end

function ISChat.onToggleRadioIcon()
    ISChat.instance.isRadioIconEnabled = not ISChat.instance.isRadioIconEnabled
    ISChat.instance.ticsModData['isRadioIconEnabled'] = ISChat.instance.isRadioIconEnabled
    SaveTicsModData()
    if ISChat.instance.radioRangeIndicator then
        ISChat.instance.radioRangeIndicator.showIcon = ISChat.instance.isRadioIconEnabled
    end
end

function ISChat.onTogglePortrait()
    ISChat.instance.isPortraitEnabled = not ISChat.instance.isPortraitEnabled
    ISChat.instance.ticsModData['isPortraitEnabled'] = ISChat.instance.isPortraitEnabled
    SaveTicsModData()
end

function ISChat.onToggleRpLog()
    ISChat.instance.isRpLogEnabled = not ISChat.instance.isRpLogEnabled
    ISChat.instance.ticsModData['isRpLogEnabled'] = ISChat.instance.isRpLogEnabled
    SaveTicsModData()
    if ISChat.instance.isRpLogEnabled then
        ISChat.sendInfoToCurrentTab(getText('UI_TICS_Messages_rp_log_enabled', File.getAbsolutePath(RpLog.getDirectory())))
    else
        ISChat.sendInfoToCurrentTab(getText('UI_TICS_Messages_rp_log_disabled'))
    end
end

Events.OnChatWindowInit.Add(ISChat.initChat)
