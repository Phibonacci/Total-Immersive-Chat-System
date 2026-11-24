-- The state of the characters changes how they speak and hear (each effect is a sandbox option).
--
-- Speaker, applied before the message is sent so everyone sees the same line:
--   drunk:  slurred words ("shee", "yeaah") and hiccups, more as the moodle grows
--   panic:  stuttering ("I-I saw them")
--   mask:   a gas mask, respirator, welding mask or hazmat hood muffles words ("mmf")
-- Listener, applied to what the player receives:
--   Hard of Hearing: some words are lost ("..."), more for a whisper or a far speaker
--   Deaf: speech is not heard at all, only "(inaudible)"
-- Only speech is changed (whisper, low, say, yell and their radio versions), never /me, /do,
-- OOC or private messages.

local SpeechEffects = {}

local SPEECH = { whisper = true, low = true, say = true, yell = true }

-- chance for each word to be changed, by moodle level (1 to 4)
local DRUNK_CHANCE = { 0.12, 0.25, 0.45, 0.65 }
local PANIC_CHANCE = { 0.08, 0.16, 0.3, 0.45 }
local MASK_CHANCE = 0.3
-- Hard of Hearing: chance for each word to be lost, by volume, plus up to DISTANCE_LOSS at the
-- edge of the range of the channel
local HEARING_LOSS = { whisper = 0.55, low = 0.4, say = 0.22, yell = 0.08 }
local DISTANCE_LOSS = 0.2

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
local function MapWords(text, change)
    return (text:gsub('%S+', function(word)
        local before, core, after = word:match('^(%p*)(.-)(%p*)$')
        if core == nil or core == '' then
            return word
        end
        return before .. change(core) .. after
    end))
end

---------------------------------------------------------------------------- speaker

local function Slur(text, level)
    local chance = DRUNK_CHANCE[level]
    local hiccups = level >= 3 and not text:find('*', 1, true)
    local result = MapWords(text, function(word)
        if not Chance(chance) then
            return word
        end
        if word:find('[sS]') and Chance(0.6) then
            -- "so" -> "sho", "SO" -> "SHO"
            return (word:gsub('([sS])', function(s) return s == 's' and 'sh' or 'SH' end, 1))
        end
        -- stretch the first vowel: "yeah" -> "yeaah"
        local index = word:find('[' .. VOWELS .. ']')
        if index then
            local vowel = word:sub(index, index)
            return word:sub(1, index) .. vowel .. word:sub(index + 1)
        end
        return word
    end)
    if hiccups and Chance(0.5) then
        -- after a random word, as an emphasized aside (markdown)
        local words = {}
        for word in result:gmatch('%S+') do
            table.insert(words, word)
        end
        if #words > 1 then
            local index = ZombRand(#words - 1) + 1
            words[index] = words[index] .. ' *hic*'
            result = table.concat(words, ' ')
        end
    end
    return result
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

local function Muffle(text)
    return MapWords(text, function(word)
        if #word > 2 and Chance(MASK_CHANCE) then
            return Pick(MUFFLED)
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
    local moodles = player:getMoodles()
    if IsEnabled('drunk') then
        local level = moodles:getMoodleLevel(MoodleType.DRUNK)
        if level > 0 then
            text = Slur(text, math.min(level, 4))
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

-- What the player hears of a message (nil distance: heard on a radio).
-- Returns the text and whether the voice can be heard.
function SpeechEffects.hear(player, text, channel, distance)
    if not SpeechEffects.isSpeech(channel) or player == nil or not IsEnabled('hearing') then
        return text, true
    end
    if player:hasTrait(CharacterTrait.DEAF) then
        return getText('UI_TICS_Speech_inaudible'), false
    end
    if player:hasTrait(CharacterTrait.HARD_OF_HEARING) then
        local chance = HEARING_LOSS[channel]
        local range = TicsServerSettings and TicsServerSettings[channel] and TicsServerSettings[channel]['range']
        if distance and range and range > 0 then
            chance = chance + DISTANCE_LOSS * math.min(1, distance / range)
        end
        return LoseWords(text, chance), true
    end
    return text, true
end

return SpeechEffects
