-- The state of the characters changes how they speak and hear (each effect is a sandbox option).
--
-- Speaker, applied before the message is sent so everyone sees the same line:
--   drunk:  slurred words ("shee", "yeaah") and hiccups, more as the moodle grows
--   panic:  stuttering ("I-I saw them")
--   mask:   a gas mask, respirator, welding mask or hazmat hood muffles words ("mmf")
-- Listener, applied to what the player receives:
--   walls: walls, closed doors and windows, floors between the speaker and the player muffle
--          the speech, "(muffled)" with lost words, "(muffled voices)" when nothing gets through
--   Hard of Hearing: some words are lost ("..."), more for a whisper or a far speaker
--   Deaf: speech is not heard at all, only "(inaudible)"
-- Only speech is changed (whisper, low, say, yell and their radio versions), never /me, /do,
-- OOC or private messages.

local SpeechEffects = {}

local SPEECH = { whisper = true, low = true, say = true, yell = true }

-- The effects must stay fun to read: players who struggle to understand each other end up
-- asking their admin to disable them. Changes that keep the word readable (slur, stutter, half
-- muffled word) can be more frequent than lost words.

-- chance for each word to be changed, by moodle level (1 to 4)
local DRUNK_CHANCE = { 0.08, 0.15, 0.25, 0.35 }
local DRUNK_HICCUP_CHANCE = 0.35 -- per line, from level 3
local PANIC_CHANCE = { 0.05, 0.1, 0.18, 0.25 }
local MASK_CHANCE = 0.1 -- about 1 word in 10
-- drunk, panic and mask together never change more than this share of the words of a line
local MAX_CHANGED_SHARE = 1 / 3
-- Hard of Hearing: chance for each word to be lost, by volume, plus up to DISTANCE_LOSS at the
-- edge of the range of the channel
local HEARING_LOSS = { whisper = 0.35, low = 0.2, say = 0.1, yell = 0.03 }
local DISTANCE_LOSS = 0.1
-- walls: chance for each word to be lost, by number of barriers (wall, closed door or window,
-- floor) from 1. Past the end of a list nothing is understood ("(muffled voices)").
local WALL_LOSS = {
    whisper = {},
    low = { 0.5 },
    say = { 0.2, 0.4, 0.8 },
    yell = { 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8 },
}

local MUFFLED = { 'mmf', 'mph', 'mmh' }
local VOWELS = 'aeiouyAEIOUY'

local function Chance(probability)
    return ZombRandFloat(0, 1) < probability
end

local function Pick(list)
    return list[ZombRand(#list) + 1]
end

local function IsEnabled(name)
    local options = TicsServerSettings and TicsServerSettings['options']
    local effects = options and options['speechEffects']
    return effects ~= nil and effects[name] == true
end

function SpeechEffects.isSpeech(channel)
    return SPEECH[channel] == true
end

-- Calls change(core) for the words of the text and puts back what it returns, the
-- punctuation and markdown asterisks around the words are kept as they are.
-- words the speaker effects may still change in the line being said (nil: no limit)
local changesLeft = nil

local function MapWords(text, change)
    return (text:gsub('%S+', function(word)
        local before, core, after = word:match('^(%p*)(.-)(%p*)$')
        if core == nil or core == '' or (changesLeft and changesLeft <= 0) then
            return word
        end
        local changed = change(core)
        if changed ~= core and changesLeft then
            changesLeft = changesLeft - 1
        end
        return before .. changed .. after
    end))
end

---------------------------------------------------------------------------- speaker

local function Slur(text, level)
    local chance = DRUNK_CHANCE[level]
    return MapWords(text, function(word)
        if not Chance(chance) then
            return word
        end
        if word:find('[sS]') and Chance(0.6) then
            -- "so" -> "sho", "So" -> "Sho", "SO" -> "SHO"
            local h = word == word:upper() and 'H' or 'h'
            return (word:gsub('([sS])', '%1' .. h, 1))
        end
        -- stretch the first vowel: "yeah" -> "yeaah"
        local index = word:find('[' .. VOWELS .. ']')
        if index then
            local vowel = word:sub(index, index)
            return word:sub(1, index) .. vowel .. word:sub(index + 1)
        end
        return word
    end)
end

-- very drunk: sometimes a hiccup after a random word, as an emphasized aside (markdown), added
-- after the other effects so it is not stuttered or muffled
local function Hiccup(text)
    if text:find('*', 1, true) or not Chance(DRUNK_HICCUP_CHANCE) then
        return text
    end
    local words = {}
    for word in text:gmatch('%S+') do
        table.insert(words, word)
    end
    if #words < 2 then
        return text
    end
    local index = ZombRand(#words - 1) + 1
    words[index] = words[index] .. ' *hic*'
    return table.concat(words, ' ')
end

local function Stutter(text, level)
    local chance = PANIC_CHANCE[level]
    return MapWords(text, function(word)
        local first = word:sub(1, 1)
        if first:match('%d') or not Chance(chance) then
            return word
        end
        local repeats = level >= 4 and Chance(0.5) and 2 or 1
        return string.rep(first .. '-', repeats) .. word
    end)
end

-- the start of the word stays, the end is lost in the mask: "station" -> "stamph"
local function Muffle(text)
    return MapWords(text, function(word)
        if #word > 2 and Chance(MASK_CHANCE) then
            local sound = Pick(MUFFLED)
            if word == word:upper() then
                sound = sound:upper()
            end
            return word:sub(1, math.floor(#word / 2)) .. sound
        end
        return word
    end)
end

local MASK_TAGS = { 'GAS_MASK', 'GAS_MASK_NO_FILTER', 'IMPROVISED_GAS_MASK', 'RESPIRATOR', 'RESPIRATOR_NO_FILTER',
    'WELDING_MASK', 'HAZMAT_SUIT', 'SCBA' }

local function WearsMask(player)
    local worn = player:getWornItems()
    for index = 0, worn:size() - 1 do
        local item = worn:get(index):getItem()
        if item then
            for _, tag in ipairs(MASK_TAGS) do
                if ItemTag[tag] and item:hasTag(ItemTag[tag]) then
                    return true
                end
            end
        end
    end
    return false
end

-- the message the player says, changed by their state
function SpeechEffects.speak(player, text, channel)
    if not SpeechEffects.isSpeech(channel) or player == nil then
        return text
    end
    local words = 0
    for _ in text:gmatch('%S+') do
        words = words + 1
    end
    changesLeft = math.max(1, math.floor(words * MAX_CHANGED_SHARE))
    local moodles = player:getMoodles()
    local drunkLevel = 0
    if IsEnabled('drunk') then
        drunkLevel = math.min(moodles:getMoodleLevel(MoodleType.DRUNK), 4)
        if drunkLevel > 0 then
            text = Slur(text, drunkLevel)
        end
    end
    if IsEnabled('panic') then
        local level = moodles:getMoodleLevel(MoodleType.PANIC)
        if level > 0 then
            text = Stutter(text, math.min(level, 4))
        end
    end
    if IsEnabled('mask') and WearsMask(player) then
        text = Muffle(text)
    end
    changesLeft = nil
    if drunkLevel >= 3 then
        text = Hiccup(text)
    end
    return text
end

---------------------------------------------------------------------------- listener

local function LoseWords(text, chance)
    local words = {}
    local lost = false
    for word in text:gmatch('%S+') do
        -- a word holding a markdown asterisk is kept, not to leave an emphasis unclosed
        if not word:find('*', 1, true) and Chance(chance) then
            lost = true
            -- several lost words in a row are one "..."
            if words[#words] ~= '...' then
                table.insert(words, '...')
            end
        else
            table.insert(words, word)
        end
    end
    if not lost then
        return text
    end
    return table.concat(words, ' ')
end

-- materials of the walls sound goes through: wire mesh fences, bar fences and railings
local OPEN_MATERIALS = { MetalWire = true, MetalBars = true }

-- true when the walls on one edge of a square (its north or west side, where the game stores
-- them) are all open (wire mesh, bars): sound goes through them
local function IsOpenEdge(square, collideFlag)
    local objects = square:getObjects()
    local open = false
    for index = 0, objects:size() - 1 do
        local properties = objects:get(index):getProperties()
        if properties and properties:has(collideFlag) then
            if not OPEN_MATERIALS[properties:get('Material')] then
                return false
            end
            open = true
        end
    end
    return open
end

-- A blocked step between two side by side squares, unless only wire mesh or bars are in the way.
local function IsBarrier(from, to)
    if not from:isBlockedTo(to) then
        return false
    end
    -- the wall between them is on the north or west side of the one further south or east
    if to:getX() > from:getX() then
        return not IsOpenEdge(to, IsoFlagType.collideW)
    elseif to:getX() < from:getX() then
        return not IsOpenEdge(from, IsoFlagType.collideW)
    elseif to:getY() > from:getY() then
        return not IsOpenEdge(to, IsoFlagType.collideN)
    end
    return not IsOpenEdge(from, IsoFlagType.collideN)
end

local STAIRS_RADIUS = 2 -- squares around a character where stairs let the sound between two floors

-- true when the character is on or near stairs: a stairs square, or the opening above one
local function NearStairs(cell, character)
    local x, y, z = math.floor(character:getX()), math.floor(character:getY()), math.floor(character:getZ())
    for dx = -STAIRS_RADIUS, STAIRS_RADIUS do
        for dy = -STAIRS_RADIUS, STAIRS_RADIUS do
            local square = cell:getGridSquare(x + dx, y + dy, z)
            if square and (square:HasStairs() or square:HasStairsBelow()) then
                return true
            end
        end
    end
    return false
end

-- Walls, closed doors and closed windows between two characters: the line between their
-- squares is walked one square at a time along x or y (the game only tells what is between
-- two side by side squares), each floor of difference counts as one more barrier, except the
-- one the stairs cross when one of them is on or near stairs. Wire mesh and bar fences do not
-- count.
-- Squares that are not loaded are not checked.
function SpeechEffects.countBarriers(from, to)
    local cell = getCell()
    local z = math.floor(from:getZ())
    local barriers = math.abs(math.floor(to:getZ()) - z)
    -- someone on or near the stairs hears, and is heard from, the next floor
    if barriers > 0 and (NearStairs(cell, from) or NearStairs(cell, to)) then
        barriers = barriers - 1
    end
    local x, y = math.floor(from:getX()), math.floor(from:getY())
    local x1, y1 = math.floor(to:getX()), math.floor(to:getY())
    local dx, dy = math.abs(x1 - x), math.abs(y1 - y)
    local sx = x < x1 and 1 or -1
    local sy = y < y1 and 1 or -1
    local ix, iy = 0, 0
    local current = cell:getGridSquare(x, y, z)
    for _ = 1, math.min(dx + dy, 200) do
        -- step along the axis whose next square border the line crosses first
        local tx = dx > 0 and (ix + 0.5) / dx or 1e9
        local ty = dy > 0 and (iy + 0.5) / dy or 1e9
        if tx < ty then
            x = x + sx
            ix = ix + 1
        else
            y = y + sy
            iy = iy + 1
        end
        local nextSquare = cell:getGridSquare(x, y, z)
        if current and nextSquare and IsBarrier(current, nextSquare) then
            barriers = barriers + 1
        end
        current = nextSquare
    end
    return barriers
end

-- What the player hears of a message. speaker: the IsoPlayer speaking, nil on a radio;
-- distance: between them, nil on a radio. Returns the text and whether the voice is heard.
function SpeechEffects.hear(player, text, channel, distance, speaker)
    if not SpeechEffects.isSpeech(channel) or player == nil then
        return text, true
    end
    local hearing = IsEnabled('hearing')
    if hearing and player:hasTrait(CharacterTrait.DEAF) then
        return getText('UI_TICS_Speech_inaudible'), false
    end
    local loss = 0
    if hearing and player:hasTrait(CharacterTrait.HARD_OF_HEARING) then
        loss = HEARING_LOSS[channel]
        local range = TicsServerSettings and TicsServerSettings[channel] and TicsServerSettings[channel]['range']
        if distance and range and range > 0 then
            loss = loss + DISTANCE_LOSS * math.min(1, distance / range)
        end
    end
    local barriers = 0
    if speaker and IsEnabled('walls') then
        barriers = SpeechEffects.countBarriers(speaker, player)
        if barriers > 0 then
            local wallLoss = WALL_LOSS[channel][barriers]
            if wallLoss == nil then
                return getText('UI_TICS_Speech_muffled_voices'), false
            end
            -- a word lost to the walls or to the ears
            loss = 1 - (1 - loss) * (1 - wallLoss)
        end
    end
    if loss > 0 then
        text = LoseWords(text, loss)
    end
    if barriers > 0 then
        text = getText('UI_TICS_Speech_muffled') .. ' ' .. text
    end
    return text, true
end

return SpeechEffects
