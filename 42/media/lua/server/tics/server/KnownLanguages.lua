-- Roleplay languages known by each character, stored on the server (global ModData is
-- saved by the server) so they are remembered across logins.
-- Languages are per character: the key is the username and the character name, a new
-- character (after a death for example) starts again with the default language only.

local Character = require('tics/shared/utils/Character')
local Languages = require('tics/shared/languages/Languages')

local KnownLanguages = {}

-- not 'ticsKnownLanguages': in single player the client used that key in the same global ModData
local MOD_DATA_KEY = 'ticsKnownLanguagesByCharacter'
local DEFAULT_LANGUAGE = 'English'
local DEFAULT_CODE = 'en'

local function GetKey(player)
    local firstName, lastName = Character.getFirstAndLastName(player)
    return player:getUsername() .. '_' .. firstName .. '_' .. lastName
end

local function IsValidLanguage(language, code)
    return type(language) == 'string' and Languages[language] ~= nil and Languages[language] == code
end

-- language name -> language code, always including the default language
function KnownLanguages.get(player)
    local stored = ModData.getOrCreate(MOD_DATA_KEY)[GetKey(player)]
    local languages = { [DEFAULT_LANGUAGE] = DEFAULT_CODE }
    if type(stored) == 'table' then
        for language, code in pairs(stored) do
            if IsValidLanguage(language, code) then
                languages[language] = code
            end
        end
    end
    return languages
end

function KnownLanguages.isKnown(player, language)
    return KnownLanguages.get(player)[language] ~= nil
end

function KnownLanguages.learn(player, language)
    local code = Languages[language]
    if not IsValidLanguage(language, code) then
        print('TICS error: KnownLanguages.learn: invalid language "' .. tostring(language) .. '"')
        return
    end
    local all = ModData.getOrCreate(MOD_DATA_KEY)
    local key = GetKey(player)
    local languages = KnownLanguages.get(player)
    languages[language] = code
    all[key] = languages
    ModData.add(MOD_DATA_KEY, all)
end

function KnownLanguages.forgetAll(player)
    local all = ModData.getOrCreate(MOD_DATA_KEY)
    all[GetKey(player)] = nil
    ModData.add(MOD_DATA_KEY, all)
end

return KnownLanguages
