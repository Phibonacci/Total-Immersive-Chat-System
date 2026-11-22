local ClientSend = require('tics/client/network/ClientSend')

local LanguageManager = {}

-- Known languages are stored on the server per character (server/tics/server/KnownLanguages.lua)
-- and sent to the client on login and when a language book is read (the server applies the
-- book, see ISReadLanguageBook). This key is the old client side storage, only read to migrate it.
local OldLanguageRegister = 'ticsKnownLanguages'

LanguageManager.DefaultLanguage = 'English'

local AllLanguages = require('tics/shared/languages/Languages')

local function DefaultKnownLanguages()
    return { [LanguageManager.DefaultLanguage] = AllLanguages[LanguageManager.DefaultLanguage] }
end

function LanguageManager:getKnownLanguagesAndInitialize()
    if self.knownLanguages == nil or self.knownLanguages[LanguageManager.DefaultLanguage] == nil then
        self.knownLanguages = DefaultKnownLanguages()
    end
    return self.knownLanguages
end

-- languages learnt before they were stored on the server (only saved in single player)
local function MigrateOldKnownLanguages(serverLanguages)
    local old = ModData.get(OldLanguageRegister)
    if type(old) ~= 'table' then
        return
    end
    for language, code in pairs(old) do
        if serverLanguages[language] == nil and AllLanguages[language] == code then
            ClientSend.sendLearnLanguage(language)
        end
    end
    ModData.remove(OldLanguageRegister)
end

-- list sent by the server: language name -> language code
function LanguageManager:setKnownLanguages(languages)
    local knownLanguages = DefaultKnownLanguages()
    for language, code in pairs(languages or {}) do
        if AllLanguages[language] == code then
            knownLanguages[language] = code
        end
    end
    self.knownLanguages = knownLanguages
    if knownLanguages[self.currentLanguage] == nil then
        self.currentLanguage = LanguageManager.DefaultLanguage
    end
    MigrateOldKnownLanguages(knownLanguages)
end

-- On login this is called once the sandbox vars are received (ISChat.onRecvSandboxVars):
-- the server drops the commands sent before it is ready to receive them.
function LanguageManager:askKnownLanguages()
    ClientSend.sendAskKnownLanguages()
end

function LanguageManager.GetLanguages()
    return AllLanguages
end

function LanguageManager.GetLanguageCode(languageName)
    return AllLanguages[languageName]
end

function LanguageManager:getKnownLanguages()
    return self:getKnownLanguagesAndInitialize()
end

function LanguageManager:isKnown(language)
    local knownLanguages = self:getKnownLanguagesAndInitialize()
    return knownLanguages[language] ~= nil
end

function LanguageManager:isCodeKnown(languageCode)
    local knownLanguages = self:getKnownLanguagesAndInitialize()
    for _, knownCode in pairs(knownLanguages) do
        if knownCode == languageCode then
            return true
        end
    end
    return false
end

function LanguageManager.LanguageExists(languageName)
    return AllLanguages[languageName] ~= nil
end

function LanguageManager.GetLanguageTranslatedFromCode(languageCode)
    return getText('UI_TICS_Languages_' .. languageCode)
end

function LanguageManager.GetCodeFromLanguage(language)
    return AllLanguages[language]
end

function LanguageManager.GetLanguageFromCode(languageCode)
    for language, code in pairs(AllLanguages) do
        if languageCode == code then
            return language
        end
    end
    return nil
end

function LanguageManager.GetLanguageTranslated(language)
    local languageCode = AllLanguages[language]
    return LanguageManager.GetLanguageTranslatedFromCode(languageCode)
end

function LanguageManager:setCurrentLanguageFromCode(languageCode)
    local knownLanguages = self:getKnownLanguagesAndInitialize()
    for knownLanguage, knownCode in pairs(knownLanguages) do
        if knownCode == languageCode then
            self.currentLanguage = knownLanguage
        end
    end
end

function LanguageManager:getCurrentLanguage()
    return self.currentLanguage
end

LanguageManager.UnknownCharacters = {
    -- 'ƒ', '¢', '¤', '¥', '§', '¬', '°', '¶', '×', 'ø', 'þ',
    0x83, 0xA2, 0xA4, 0xA5, 0xA7, 0xAC, 0xB0, 0xB6, 0xD7, 0xF8, 0xFE,
}
local newUnknownCharacters = {}
for _, c in pairs(LanguageManager.UnknownCharacters) do
    local newChar = string.char(c)
    table.insert(newUnknownCharacters, newChar)
end
LanguageManager.UnknownCharacters = newUnknownCharacters
LanguageManager.UnknownCharactersLen = #LanguageManager.UnknownCharacters

function LanguageManager:getRandomMessage(message)
    local newMessage = ''
    for i = 1, #message do
        local c = message:sub(i, i)
        if c == '.' or c == '?' or c == '!' or c == ' ' or c == '-' or
            c == ',' or c == ';' or c == '*' or c == '_'
        then
            newMessage = newMessage .. c
        else
            local randomIndex = ZombRand(LanguageManager.UnknownCharactersLen - 1) + 1
            newMessage = newMessage .. LanguageManager.UnknownCharacters[randomIndex]
        end
    end
    return newMessage
end

local function CreateLanguageManager()
    local o = {}
    setmetatable(o, LanguageManager)
    LanguageManager.__index = LanguageManager
    o.currentLanguage = LanguageManager.DefaultLanguage
    return o
end

local instance = CreateLanguageManager()

-- new character (after a death for example), the login case is handled by ISChat.onRecvSandboxVars
Events.OnCreatePlayer.Add(function() instance:askKnownLanguages() end)

return instance
