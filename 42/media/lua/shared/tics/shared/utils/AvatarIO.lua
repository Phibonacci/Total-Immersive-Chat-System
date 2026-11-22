local Character = require('tics/shared/utils/Character')
local File = require('tics/shared/utils/File')


local AvatarIO = {}

function AvatarIO.getBasePath()
    if isClient() then
        -- a client does not know the server name...
        return 'avatars/client/' .. getServerIP() .. '/'
    else
        local serverName = getServerName()
        if serverName == nil then
            serverName = 'unknown'
            print('TICS error: AvatarIO: unknown server name, using "unknown" directory for avatars')
        end
        return 'avatars/server/' .. serverName .. '/'
    end
end

AvatarIO.Extensions = { 'png', 'jpg', 'jpeg' }

-- a deleted avatar is an empty file (File.remove can only erase the content), it is skipped
function AvatarIO.getAvatarPath(partialPath)
    local basePath = AvatarIO.getBasePath()
    local pathPrefix = basePath .. '/' .. partialPath .. '.'
    for _, extension in ipairs(AvatarIO.Extensions) do
        local path = pathPrefix .. extension
        if not File.isEmpty(path) then
            return path, extension
        end
    end
    return nil
end

-- empties the avatar files of a character, whatever their extension
function AvatarIO.removePlayerAvatar(path, username, firstName, lastName)
    local pathPrefix = AvatarIO.getBasePath() .. '/' .. path .. '/' .. AvatarIO.createFileName(username, firstName, lastName) .. '.'
    for _, extension in ipairs(AvatarIO.Extensions) do
        if File.exists(pathPrefix .. extension) then
            File.remove(pathPrefix .. extension)
        end
    end
end

function AvatarIO.createFileName(username, firstName, lastName)
    return username .. '_' .. firstName .. '_' .. lastName
end

function AvatarIO.createFileNameFromPlayer(player)
    local username = player:getUsername()
    local firstName, lastName = Character.getFirstAndLastName(player)
    return AvatarIO.createFileName(username, firstName, lastName)
end

function AvatarIO.loadPlayerAvatarFromNames(path, username, firstName, lastName)
    local key = AvatarIO.createFileName(username, firstName, lastName)
    local partialPath = path .. '/' .. key
    local fullPath, extension = AvatarIO.getAvatarPath(partialPath)
    if fullPath == nil then
        return
    end
    local data, checksum = File.readAllBytes(fullPath)
    if data ~= nil and #data == 0 then
        return -- deleted avatar
    end
    if data == nil or checksum == nil then
        print('TICS error: failed to read file at path: "' .. fullPath .. '"')
        return
    end
    return {
        data = data,
        checksum = checksum:tonumber(),
        extension = extension,
        username = username,
        firstName = firstName,
        lastName = lastName,
    }
end

function AvatarIO.loadPlayerAvatar(path, player)
    local username = player:getUsername()
    local firstName, lastName = Character.getFirstAndLastName(player)
    return AvatarIO.loadPlayerAvatarFromNames(path, username, firstName, lastName)
end

function AvatarIO.savePlayerAvatar(username, firstName, lastName, extension, data, path)
    local basePath = AvatarIO.getBasePath()
    local fileName = AvatarIO.createFileName(username, firstName, lastName)
    local fullPath = basePath .. '/' .. path .. '/' .. fileName .. '.' .. extension
    -- an avatar with another extension would be found first by getAvatarPath
    AvatarIO.removePlayerAvatar(path, username, firstName, lastName)
    File.writeAllBytes(data, fullPath)
    return fullPath
end

return AvatarIO
