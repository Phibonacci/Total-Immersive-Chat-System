-- Persists client-side TICS settings (player color, voice pitch, toggles...) to a file.
--
-- In build 42 the global ModData is never written to disk by a multiplayer client
-- (GameWindow.save only saves the world map when GameClient.clientSave is set),
-- so anything stored there is lost after a restart. We store the settings in
-- Zomboid/Lua/TICS/settings/<save name>.txt instead. The save name is the same
-- as the one used by the game: '<ip>_<port>_<hashed username>' in multiplayer,
-- so settings stay per server and per account like they used to in build 41.

local ClientSettings = {}

local SETTINGS_DIRECTORY = 'TICS/settings/'

local function GetSettingsPath()
    local world = getWorld()
    local saveName = world and world:getWorld() or nil
    if saveName == nil or saveName == '' then
        saveName = 'default'
    end
    saveName = saveName:gsub('[^%w%-_%.]', '_')
    return SETTINGS_DIRECTORY .. saveName .. '.txt'
end

local function SerializeValue(value)
    local valueType = type(value)
    if valueType == 'boolean' then
        return 'b:' .. tostring(value)
    elseif valueType == 'number' then
        return 'n:' .. tostring(value)
    elseif valueType == 'string' then
        return 's:' .. value
    elseif valueType == 'table' then
        local numbers = {}
        for key, number in pairs(value) do
            if type(key) ~= 'number' or type(number) ~= 'number' then
                return nil
            end
        end
        for _, number in ipairs(value) do
            table.insert(numbers, tostring(number))
        end
        return 'l:' .. table.concat(numbers, ',')
    end
    return nil
end

local function DeserializeValue(serialized)
    local valueType, raw = serialized:match('^(%a):(.*)$')
    if valueType == 'b' then
        return raw == 'true'
    elseif valueType == 'n' then
        return tonumber(raw)
    elseif valueType == 's' then
        return raw
    elseif valueType == 'l' then
        local list = {}
        for number in raw:gmatch('[^,]+') do
            local parsed = tonumber(number)
            if parsed == nil then
                return nil
            end
            table.insert(list, parsed)
        end
        return list
    end
    return nil
end

-- Returns the settings stored on disk as a table, or an empty table if there are none.
function ClientSettings.load()
    local settings = {}
    local reader = getFileReader(GetSettingsPath(), false)
    if reader == nil then
        return settings
    end
    while true do
        local line = reader:readLine()
        if line == nil then
            break
        end
        local key, serialized = line:match('^([^=]+)=(.*)$')
        if key ~= nil then
            local value = DeserializeValue(serialized)
            if value ~= nil then
                settings[key] = value
            end
        end
    end
    reader:close()
    return settings
end

-- Writes the given table to disk, overwriting the previous settings.
-- Only booleans, numbers, strings and lists of numbers are saved.
function ClientSettings.save(settings)
    local writer = getFileWriter(GetSettingsPath(), true, false)
    if writer == nil then
        print('TICS error: ClientSettings.save: failed to open settings file: ' .. GetSettingsPath())
        return
    end
    for key, value in pairs(settings) do
        local serialized = SerializeValue(value)
        if type(key) == 'string' and serialized ~= nil then
            writer:writeln(key .. '=' .. serialized)
        end
    end
    writer:close()
end

return ClientSettings
