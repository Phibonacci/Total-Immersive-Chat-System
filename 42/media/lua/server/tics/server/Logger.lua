local DateTime = require('tics/shared/utils/DateTime')
local File     = require('tics/shared/utils/File')


local Logger = {}

local function ChatLogPath()
    local date = DateTime.GetISODate()
    local serverName = getServerName()
    if serverName == nil then
        serverName = 'unknown'
        print('TICS error: Logger: unknown server name, using "unknown" directory for logs')
    end
    return 'TICS/logs/' .. serverName .. '/tics-chat-log-' .. date .. '.txt'
end

function Logger.LogChat(type, author, characterName, message, radiosFrequenciesList, target)
    if type == nil or author == nil or characterName == nil or message == nil then
        return
    end
    local time = DateTime.GetISOTime()
    local text = time .. ' [' .. type .. '] ' .. author .. ' (' .. characterName .. ')'
    if target ~= nil then
        text = text .. ' to ' .. target
    end
    local first = true
    for _, radioFrequency in pairs(radiosFrequenciesList) do
        if first then
            text = text .. '['
        else
            text = text .. ', '
        end
        text = text .. string.format('%.2f', radioFrequency / 1000) .. 'Hz'
        first = false
    end
    if not first then
        text = text .. ']'
    end
    text = text .. ': ' .. message
    local path = ChatLogPath()
    File.writeStringWithNewLine(text, path)
end

return Logger
