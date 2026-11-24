-- Personal RP log: the in-character lines the player sees in the chat (whisper, low, say,
-- yell, /me, /do, their radio versions, and dice rolls) are appended as plain text to
-- Zomboid/Lua/TICS/logs/<save name>/<real date> <character name>.txt
-- The text is the one shown in the chat: a language the character does not know stays
-- scrambled. A header marks the start of each play session in a file.

local ClientSettings = require('tics/client/ClientSettings')
local File = require('tics/shared/utils/File')
local LanguageManager = require('tics/client/languages/LanguageManager')

local RpLog = {}

local DIRECTORY = 'TICS/logs/'

local IN_CHARACTER = {
    whisper = true,
    low = true,
    say = true,
    yell = true,
    me = true,
    ['do'] = true,
    roll = true,
}

local sessionFiles = {} -- files that already got the session header

local function IsEnabled()
    return ISChat.instance ~= nil and ISChat.instance.isRpLogEnabled == true
end

local function FormatRealTime(pattern)
    local format = SimpleDateFormat.new(pattern, Locale.ENGLISH)
    return format:format(Calendar.getInstance():getTime())
end

-- characters a file name cannot hold on Windows, and '..' that the game refuses in paths
local function SafeFileName(name)
    name = name:gsub('[\\/:%*%?"<>|]', '_'):gsub('%.%.+', '.')
    return name
end

local function CharacterName()
    local player = getPlayer()
    local descriptor = player and player:getDescriptor()
    if descriptor == nil then
        return 'unknown'
    end
    return descriptor:getForename() .. ' ' .. descriptor:getSurname()
end

-- relative path in Zomboid/Lua, a new file per real day and character
function RpLog.getDirectory()
    return DIRECTORY .. ClientSettings.getSaveName() .. '/'
end

local function GetPath()
    return RpLog.getDirectory() .. SafeFileName(FormatRealTime('yyyy-MM-dd') .. ' ' .. CharacterName()) .. '.txt'
end

-- chat text without the rich text tags (<RGB:...>, <SIZE:...>, <LINE>...)
local function PlainText(formatted)
    local text = formatted:gsub('<LINE>', ' '):gsub('<%u+:[^>]*>', ''):gsub('<%u+>', '')
    text = text:gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', '')
    return text
end

local function GameDate()
    local time = getGameTime()
    return string.format('%04d-%02d-%02d %02d:%02d', time:getYear(), time:getMonth() + 1, time:getDay() + 1,
        time:getHour(), time:getMinutes())
end

local function Append(path, text)
    if not sessionFiles[path] then
        sessionFiles[path] = true
        File.writeStringWithNewLine('', path)
        File.writeStringWithNewLine('=== ' .. FormatRealTime('HH:mm') .. ' - ' .. CharacterName()
            .. ' - in game ' .. GameDate() .. ' ===', path)
    end
    File.writeStringWithNewLine(text, path)
end

-- Called for every line added to the chat. `channel` is the stream name ('say', 'me'...)
-- or nil for the TICS info and error lines.
function RpLog.addChatLine(channel, language, formattedMessage)
    if channel == nil or not IN_CHARACTER[channel] or not IsEnabled() then
        return
    end
    local text = PlainText(formattedMessage)
    if text == '' then
        return
    end
    local code = language and language ~= LanguageManager.DefaultLanguage
        and LanguageManager.GetCodeFromLanguage(language)
    if code then
        text = '[' .. code:upper() .. '] ' .. text
    end
    Append(GetPath(), '[' .. FormatRealTime('HH:mm') .. '] ' .. text)
end

-- Dice rolls are shown as info lines in the chat, they are logged from here.
function RpLog.addRoll(message)
    RpLog.addChatLine('roll', nil, message)
end

return RpLog
