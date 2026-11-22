local AvatarManager = require('tics/client/AvatarManager')
local LanguageManager = require('tics/client/languages/LanguageManager')
local Radio = require('tics/client/Radio')

local ClientRecv = {}

ClientRecv['ChatMessage'] = function(args)
    ISChat.onMessagePacket(args['type'], args['author'], args['characterName'],
        args['message'], args['language'], args['color'], args['hideInChat'],
        args['target'], false, args['pitch'], args['disableVerb'])
end

ClientRecv['RadioMessage'] = function(args)
    ISChat.onRadioPacket(
        args['type'], args['author'], args['characterName'], args['message'], args['language'], args['color'],
        args['radios'], args['pitch'], args['disableVerb'])
end

ClientRecv['RadioEmittingMessage'] = function(args)
    ISChat.onRadioEmittingPacket(
        args['type'], args['author'], args['characterName'], args['message'], args['language'], args['color'],
        args['frequency'], args['disableVerb'])
end

ClientRecv['DiscordMessage'] = function(args)
    ISChat.onDiscordPacket(args['message'])
end

ClientRecv['Typing'] = function(args)
    ISChat.onTypingPacket(args['author'], args['type'])
end

ClientRecv['ChatError'] = function(args)
    ISChat.onChatErrorPacket(args['type'], args['message'])
end

ClientRecv['KnownLanguages'] = function(args)
    LanguageManager:setKnownLanguages(args['languages'])
end

ClientRecv['LanguageBookRead'] = function(args)
    local result = args['result']
    if result == 'forgotten' then
        ISChat.sendInfoToCurrentTab(getText('UI_TICS_Messages_languages_forgotten', getText('UI_TICS_Languages_en')))
        return
    end
    local languageTranslated = LanguageManager.GetLanguageTranslated(args['language'])
    if result == 'learnt' then
        ISChat.sendInfoToCurrentTab(getText('UI_TICS_Messages_language_learnt', languageTranslated))
    elseif result == 'already_known' then
        ISChat.sendErrorToCurrentTab(getText('UI_TICS_Messages_language_already_learnt', languageTranslated))
    end
end

ClientRecv['ServerPrint'] = function(args)
    print('Server: ' .. args.message)
end

ClientRecv['SendSandboxVars'] = function(args)
    ISChat.onRecvSandboxVars(args)
end

ClientRecv['RadioSquareState'] = function(args)
    Radio.SyncSquare(
        args.turnedOn, args.mute, args.power, args.volume,
        args.frequency, args.x, args.y, args.z)
end

ClientRecv['RadioInHandState'] = function(args)
    Radio.SyncInHand(
        args.id, args.turnedOn, args.mute, args.power, args.volume,
        args.frequency)
end

ClientRecv['ApprovedAvatar'] = function(args)
    local username  = args['username']
    local firstName = args['firstName']
    local lastName  = args['lastName']
    local extension = args['extension']
    local checksum  = args['checksum']
    local data      = args['data']

    if type(username) ~= 'string' then
        print('TICS error: ApprovedAvatar packet does not contain a valid "username"')
        return
    end
    if type(firstName) ~= 'string' then
        print('TICS error: ApprovedAvatar packet does not contain a valid "firstName"')
        return
    end
    if type(lastName) ~= 'string' then
        print('TICS error: ApprovedAvatar packet does not contain a valid "lastName"')
        return
    end
    if type(extension) ~= 'string' then
        print('TICS error: ApprovedAvatar packet does not contain a valid "extension"')
        return
    end
    if type(checksum) ~= 'number' then
        print('TICS error: ApprovedAvatar packet does not contain a valid "checksum"')
        return
    end
    if type(data) ~= 'table' then
        print('TICS error: ApprovedAvatar packet does not contain a valid "data"')
        return
    end

    AvatarManager:saveApprovedAvatar(username, firstName, lastName, extension, checksum, data)
end

ClientRecv['PendingAvatar'] = function(args)
    local username  = args['username']
    local firstName = args['firstName']
    local lastName  = args['lastName']
    local extension = args['extension']
    local checksum  = args['checksum']
    local data      = args['data']

    if type(username) ~= 'string' then
        print('TICS error: PendingAvatar packet does not contain a valid "username"')
        return
    end
    if type(firstName) ~= 'string' then
        print('TICS error: PendingAvatar packet does not contain a valid "firstName"')
        return
    end
    if type(lastName) ~= 'string' then
        print('TICS error: PendingAvatar packet does not contain a valid "lastName"')
        return
    end
    if type(extension) ~= 'string' then
        print('TICS error: PendingAvatar packet does not contain a valid "extension"')
        return
    end
    if type(checksum) ~= 'number' then
        print('TICS error: PendingAvatar packet does not contain a valid "checksum"')
        return
    end
    if type(data) ~= 'table' then
        print('TICS error: PendingAvatar packet does not contain a valid "data"')
        return
    end

    AvatarManager:savePendingAvatar(username, firstName, lastName, extension, checksum, data)
end

ClientRecv['OwnPendingAvatar'] = function(args)
    args = args or {} -- a table with only nil values is received as nil
    local data = args['data']
    if type(data) == 'table' and type(args['checksum']) == 'number' and type(args['extension']) == 'string' then
        AvatarManager:setOwnPendingAvatar(args['checksum'], args['extension'], data)
    else
        AvatarManager:setOwnPendingAvatar(nil)
    end
end

ClientRecv['ApprovedAvatarList'] = function(args)
    local avatars = {}
    for _, avatar in pairs(args and args['avatars'] or {}) do
        if type(avatar) == 'table' and type(avatar['username']) == 'string'
            and type(avatar['firstName']) == 'string' and type(avatar['lastName']) == 'string'
        then
            table.insert(avatars, avatar)
        end
    end
    AvatarManager:setApprovedAvatarList(avatars)
end

ClientRecv['AvatarDeleted'] = function(args)
    local username  = args['username']
    local firstName = args['firstName']
    local lastName  = args['lastName']
    if type(username) ~= 'string' or type(firstName) ~= 'string' or type(lastName) ~= 'string' then
        print('TICS error: AvatarDeleted packet does not contain a valid character')
        return
    end
    AvatarManager:deleteApprovedAvatar(username, firstName, lastName)
end

ClientRecv['AvatarProcessed'] = function(args)
    local username  = args['username']
    local firstName = args['firstName']
    local lastName  = args['lastName']
    local checksum  = args['checksum']

    if type(username) ~= 'string' then
        print('TICS error: PendingAvatar packet does not contain a valid "username"')
        return
    end
    if type(firstName) ~= 'string' then
        print('TICS error: PendingAvatar packet does not contain a valid "firstName"')
        return
    end
    if type(lastName) ~= 'string' then
        print('TICS error: PendingAvatar packet does not contain a valid "lastName"')
        return
    end
    if type(checksum) ~= 'number' then
        print('TICS error: PendingAvatar packet does not contain a valid "checksum"')
        return
    end
    AvatarManager:removeAvatarPending(username, firstName, lastName, checksum)
end

ClientRecv['RollResult'] = function(args)
    local username      = args['username']
    local characterName = args['characterName']
    local diceCount     = args['diceCount']
    local diceType      = args['diceType']
    local addCount      = args['addCount']
    local diceResults   = args['diceResults']
    local finalResult   = args['finalResult']

    if type(username) ~= 'string' then
        print('TICS error: RollResult packet does not contain a valid "username"')
        return
    end
    if type(characterName) ~= 'string' then
        print('TICS error: RollResult packet does not contain a valid "characterName"')
        return
    end
    if type(diceCount) ~= 'number' then
        print('TICS error: RollResult packet does not contain a valid "diceCount"')
        return
    end
    if type(diceType) ~= 'number' then
        print('TICS error: RollResult packet does not contain a valid "diceType"')
        return
    end
    if addCount ~= nil and type(addCount) ~= 'number' then
        print('TICS error: RollResult packet does not contain a valid "addCount"')
        return
    end
    if type(diceResults) ~= 'table' then
        print('TICS error: RollResult packet does not contain a valid "diceResults"')
        return
    end
    if type(finalResult) ~= 'number' then
        print('TICS error: RollResult packet does not contain a valid "finalResult"')
        return
    end
    ISChat.onDiceResult(username, characterName, diceCount, diceType, addCount, diceResults, finalResult)
end

function OnServerCommand(module, command, args)
    if module == 'TICS' and ClientRecv[command] then
        ClientRecv[command](args)
    end
end

Events.OnServerCommand.Add(OnServerCommand)

return ClientRecv
