local Character = require('tics/shared/utils/Character')
local ServerSend = {}

function ServerSend.Command(player, commandName, args)
    sendServerCommand(player, 'TICS', commandName, args)
end

-- languages: language name -> language code
function ServerSend.KnownLanguages(player, languages)
    ServerSend.Command(player, 'KnownLanguages', { languages = languages })
end

-- result of a language book read by the player: 'learnt', 'already_known' or 'forgotten'
function ServerSend.LanguageBookRead(player, result, language)
    ServerSend.Command(player, 'LanguageBookRead', { result = result, language = language })
end

-- checksum, extension and data are nil when the player has no pending request
function ServerSend.OwnPendingAvatar(player, checksum, extension, data)
    -- 'pending' keeps the table from being empty: empty arguments are received as nil
    ServerSend.Command(player, 'OwnPendingAvatar', {
        pending = checksum ~= nil, checksum = checksum, extension = extension, data = data,
    })
end

-- avatars: array of { username, firstName, lastName }
function ServerSend.ApprovedAvatarList(player, avatars)
    ServerSend.Command(player, 'ApprovedAvatarList', { count = #avatars, avatars = avatars })
end

function ServerSend.AvatarDeleted(player, username, firstName, lastName)
    ServerSend.Command(player, 'AvatarDeleted', { username = username, firstName = firstName, lastName = lastName })
end

-- the character sheet of target, sent to player
function ServerSend.CharacterSheet(player, target, sheet)
    local firstName, lastName = Character.getFirstAndLastName(target)
    ServerSend.Command(player, 'CharacterSheet', {
        username = target:getUsername(),
        firstName = firstName,
        lastName = lastName,
        title = sheet.title,
        background = sheet.background,
        ooc = sheet.ooc,
    })
end

function ServerSend.Print(player, message)
    ServerSend.Command(player, 'ServerPrint', { message = message })
end

function ServerSend.ChatErrorMessage(player, type, message)
    ServerSend.Command(player, 'ChatError', { message = message, type = type })
end

function ServerSend.SquareRadioState(player, turnedOn, mute, power, volume, frequency, x, y, z)
    ServerSend.Command(player, 'RadioSquareState', {
        turnedOn = turnedOn,
        mute = mute,
        power = power,
        volume = volume,
        frequency = frequency,
        x = x,
        y = y,
        z = z,
    })
end

function ServerSend.InHandRadioState(player, radioId, turnedOn, mute, power, volume, frequency, x, y, z)
    ServerSend.Command(player, 'RadioInHandState', {
        id = radioId,
        turnedOn = turnedOn,
        mute = mute,
        power = power,
        volume = volume,
        frequency = frequency,
    })
end

function ServerSend.ApprovedAvatar(player, checksum, username, firstName, lastName, data, extension)
    ServerSend.Command(player, 'ApprovedAvatar', {
        username = username,
        firstName = firstName,
        lastName = lastName,
        checksum = checksum,
        data = data,
        extension = extension,
    })
end

function ServerSend.PendingAvatar(player, checksum, username, firstName, lastName, data, extension)
    ServerSend.Command(player, 'PendingAvatar', {
        username = username,
        firstName = firstName,
        lastName = lastName,
        checksum = checksum,
        data = data,
        extension = extension,
    })
end

function ServerSend.AvatarProcessed(player, username, firstName, lastName, checksum)
    ServerSend.Command(player, 'AvatarProcessed', {
        username = username,
        firstName = firstName,
        lastName = lastName,
        checksum = checksum,
    })
end

function ServerSend.RollResult(player, username, characterName, diceCount, diceType, addCount, diceResults, finalResult)
    ServerSend.Command(player, 'RollResult', {
        username = username,
        characterName = characterName,
        diceCount = diceCount,
        diceType = diceType,
        addCount = addCount,
        diceResults = diceResults,
        finalResult = finalResult,
    })
end

return ServerSend
