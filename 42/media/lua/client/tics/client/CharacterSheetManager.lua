-- Character sheets received from the server (the player's own one and the examined ones),
-- the server stores them (server/tics/server/CharacterSheets.lua).

local ClientSend = require('tics/client/network/ClientSend')

local CharacterSheetManager = {}

-- limits of the server, the input boxes do not accept more
CharacterSheetManager.MaxLengths = {
    title = 60,
    background = 3000,
    ooc = 1000,
    stranger = 60, -- how strangers see the character (introductions)
}

local sheets = {}
local listeners = {}

-- function(sheet) called for every sheet received (the journal saves them)
function CharacterSheetManager.addListener(listener)
    table.insert(listeners, listener)
end

-- received from the server: { username, firstName, lastName, title, background, ooc }
function CharacterSheetManager.setSheet(sheet)
    if type(sheet) ~= 'table' or type(sheet.username) ~= 'string' then
        return
    end
    sheet.title = sheet.title or ''
    sheet.background = sheet.background or ''
    sheet.ooc = sheet.ooc or ''
    sheet.stranger = sheet.stranger or ''
    sheet.receivedAt = getTimestampMs()
    sheets[sheet.username:lower()] = sheet
    for _, listener in ipairs(listeners) do
        listener(sheet)
    end
end

function CharacterSheetManager.getSheet(username)
    return sheets[username:lower()]
end

function CharacterSheetManager.ask(username)
    ClientSend.sendAskCharacterSheet(username)
end

function CharacterSheetManager.save(title, background, ooc, stranger)
    ClientSend.sendSetCharacterSheet(title, background, ooc, stranger)
end

function CharacterSheetManager.isEnabled()
    return TicsServerSettings ~= nil and TicsServerSettings['options'] ~= nil
        and TicsServerSettings['options']['characterSheet'] == true
end

return CharacterSheetManager
