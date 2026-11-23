-- Character sheets received from the server (the player's own one and the examined ones),
-- the server stores them (server/tics/server/CharacterSheets.lua).

local ClientSend = require('tics/client/network/ClientSend')

local CharacterSheetManager = {}

-- limits of the server, the input boxes do not accept more
CharacterSheetManager.MaxLengths = {
    title = 60,
    background = 3000,
    ooc = 1000,
}

local sheets = {}

-- received from the server: { username, firstName, lastName, title, background, ooc }
function CharacterSheetManager.setSheet(sheet)
    if type(sheet) ~= 'table' or type(sheet.username) ~= 'string' then
        return
    end
    sheet.title = sheet.title or ''
    sheet.background = sheet.background or ''
    sheet.ooc = sheet.ooc or ''
    sheet.receivedAt = getTimestampMs()
    sheets[sheet.username:lower()] = sheet
end

function CharacterSheetManager.getSheet(username)
    return sheets[username:lower()]
end

function CharacterSheetManager.ask(username)
    ClientSend.sendAskCharacterSheet(username)
end

function CharacterSheetManager.save(title, background, ooc)
    ClientSend.sendSetCharacterSheet(title, background, ooc)
end

function CharacterSheetManager.isEnabled()
    return TicsServerSettings ~= nil and TicsServerSettings['options'] ~= nil
        and TicsServerSettings['options']['characterSheet'] == true
end

return CharacterSheetManager
