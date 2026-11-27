-- Introductions (sandbox option, off by default): the player's character only knows the names
-- given by the characters who introduced themselves (/introduce, possibly a false name). The
-- others are shown with the description they wrote in their character sheet ("How strangers
-- see you"), or "a man" / "a woman" / "someone". Unknown voices on the radio are "unknown voice".
-- The server stores who knows whom (server/tics/server/Introductions.lua), the client only
-- chooses the name to display: the game sends every character name to every client anyway.

local Character = require('tics/shared/utils/Character')
local World = require('tics/shared/utils/World')

local Introductions = {}

local known = {}        -- 'username|First Last' -> name given in the introduction
local descriptions = {} -- 'username|First Last' -> how strangers see them, as last received
local knownBy = {}      -- 'username|First Last' -> name they know the player's character by

local function Key(username, name)
    return username:lower() .. '|' .. name
end

local function Options()
    local options = TicsServerSettings and TicsServerSettings['options']
    return options and options['introductions'] or nil
end

function Introductions.isEnabled()
    local options = Options()
    return options ~= nil and options['enabled'] == true
end

-- lists from the server: { { username, firstName, lastName, knownAs } }, the characters the
-- player's character knows and the ones who know them
function Introductions.setKnown(list, knownByList)
    known = {}
    knownBy = {}
    for _, entry in pairs(list or {}) do
        Introductions.addKnown(entry)
    end
    for _, entry in pairs(knownByList or {}) do
        Introductions.addKnownBy(entry)
    end
end

-- someone who now knows the player's character, as entry.knownAs
function Introductions.addKnownBy(entry)
    if type(entry) == 'table' and type(entry.username) == 'string' and type(entry.firstName) == 'string'
        and type(entry.lastName) == 'string' and type(entry.knownAs) == 'string'
    then
        knownBy[Key(entry.username, entry.firstName .. ' ' .. entry.lastName)] = entry.knownAs
    end
end

-- the name this character knows the player's character by, nil if they were never introduced
function Introductions.getKnownAs(username, name)
    return knownBy[Key(username, name)]
end

function Introductions.addKnown(entry)
    if type(entry) == 'table' and type(entry.username) == 'string' and type(entry.firstName) == 'string'
        and type(entry.lastName) == 'string' and type(entry.knownAs) == 'string'
    then
        known[Key(entry.username, entry.firstName .. ' ' .. entry.lastName)] = entry.knownAs
    end
end

function Introductions.rememberDescription(username, name, description)
    if type(username) == 'string' and type(name) == 'string' and type(description) == 'string' then
        descriptions[Key(username, name)] = description
    end
end

function Introductions.getDescription(username, name)
    return descriptions[Key(username, name)]
end

local function Capitalize(text)
    return (text:gsub('^%l', string.upper))
end

-- faction and safehouse members know each other (sandbox option)
local function SameGroup(username)
    local me = getPlayer():getUsername()
    local ok, same = pcall(function()
        local mine, theirs = Faction.getPlayerFaction(me), Faction.getPlayerFaction(username)
        if mine and theirs and mine:getName() == theirs:getName() then
            return true
        end
        local myHouse, theirHouse = SafeHouse.hasSafehouse(me), SafeHouse.hasSafehouse(username)
        return myHouse ~= nil and theirHouse ~= nil and myHouse:getTitle() == theirHouse:getTitle()
    end)
    return ok and same == true
end

-- true when the player's character knows this character by name (or introductions are off)
function Introductions.knows(username, name)
    if not Introductions.isEnabled() or username == nil or name == nil then
        return true
    end
    if username:lower() == getPlayer():getUsername():lower() or known[Key(username, name)] then
        return true
    end
    local options = Options()
    if options['staffSeeNames'] and Character.isAdminOrModerator(getPlayer()) then
        return true
    end
    return options['factionKnown'] == true and SameGroup(username)
end

-- How the player's character calls this character. username / name: the account and the
-- character name ('First Last'). opts.radio: heard on a radio, opts.description: a known
-- description (journal), opts.lowercase: not at the start of a sentence.
function Introductions.displayName(username, name, opts)
    opts = opts or {}
    if not Introductions.isEnabled() or username == nil or name == nil then
        return name
    end
    local key = Key(username, name)
    local isMe = username:lower() == getPlayer():getUsername():lower()
    local options = Options()
    if isMe or (options['staffSeeNames'] and Character.isAdminOrModerator(getPlayer())) then
        return name
    end
    if known[key] then
        return known[key]
    end
    if options['factionKnown'] and SameGroup(username) then
        return name
    end
    local text
    if opts.radio then
        text = getText('UI_TICS_Intro_unknown_voice')
    else
        text = descriptions[key] or opts.description
        if text == nil or text == '' then
            local player = World.getPlayerByUsername(username)
            if player == nil then
                text = getText('UI_TICS_Intro_someone')
            elseif player:isFemale() then
                text = getText('UI_TICS_Intro_a_woman')
            else
                text = getText('UI_TICS_Intro_a_man')
            end
        end
    end
    if opts.lowercase then
        return text
    end
    return Capitalize(text)
end

return Introductions
