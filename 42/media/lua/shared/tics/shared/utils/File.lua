local CRC32 = require('tics/shared/libs/crc32/crc32')


local File = {}

function File.exists(path)
    return serverFileExists('../Lua/' .. path)
end

function File.createDirectory(path, fileName)
    -- create useless file to ensure the directory is created
    local fullPath
    if fileName then
        fullPath = path .. '/' .. fileName
    else
        fullPath = path .. '/delete_me'
    end
    if serverFileExists('../Lua/' .. fullPath) then
        return
    end
    getFileOutput(fullPath)
    endFileOutput()
end

function File.readAllBytes(path)
    if path == nil then
        print('TICS error: File.readAllBytes: path is nil')
        return
    end
    local file = getFileInput(path)
    if file == nil then
        print('TICS error: File.readAllBytes: could not read avatar file at :"' .. path .. '"')
        return
    end
    local data = {}
    local checksum = CRC32.newcrc32()
    -- in build 42 a Java exception thrown by readUnsignedByte at the end of the file
    -- becomes a Lua error, so we check the remaining bytes before each read instead
    while file:available() > 0 do
        local byte = file:readUnsignedByte()
        checksum:update(byte)
        table.insert(data, byte)
    end
    endFileInput()
    return data, checksum
end

function File.writeAllBytes(data, path)
    local outFile = getFileOutput(path)
    if outFile == nil then
        print('TICS error: File.writeAllBytes: failed to write file in path: ' .. path)
        return
    end
    for _, byte in pairs(data) do
        outFile:writeByte(byte)
    end
    endFileOutput()
end

function File.writeStringWithNewLine(text, path)
    local outFile = getFileWriter(path, true, true)
    if outFile == nil then
        print('TICS error: File.writeString: failed to write file in path: ' .. path)
        return
    end
    outFile:writeln(text)
    outFile:close()
end

-- Absolute path of a file stored in the Zomboid/Lua directory.
function File.getAbsolutePath(path)
    local absolutePath = getMyDocumentFolder() .. '/Lua/' .. path
    return (absolutePath:gsub('\\', '/'):gsub('/+', '/'))
end

-- Loads a texture stored in the Zomboid/Lua directory.
function File.getTexture(path)
    if path == nil then
        return nil
    end
    return getTexture(File.getAbsolutePath(path))
end

-- true if the file does not exist or has no content (File.remove only empties files)
function File.isEmpty(path)
    if not File.exists(path) then
        return true
    end
    local file = getFileInput(path)
    if file == nil then
        return true
    end
    local empty = file:available() <= 0
    endFileInput()
    return empty
end

-- lists the files (not the directories) of a directory of Zomboid/Lua, nil if it does not exist
function File.listFiles(directory)
    local files = listFilesInZomboidLuaDirectory(directory)
    if files == nil then
        return nil
    end
    local result = {}
    for i = 0, files:size() - 1 do
        table.insert(result, files:get(i))
    end
    return result
end

function File.remove(path) -- we can only erase the bytes of the file, not the file
    File.writeAllBytes({}, path)
end

return File
