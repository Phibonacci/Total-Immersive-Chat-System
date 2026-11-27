local AvatarIO   = require('tics/shared/utils/AvatarIO')
local Character  = require('tics/shared/utils/Character')
local File       = require('tics/shared/utils/File')
local ServerSend = require('tics/server/network/ServerSend')
local World      = require('tics/shared/utils/World')


local AvatarManager = {}

function AvatarManager:loadPlayerAvatar(player)
    local avatar = AvatarIO.loadPlayerAvatar('approved', player)
    if avatar == nil then -- just to make it clear
        return nil
    end
    local key = AvatarIO.createFileNameFromPlayer(player)
    self.avatars[key] = avatar
end

function AvatarManager:freePlayerAvatar(player)
    local key = AvatarIO.createFileNameFromPlayer(player)
    self.avatars[key] = nil
end

function AvatarManager:registerPlayerAvatars(player, avatars)
    if self.players[player:getUsername()] == nil then
        self.players[player:getUsername()] = {}
    end
    self.players[player:getUsername()]['approved'] = avatars
    if self.players[player:getUsername()]['pending'] == nil then
        self.players[player:getUsername()]['pending'] = {}
    end
end

function AvatarManager:loadPendingAvatarsData()
    if self.pendingAvatarsStored == nil then
        self.pendingAvatarsStored = ModData.getOrCreate('ticsPendingAvatars')
    end
end

function AvatarManager:loadPendingAvatar(key, avatar)
    local username = avatar['username']
    local firstName = avatar['firstName']
    local lastName = avatar['lastName']
    local checksum = avatar['checksum']
    local playerAvatar = AvatarIO.loadPlayerAvatarFromNames('pending', username, firstName, lastName)
    if playerAvatar ~= nil then
        if checksum ~= playerAvatar['checksum'] then
            print(
                'TICS error: pending avatar for user "' ..
                username ..
                '" and character "' ..
                firstName ..
                ' ' ..
                lastName ..
                '" does not match the one sent by the player, if you tried to ' ..
                'upload an avatar on the server through FTP you should move it ' ..
                'directly in the "approved" directory')
            self:removePendingAvatar(playerAvatar['username'], playerAvatar['firstName'], playerAvatar['lastName'])
            return
        end
        self.pendingAvatarsShared[key] = {
            data = playerAvatar['data'],
            checksum = playerAvatar['checksum'],
            username = username,
            firstName = firstName,
            lastName = lastName,
            extension = playerAvatar['extension'],
        }
    end
end

function AvatarManager:loadPendingAvatars()
    if self.pendingAvatarsStored == nil then
        self:loadPendingAvatarsData()
        self.pendingAvatarsShared = {}
        for key, avatar in pairs(self.pendingAvatarsStored) do
            self:loadPendingAvatar(key, avatar)
        end
    end
end

function AvatarManager:trackPlayersOnline()
    local newConnectedPlayers = {}
    World.forAllPlayers(
        function(player)
            local username = player:getUsername()
            local firstName, lastName = Character.getFirstAndLastName(player)
            if not self.connectedPlayers[username] then
                self:loadPlayerAvatar(player)
            elseif self.charactersNames[username] and
                (self.charactersNames[username]['firstName'] ~= firstName or
                    self.charactersNames[username]['lastName'] ~= lastName)
            then
                self:loadPlayerAvatar(player)
            end
            self.charactersNames[username] = {
                firstName = firstName,
                lastName = lastName,
            }
            newConnectedPlayers[username] = player
        end
    )
    for username, player in pairs(self.connectedPlayers) do
        if newConnectedPlayers[username] == nil then
            self.players[username] = nil
            self:freePlayerAvatar(player)
        end
    end
    self.connectedPlayers = newConnectedPlayers
end

function AvatarManager:sendApprovedAvatars(playerUsername, playerAvatars)
    for key, avatar in pairs(self.avatars) do
        local storedAvatarChecksum = avatar['checksum']
        local playerAvatarChecksum = playerAvatars[key]
        if playerAvatarChecksum ~= storedAvatarChecksum then
            local player = self.connectedPlayers[playerUsername]
            if player ~= nil then
                ServerSend.ApprovedAvatar(player, storedAvatarChecksum,
                    avatar['username'], avatar['firstName'], avatar['lastName'],
                    avatar['data'], avatar['extension'])
                playerAvatars[key] = storedAvatarChecksum
            else
                print('TICS error: sendApprovedAvatars: player not found: ' .. playerUsername)
                break
            end
        end
    end
end

function AvatarManager:sendPendingAvatars(playerUsername, playerAvatars)
    local player = self.connectedPlayers[playerUsername]
    if player == nil then
        print('TICS error: sendPendingAvatars: player not found: ' .. playerUsername)
        return
    end
    if not Character.canValidateAvatars(player) then
        return
    end
    for key, avatar in pairs(self.pendingAvatarsShared) do
        local storedAvatarChecksum = avatar['checksum']
        local playerAvatarChecksum = playerAvatars[key]
        if playerAvatarChecksum ~= storedAvatarChecksum then
            ServerSend.PendingAvatar(player, storedAvatarChecksum,
                avatar['username'], avatar['firstName'], avatar['lastName'],
                avatar['data'], avatar['extension'])
            playerAvatars[key] = storedAvatarChecksum
        end
    end
end

function AvatarManager:sendAvatars()
    for playerUsername, playerAvatarCategories in pairs(self.players) do
        local approvedAvatars = playerAvatarCategories['approved']
        local pendingAvatars = playerAvatarCategories['pending']
        self:sendApprovedAvatars(playerUsername, approvedAvatars)
        self:sendPendingAvatars(playerUsername, pendingAvatars)
    end
end

function AvatarManager:removePendingAvatar(username, firstName, lastName)
    if self.pendingAvatarsStored == nil then
        AvatarManager:loadPendingAvatarsData()
    end
    local avatars = ModData.getOrCreate('ticsPendingAvatars')
    local key = AvatarIO.createFileName(username, firstName, lastName)
    avatars[key] = nil
    ModData.add('ticsPendingAvatars', avatars)
    local path = nil
    if self.pendingAvatarsStored[key] then
        path = self.pendingAvatarsStored[key]['path']
    end
    self.pendingAvatarsStored[key] = nil
    self.pendingAvatarsShared[key] = nil
    return path
end

function AvatarManager:removePendingAvatarAndDeleteFile(username, firstName, lastName)
    local path = self:removePendingAvatar(username, firstName, lastName)
    File.remove(path)
end

function AvatarManager:updatePendingAvatarStored(username, firstName, lastName, extension, checksum, data)
    if self.pendingAvatarsStored == nil then
        AvatarManager:loadPendingAvatarsData()
    end
    local avatars = ModData.getOrCreate('ticsPendingAvatars')
    local path = '/pending'
    AvatarIO.savePlayerAvatar(username, firstName, lastName, extension, data, path)
    local key = AvatarIO.createFileName(username, firstName, lastName)
    local pendingAvatarInfo = {
        path = path,
        checksum = checksum,
        username = username,
        firstName = firstName,
        lastName = lastName,
        extension = extension,
    }
    avatars[key] = pendingAvatarInfo
    ModData.add('ticsPendingAvatars', avatars)
    self.pendingAvatarsStored[key] = pendingAvatarInfo
    return key, pendingAvatarInfo
end

-- we could additionally store the data in a table directly, but we could not
-- guarantee the image was successfully saved
function AvatarManager:registerAvatarRequest(username, firstName, lastName, extension, checksum, data)
    local key, pendingAvatarInfo = self:updatePendingAvatarStored(username, firstName, lastName, extension, checksum,
        data)
    self:loadPendingAvatar(key, pendingAvatarInfo)
end

-- the pending request of the player's current character (nil if none) is sent to them,
-- it is shown in their avatar window
function AvatarManager:sendOwnPendingAvatar(player)
    self:loadPendingAvatars()
    local key = AvatarIO.createFileNameFromPlayer(player)
    local avatar = self.pendingAvatarsShared and self.pendingAvatarsShared[key]
    if avatar then
        ServerSend.OwnPendingAvatar(player, avatar['checksum'], avatar['extension'], avatar['data'])
    else
        ServerSend.OwnPendingAvatar(player, nil, nil, nil)
    end
end

function AvatarManager:update()
    local currentTime = Calendar.getInstance():getTimeInMillis()
    local elapsed = currentTime - self.previousTime
    if elapsed < 500 then
        return
    end
    self:loadPendingAvatars()
    self:trackPlayersOnline()
    self:sendAvatars()
    self.previousTime = currentTime
end

function AvatarManager:notifyAvatarProcessed(username, firstName, lastName, checksum)
    local owner = self.connectedPlayers[username]
    if owner then
        local ownerFirstName, ownerLastName = Character.getFirstAndLastName(owner)
        if ownerFirstName == firstName and ownerLastName == lastName then
            self:sendOwnPendingAvatar(owner) -- no longer pending
        end
    end
    for _, player in pairs(self.connectedPlayers) do
        if Character.canValidateAvatars(player) then
            ServerSend.AvatarProcessed(player, username, firstName, lastName, checksum)
        end
        local key = AvatarIO.createFileName(username, firstName, lastName)
        if self.players and
            self.players[player:getUsername()] and
            self.players[player:getUsername()]['pending']
        then
            self.players[player:getUsername()]['pending'][key] = nil
        end
    end
end

-- Index of the approved avatars: the file names (username_firstname_lastname) cannot be split
-- back reliably when a name contains '_'. Avatars without an entry (copied by hand in the
-- approved directory) are listed from their file name.
local APPROVED_INDEX_KEY = 'ticsApprovedAvatarIndex'

local function SetApprovedIndex(username, firstName, lastName, present)
    local index = ModData.getOrCreate(APPROVED_INDEX_KEY)
    local key = AvatarIO.createFileName(username, firstName, lastName)
    if present then
        index[key] = { username = username, firstName = firstName, lastName = lastName }
    else
        index[key] = nil
    end
    ModData.add(APPROVED_INDEX_KEY, index)
end

-- every approved avatar: array of { username, firstName, lastName }, sorted by username
function AvatarManager:getApprovedAvatarList()
    local index = ModData.getOrCreate(APPROVED_INDEX_KEY)
    local directory = AvatarIO.getBasePath() .. 'approved'
    local list = {}
    local seen = {}
    for _, fileName in ipairs(File.listFiles(directory) or {}) do
        local key, extension = fileName:match('^(.+)%.(%w+)$')
        extension = extension and extension:lower()
        if key and not seen[key] and (extension == 'png' or extension == 'jpg' or extension == 'jpeg')
            and not File.isEmpty(directory .. '/' .. fileName)
        then
            local entry = index[key]
            if entry == nil then
                local username, firstName, lastName = key:match('^(.+)_([^_]*)_([^_]*)$')
                if username then
                    entry = { username = username, firstName = firstName, lastName = lastName }
                end
            end
            if entry then
                seen[key] = true
                table.insert(list, {
                    username = entry.username, firstName = entry.firstName, lastName = entry.lastName,
                })
            end
        end
    end
    table.sort(list, function(a, b)
        if a.username:lower() ~= b.username:lower() then
            return a.username:lower() < b.username:lower()
        end
        return (a.firstName .. a.lastName):lower() < (b.firstName .. b.lastName):lower()
    end)
    return list
end

-- an approved avatar sent to an admin for the avatar management window
function AvatarManager:sendApprovedAvatarTo(admin, username, firstName, lastName)
    local avatar = AvatarIO.loadPlayerAvatarFromNames('approved', username, firstName, lastName)
    if avatar == nil then
        return
    end
    ServerSend.ApprovedAvatar(admin, avatar['checksum'], username, firstName, lastName,
        avatar['data'], avatar['extension'])
    local key = AvatarIO.createFileName(username, firstName, lastName)
    local adminData = self.players[admin:getUsername()]
    if adminData and adminData['approved'] then
        adminData['approved'][key] = avatar['checksum']
    end
end

-- the player deletes their own approved avatar, no admin approval needed
function AvatarManager:deleteAvatar(player)
    local firstName, lastName = Character.getFirstAndLastName(player)
    self:deleteAvatarOf(player:getUsername(), firstName, lastName)
end

-- deletes the approved avatar of any character (owner or admin)
function AvatarManager:deleteAvatarOf(username, firstName, lastName)
    local key = AvatarIO.createFileName(username, firstName, lastName)
    AvatarIO.removePlayerAvatar('approved', username, firstName, lastName)
    SetApprovedIndex(username, firstName, lastName, false)
    self.avatars[key] = nil
    for connectedUsername, connectedPlayer in pairs(self.connectedPlayers) do
        -- forget that the player got it, a new avatar for this character will be sent again
        if self.players[connectedUsername] and self.players[connectedUsername]['approved'] then
            self.players[connectedUsername]['approved'][key] = nil
        end
        ServerSend.AvatarDeleted(connectedPlayer, username, firstName, lastName)
    end
end

function AvatarManager:approveAvatar(admin, username, firstName, lastName, checksum)
    local key = AvatarIO.createFileName(username, firstName, lastName)
    local avatar = self.pendingAvatarsShared[key]
    local adminName = admin:getUsername()
    if avatar == nil then
        print('TICS error: avatar approved by ' .. adminName .. ' not found for ' ..
            username ..
            ' "' .. firstName .. ' ' .. lastName .. '" (' .. checksum .. ')')
        return
    end
    if checksum ~= avatar['checksum'] then
        print('TICS error: avatar approved by ' .. adminName .. ' outdated for ' ..
            username ..
            ' "' .. firstName .. ' ' .. lastName .. '" (' .. checksum .. ')')
        return
    end
    local extension = avatar['extension']
    local data = avatar['data']
    assert(extension ~= nil, 'TICS error: not extension found for pending avatar ' ..
        username ..
        ' "' .. firstName .. ' ' .. lastName .. '" (' .. checksum .. ')')
    assert(data ~= nil, 'TICS error: not data found for pending avatar ' ..
        username ..
        ' "' .. firstName .. ' ' .. lastName .. '" (' .. checksum .. ')')
    AvatarIO.savePlayerAvatar(username, firstName, lastName, extension, data, 'approved')
    SetApprovedIndex(username, firstName, lastName, true)
    if self.connectedPlayers[username] then -- players is online so we load the avatar
        local player = self.connectedPlayers[username]
        self:loadPlayerAvatar(player)
    end
    self:removePendingAvatarAndDeleteFile(username, firstName, lastName)
    self:notifyAvatarProcessed(username, firstName, lastName, checksum)
end

function AvatarManager:rejectAvatar(admin, username, firstName, lastName, checksum)
    local key = AvatarIO.createFileName(username, firstName, lastName)
    local avatar = self.pendingAvatarsShared[key]
    local adminName = admin:getUsername()
    if avatar == nil then
        print('TICS error: avatar rejected by ' .. adminName .. ' not found for ' ..
            username ..
            ' "' .. firstName .. ' ' .. lastName .. '" (' .. checksum .. ')')
        return
    end
    if checksum ~= avatar['checksum'] then
        print('TICS error: avatar rejected by ' .. adminName .. ' outdated for ' ..
            username ..
            ' "' .. firstName .. ' ' .. lastName .. '" (' .. checksum .. ')')
        return
    end
    self:removePendingAvatarAndDeleteFile(username, firstName, lastName)
    self:notifyAvatarProcessed(username, firstName, lastName, checksum)
end

local function CreateAvatarManager()
    local o = {}
    setmetatable(o, AvatarManager)
    AvatarManager.__index = AvatarManager
    o.players = {}
    o.avatars = {}
    o.pendingAvatarsStored = nil
    o.pendingAvatarsShared = nil
    o.connectedPlayers = {}
    o.charactersNames = {}
    o.previousTime = 0
    return o
end

local instance = CreateAvatarManager()

if not isClient() then
    Events.OnTick.Add(function() instance:update() end)
end

-- Since a lua file is only read once, this file will always return the same
-- value. Making this a singleton that cannot be missused.
return instance
