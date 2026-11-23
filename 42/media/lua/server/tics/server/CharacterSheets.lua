-- Character sheets (title, personality & background, OOC notes) written by the players,
-- stored on the server per character (username and character name) like the known
-- languages, so a new character starts with an empty sheet.

local Character = require('tics/shared/utils/Character')

local CharacterSheets = {}

local MOD_DATA_KEY = 'ticsCharacterSheets'

CharacterSheets.MaxLengths = {
    title = 60,
    background = 3000,
    ooc = 1000,
}

local function GetKey(username, firstName, lastName)
    return username .. '_' .. firstName .. '_' .. lastName
end

local function GetPlayerKey(player)
    local firstName, lastName = Character.getFirstAndLastName(player)
    return GetKey(player:getUsername(), firstName, lastName)
end

-- no rich text markup (bubbles and chat use it), limited length, title on one line
local function Clean(text, maxLength, singleLine)
    if type(text) ~= 'string' then
        return ''
    end
    text = text:gsub('[<>]', '')
    if singleLine then
        text = text:gsub('[\r\n]+', ' ')
    end
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if #text > maxLength then
        text = text:sub(1, maxLength)
    end
    return text
end

-- { title, background, ooc }, empty strings when not written
function CharacterSheets.get(player)
    local sheet = ModData.getOrCreate(MOD_DATA_KEY)[GetPlayerKey(player)]
    return {
        title = sheet and sheet.title or '',
        background = sheet and sheet.background or '',
        ooc = sheet and sheet.ooc or '',
    }
end

function CharacterSheets.getTitle(player)
    local sheet = ModData.getOrCreate(MOD_DATA_KEY)[GetPlayerKey(player)]
    return sheet and sheet.title or ''
end

function CharacterSheets.set(player, sheet)
    local all = ModData.getOrCreate(MOD_DATA_KEY)
    local cleaned = {
        title = Clean(sheet.title, CharacterSheets.MaxLengths.title, true),
        background = Clean(sheet.background, CharacterSheets.MaxLengths.background, false),
        ooc = Clean(sheet.ooc, CharacterSheets.MaxLengths.ooc, false),
    }
    if cleaned.title == '' and cleaned.background == '' and cleaned.ooc == '' then
        all[GetPlayerKey(player)] = nil
    else
        all[GetPlayerKey(player)] = cleaned
    end
    ModData.add(MOD_DATA_KEY, all)
end

-- admins clear a sheet (inappropriate content), the character may be offline
function CharacterSheets.clear(username, firstName, lastName)
    local all = ModData.getOrCreate(MOD_DATA_KEY)
    all[GetKey(username, firstName, lastName)] = nil
    ModData.add(MOD_DATA_KEY, all)
end

return CharacterSheets
