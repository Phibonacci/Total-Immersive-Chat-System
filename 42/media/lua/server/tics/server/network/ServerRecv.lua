local AvatarManager = require('tics/server/AvatarManager')
local Character     = require('tics/shared/utils/Character')
local CharacterSheets = require('tics/server/CharacterSheets')
local ChatMessage   = require('tics/server/ChatMessage')
local Introductions = require('tics/server/Introductions')
local KnownLanguages = require('tics/server/KnownLanguages')
local ServerSend    = require('tics/server/network/ServerSend')
local Radio         = require('tics/server/radio/Radio')
local RadioManager  = require('tics/server/radio/RadioManager')
local World         = require('tics/shared/utils/World')


local RecvServer = {}


RecvServer['MuteInHandRadio'] = function(player, args)
    local playerName = args['player']
    if playerName == nil then
        print('TICS error: MuteInHandRadio packet with null player name')
        return
    end
    if args['id'] == nil then
        print('TICS error: MuteInHandRadio packet with a null id')
        return
    end
    local id = args['id']
    if id == nil then
        print('TICS error: MuteInHandRadio packet has no id value')
        return
    end
    local radio = Character.getItemById(player, id) or Character.getFirstAttachedItemByType(player, args['belt'])
    if radio == nil or not instanceof(radio, 'Radio') then
        print('TICS error: MuteInHandRadio packet asking for id ' .. id ..
            ' but no radio was found')
        return
    end
    local muteState = args['mute']
    if type(muteState) ~= 'boolean' then
        print('TICS error: MuteInHandRadio packet has no "mute" variable')
        return
    end
    Radio.MuteRadio(radio, muteState)
    Radio.SyncHand(radio, player, id)
end


RecvServer['MuteSquareRadio'] = function(player, args)
    local x = args['x']
    local y = args['y']
    local z = args['z']
    if x == nil or y == nil or z == nil then
        print('TICS error: MuteSquareRadio packet with null coordinate')
        return
    end
    local square = getSquare(x, y, z)
    if square == nil then
        print('TICS error: MuteSquareRadio packet coordinate do not point to a square: x: ' ..
            x .. ', y: ' .. y .. ', z: ' .. z)
        return
    end
    local radios = World.getSquareItemsByGroup(square, 'IsoRadio')
    if radios == nil or #radios <= 0 then
        print('TICS error: MuteSquareRadio packet square does not contain a radio at: x: ' ..
            x .. ', y: ' .. y .. ', z: ' .. z)
        return
    end
    local radio = radios[1]
    if radio == nil or radio.getModData == nil or radio:getModData() == nil then
        print('TICS error: MuteSquareRadio packet lead to an impossible error where we found a corrupted radio')
        return
    end
    local muteState = args['mute']
    if type(muteState) ~= 'boolean' then
        print('TICS error: MuteSquareRadio packet has no "mute" variable')
        return
    end
    Radio.MuteRadio(radio, muteState)
    Radio.SyncSquare(radio)
end


RecvServer['ChatMessage'] = function(player, args)
    ChatMessage.ProcessMessage(player, args, 'ChatMessage', true)
end


RecvServer['Typing'] = function(player, args)
    ChatMessage.ProcessMessage(player, args, 'Typing', false)
end


RecvServer['AskSandboxVars'] = function(player, args)
    ServerSend.Command(player, 'SendSandboxVars', ChatMessage.MessageTypeSettings)
end


RecvServer['GiveBeltRadioState'] = function(player, args)
    local playerName = args['player']
    if playerName == nil then
        print('TICS error: GiveBeltRadioState packet with null player name')
        return
    end
    local beltType = args['belt']
    if beltType == nil then
        print('TICS error: GiveBeltRadioState packet has no "belt" variable')
        return
    end
    local turnedOn = args['turnedOn']
    if type(turnedOn) ~= 'boolean' then
        print('TICS error: GiveBeltRadioState packet has no "turnedOn" variable')
        return
    end
    local muteState = args['mute']
    if type(muteState) ~= 'boolean' then
        print('TICS error: GiveBeltRadioState packet has no "mute" variable')
        return
    end
    local volume = args['volume']
    if type(volume) ~= 'number' then
        print('TICS error: GiveBeltRadioState packet has no "volume" variable')
        return
    end
    local frequency = args['frequency']
    if type(frequency) ~= 'number' then
        print('TICS error: GiveBeltRadioState packet has no "frequency" variable')
        return
    end
    local battery = args['battery']
    if type(battery) ~= 'number' then
        print('TICS error: GiveBeltRadioState packet has no "battery" variable')
        return
    end
    local headphone = args['headphone']
    if type(headphone) ~= 'number' then
        print('TICS error: GiveBeltRadioState packet has no "headphone" variable')
        return
    end
    local isTwoWay = args['isTwoWay']
    if type(isTwoWay) ~= 'boolean' then
        print('TICS error: GiveBeltRadioState packet has no "isTwoWay" variable')
        return
    end
    local transmitRange = args['transmitRange']
    if type(transmitRange) ~= 'number' then
        print('TICS error: GiveBeltRadioState packet has no "transmitRange" variable')
        return
    end
    local radio = Character.getFirstAttachedItemByType(player, beltType)
    if radio == nil or not instanceof(radio, 'Radio') then
        print('TICS error: GiveBeltRadioState packet asking for a belt radio of type ' .. beltType ..
            ' but no radio was found')
        return
    end
    radio = RadioManager:getOrCreateFakeBeltRadio(player)
    Radio.MuteRadio(radio, muteState)
    Radio.SyncBelt(radio, player, turnedOn, muteState, volume, frequency, battery, headphone, isTwoWay, transmitRange)
end


RecvServer['AskInHandRadioState'] = function(player, args)
    local playerName = args['player']
    if playerName == nil then
        print('TICS error: AskInHandRadioState packet with null player name')
        return
    end
    local id = args['id']
    if id == nil then
        print('TICS error: AskInHandRadioState packet with a null id')
        return
    end
    local radio = Character.getItemById(player, id) or Character.getFirstAttachedItemByType(player, args['belt'])
    if radio == nil or not instanceof(radio, 'Radio') then
        print('TICS error: AskInHandRadioState packet asking for id ' .. id ..
            ' but no radio was found')
        return
    end
    Radio.SyncHand(radio, player, id)
end


RecvServer['AskSquareRadioState'] = function(player, args)
    local x = args['x']
    local y = args['y']
    local z = args['z']
    if x == nil or y == nil or z == nil then
        print('TICS error: AskSquareRadioState packet with null coordinate')
        return
    end
    local square = getSquare(x, y, z)
    if square == nil then
        print('TICS error: AskSquareRadioState packet coordinate do not point to a square: x: ' ..
            x .. ', y: ' .. y .. ', z: ' .. z)
        return
    end
    local radios = World.getSquareItemsByGroup(square, 'IsoRadio')
    if radios == nil or #radios <= 0 then
        print('TICS error: AskSquareRadioState packet square does not contain a radio at: x: ' ..
            x .. ', y: ' .. y .. ', z: ' .. z)
        return
    end
    local radio = radios[1]
    Radio.SyncSquare(radio, player)
end


RecvServer['KnownAvatars'] = function(player, args)
    local avatars = args['avatars']
    if avatars == nil or type(avatars) ~= 'table' then
        print('TICS error: KnownAvatars packet does not contain an "avatars" variable')
    end
    AvatarManager:registerPlayerAvatars(player, avatars)
end


RecvServer['AvatarRequest'] = function(player, args)
    local data = args['data']
    if data == nil or type(data) ~= 'table' then
        print('TICS error: AvatarRequest packet does not contain a "data" variable')
        return
    end
    local checksum = args['checksum']
    if checksum == nil or type(checksum) ~= 'number' then
        print('TICS error: AvatarRequest packet does not contain a "checksum" variable')
        return
    end
    local extension = args['extension']
    if extension == nil or type(extension) ~= 'string' then
        print('TICS error: AvatarRequest packet does not contain an "extension" variable')
        return
    end
    local username = player:getUsername()
    if username == nil or type(username) ~= 'string' then
        print('TICS error: AvatarRequest packet does not contain an "username" variable')
        return
    end
    local firstName = args['firstName']
    if firstName == nil or type(firstName) ~= 'string' then
        print('TICS error: AvatarRequest packet does not contain a "firstName" variable')
        return
    end
    local lastName = args['lastName']
    if lastName == nil or type(lastName) ~= 'string' then
        print('TICS error: AvatarRequest packet does not contain a "lastName" variable')
        return
    end
    AvatarManager:registerAvatarRequest(username, firstName, lastName, extension, checksum, data)
    AvatarManager:sendOwnPendingAvatar(player)
end

RecvServer['AskOwnPendingAvatar'] = function(player, args)
    AvatarManager:sendOwnPendingAvatar(player)
end

RecvServer['DeleteAvatar'] = function(player, args)
    AvatarManager:deleteAvatar(player)
end

-- avatar management window (admins and moderators)
local function GetCharacterArgs(args)
    if type(args) ~= 'table' or type(args['username']) ~= 'string'
        or type(args['firstName']) ~= 'string' or type(args['lastName']) ~= 'string'
    then
        return nil
    end
    return args['username'], args['firstName'], args['lastName']
end

-- character sheets
local function IsCharacterSheetEnabled()
    return SandboxVars.TICS.CharacterSheetEnabled == true
end

RecvServer['SetCharacterSheet'] = function(player, args)
    if not IsCharacterSheetEnabled() or type(args) ~= 'table' then
        return
    end
    CharacterSheets.set(player, args)
    ServerSend.CharacterSheet(player, player, CharacterSheets.get(player))
end

-- the sheet of a player close enough to be seen (same range as /say)
RecvServer['AskCharacterSheet'] = function(player, args)
    if not IsCharacterSheetEnabled() or type(args) ~= 'table' or type(args['username']) ~= 'string' then
        return
    end
    local target = World.getPlayerByUsername(args['username'])
    if target == nil then
        return
    end
    if target ~= player then
        local range = ChatMessage.MessageTypeSettings and ChatMessage.MessageTypeSettings['say']['range'] or 15
        local dx = target:getX() - player:getX()
        local dy = target:getY() - player:getY()
        if math.sqrt(dx * dx + dy * dy) > range + 1 then
            return
        end
    end
    ServerSend.CharacterSheet(player, target, CharacterSheets.get(target))
end

RecvServer['AdminClearCharacterSheet'] = function(player, args)
    local username, firstName, lastName = GetCharacterArgs(args)
    if not Character.isAdminOrModerator(player) or username == nil then
        return
    end
    print('TICS info: character sheet cleared by ' .. player:getUsername() .. ': ' .. username
        .. ' "' .. firstName .. ' ' .. lastName .. '"')
    CharacterSheets.clear(username, firstName, lastName)
    local target = World.getPlayerByUsername(username)
    if target then
        ServerSend.CharacterSheet(player, target, CharacterSheets.get(target))
        ServerSend.CharacterSheet(target, target, CharacterSheets.get(target))
    end
end

RecvServer['AskApprovedAvatarList'] = function(player, args)
    if not Character.isAdminOrModerator(player) then
        return
    end
    ServerSend.ApprovedAvatarList(player, AvatarManager:getApprovedAvatarList())
end

RecvServer['AskApprovedAvatarImage'] = function(player, args)
    local username, firstName, lastName = GetCharacterArgs(args)
    if not Character.isAdminOrModerator(player) or username == nil then
        return
    end
    AvatarManager:sendApprovedAvatarTo(player, username, firstName, lastName)
end

RecvServer['AdminDeleteAvatar'] = function(player, args)
    local username, firstName, lastName = GetCharacterArgs(args)
    if not Character.isAdminOrModerator(player) or username == nil then
        return
    end
    print('TICS info: avatar deleted by ' .. player:getUsername() .. ': ' .. username
        .. ' "' .. firstName .. ' ' .. lastName .. '"')
    AvatarManager:deleteAvatarOf(username, firstName, lastName)
    ServerSend.ApprovedAvatarList(player, AvatarManager:getApprovedAvatarList())
end

RecvServer['ApproveAvatar'] = function(player, args)
    local username  = args['username']
    local firstName = args['firstName']
    local lastName  = args['lastName']
    local checksum  = args['checksum']
    if type(username) ~= 'string' then
        print('TICS error: ApproveAvatar packet does not contain a "username" variable')
        return
    end
    if type(firstName) ~= 'string' then
        print('TICS error: ApproveAvatar packet does not contain a "firstName" variable')
        return
    end
    if type(lastName) ~= 'string' then
        print('TICS error: ApproveAvatar packet does not contain a "lastName" variable')
        return
    end
    if type(checksum) ~= 'number' then
        print('TICS error: ApproveAvatar packet does not contain a "checksum" variable')
        return
    end
    AvatarManager:approveAvatar(player, username, firstName, lastName, checksum)
end

RecvServer['RejectAvatar'] = function(player, args)
    local username  = args['username']
    local firstName = args['firstName']
    local lastName  = args['lastName']
    local checksum  = args['checksum']
    if type(username) ~= 'string' then
        print('TICS error: RejectAvatar packet does not contain a "username" variable')
        return
    end
    if type(firstName) ~= 'string' then
        print('TICS error: RejectAvatar packet does not contain a "firstName" variable')
        return
    end
    if type(lastName) ~= 'string' then
        print('TICS error: RejectAvatar packet does not contain a "lastName" variable')
        return
    end
    if type(checksum) ~= 'number' then
        print('TICS error: RejectAvatar packet does not contain a "checksum" variable')
        return
    end
    AvatarManager:rejectAvatar(player, username, firstName, lastName, checksum)
end

RecvServer['Roll'] = function(player, args)
    local diceCount = args['diceCount']
    local diceType  = args['diceType']
    local addCount  = args['addCount']
    if type(diceCount) ~= 'number' then
        print('TICS error: Roll packet does not contain a "diceCount" variable')
        return
    end
    if type(diceType) ~= 'number' then
        print('TICS error: Roll packet does not contain a "diceType" variable')
        return
    end
    if addCount ~= nil and type(addCount) ~= 'number' then
        print('TICS error: Roll packet does not contain a "diceType" variable')
        return
    end
    ChatMessage.RollDice(player, diceCount, diceType, addCount)
end

RecvServer['AskKnownLanguages'] = function(player, args)
    ServerSend.KnownLanguages(player, KnownLanguages.get(player))
end

-- only used to migrate the languages learnt before they were stored on the server,
-- language books are applied by the server itself (ISReadLanguageBook:complete)
RecvServer['LearnLanguage'] = function(player, args)
    KnownLanguages.learn(player, args['language'])
    ServerSend.KnownLanguages(player, KnownLanguages.get(player))
end

-- introductions: the characters the player's character knows
RecvServer['AskIntroductions'] = function(player, args)
    if Introductions.isEnabled() then
        ServerSend.Introductions(player, Introductions.getKnown(player), Introductions.getKnownBy(player))
    else
        ServerSend.Introductions(player, {}, {})
    end
end

local function IsInSayRange(player, other)
    local range = ChatMessage.MessageTypeSettings and ChatMessage.MessageTypeSettings['say']['range'] or 15
    local dx = other:getX() - player:getX()
    local dy = other:getY() - player:getY()
    return math.sqrt(dx * dx + dy * dy) <= range + 1
end

-- /introduce [name]: the players in /say range (or only args.target) now know the
-- character by the given name, the character name when none is given
RecvServer['Introduce'] = function(player, args)
    if not Introductions.isEnabled() or type(args) ~= 'table' then
        return
    end
    local knownAs = Introductions.cleanName(args['name'], player)
    local listeners = {}
    if type(args['target']) == 'string' then
        local target = World.getPlayerByUsername(args['target'])
        if target and target ~= player and IsInSayRange(player, target) then
            table.insert(listeners, target)
        end
    else
        local players = getOnlinePlayers()
        for index = 0, players:size() - 1 do
            local other = players:get(index)
            if other:getOnlineID() ~= player:getOnlineID() and IsInSayRange(player, other) then
                table.insert(listeners, other)
            end
        end
    end
    local stranger = CharacterSheets.getStranger(player)
    local recipients = {}
    for _, listener in ipairs(listeners) do
        local entry, reverse = Introductions.introduce(player, listener, knownAs)
        entry.stranger = stranger
        ServerSend.Command(listener, 'Introduced', entry)
        table.insert(recipients, reverse)
    end
    -- the author learns who knows them now (the introduce panel shows it)
    ServerSend.Command(player, 'IntroductionSent', { knownAs = knownAs, count = #listeners, recipients = recipients })
end

-- /resetintroductions (admins): everybody forgets every introduction, the connected clients too
RecvServer['AdminResetIntroductions'] = function(player, args)
    if not Character.isAdmin(player) then
        return
    end
    print('TICS info: every introduction was reset by ' .. player:getUsername())
    Introductions.resetAll()
    local players = getOnlinePlayers()
    for index = 0, players:size() - 1 do
        ServerSend.Introductions(players:get(index), {}, {})
    end
    ServerSend.Command(player, 'IntroductionsReset', { reset = true })
end

local function OnClientCommand(module, command, player, args)
    if module == 'TICS' and RecvServer[command] then
        RecvServer[command](player, args)
    end
end


Events.OnClientCommand.Add(OnClientCommand)
