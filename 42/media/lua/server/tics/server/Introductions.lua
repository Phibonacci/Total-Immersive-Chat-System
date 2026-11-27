-- Introductions (sandbox option, off by default): a character only knows the name of the
-- characters who introduced themselves to them (/introduce), strangers are shown with the
-- description they wrote in their character sheet. A character may give a false name: the
-- name given is the one they are known by.
-- Stored per character (username and character name), like the character sheets: a new
-- character knows nobody.

local Character = require('tics/shared/utils/Character')

local Introductions = {}

local MOD_DATA_KEY = 'ticsIntroductions'
-- the same introductions seen from the other side: who knows a character, and by which name
local KNOWN_BY_KEY = 'ticsIntroductionsKnownBy'
Introductions.MaxNameLength = 40

local function Key(username, firstName, lastName)
    return username .. '_' .. firstName .. '_' .. lastName
end

local function PlayerKey(player)
    local firstName, lastName = Character.getFirstAndLastName(player)
    return Key(player:getUsername(), firstName, lastName), firstName, lastName
end

function Introductions.isEnabled()
    return SandboxVars.TICS.IntroductionsEnabled == true
end

-- the name given in /introduce: no markup, one line, limited; the character name when empty
function Introductions.cleanName(name, player)
    if type(name) == 'string' then
        name = name:gsub('[<>]', ''):gsub('[\r\n]+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
        if #name > Introductions.MaxNameLength then
            name = name:sub(1, Introductions.MaxNameLength)
        end
        if name ~= '' then
            return name
        end
    end
    local firstName, lastName = Character.getFirstAndLastName(player)
    return firstName .. ' ' .. lastName
end

-- array of { username, firstName, lastName, knownAs } the character of player knows
function Introductions.getKnown(player)
    local known = ModData.getOrCreate(MOD_DATA_KEY)[PlayerKey(player)]
    local list = {}
    for _, entry in pairs(known or {}) do
        table.insert(list, {
            username = entry.username, firstName = entry.firstName, lastName = entry.lastName, knownAs = entry.knownAs,
        })
    end
    return list
end

-- array of { username, firstName, lastName, knownAs }: the characters who know the
-- character of player, and the name they know them by
function Introductions.getKnownBy(player)
    local knownBy = ModData.getOrCreate(KNOWN_BY_KEY)[PlayerKey(player)]
    local list = {}
    for _, entry in pairs(knownBy or {}) do
        table.insert(list, {
            username = entry.username, firstName = entry.firstName, lastName = entry.lastName, knownAs = entry.knownAs,
        })
    end
    return list
end

-- The character of listener now knows the character of speaker as knownAs. Returns the
-- entry for the listener (who they now know) and the one for the speaker (who knows them).
function Introductions.introduce(speaker, listener, knownAs)
    local all = ModData.getOrCreate(MOD_DATA_KEY)
    local listenerKey, listenerFirstName, listenerLastName = PlayerKey(listener)
    local speakerKey, firstName, lastName = PlayerKey(speaker)
    all[listenerKey] = all[listenerKey] or {}
    local entry = { username = speaker:getUsername(), firstName = firstName, lastName = lastName, knownAs = knownAs }
    all[listenerKey][speakerKey] = entry
    ModData.add(MOD_DATA_KEY, all)

    local knownBy = ModData.getOrCreate(KNOWN_BY_KEY)
    knownBy[speakerKey] = knownBy[speakerKey] or {}
    local reverse = {
        username = listener:getUsername(), firstName = listenerFirstName, lastName = listenerLastName, knownAs = knownAs,
    }
    knownBy[speakerKey][listenerKey] = reverse
    ModData.add(KNOWN_BY_KEY, knownBy)
    return entry, reverse
end

-- every character forgets every introduction (admins, for tests or a fresh start)
function Introductions.resetAll()
    ModData.add(MOD_DATA_KEY, {})
    ModData.add(KNOWN_BY_KEY, {})
end

return Introductions
