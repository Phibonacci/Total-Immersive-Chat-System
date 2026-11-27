local LanguageManager = require('tics/client/languages/LanguageManager')


local AVoice = {}

local Phonemes = {
    A = {
        'AIR',
        'AI',
        'AR',
        'A'
    },
    B = {
        'B'
    },
    C = {
        'CH',
        'C'
    },
    D = {
        'D'
    },
    E = {
        'ERE',
        'EE',
        'ER',
        'E'
    },
    F = {
        'F'
    },
    G = {
        'G'
    },
    H = {
        'H'
    },
    I = {
        'IS',
        'IR',
        'I'
    },
    J = {
        'J'
    },
    K = {
        'K'
    },
    L = {
        'L'
    },
    M = {
        'M'
    },
    N = {
        'NG',
        'N'
    },
    O = {
        'OOR',
        'OO',
        'OW',
        'OY',
        'O'
    },
    P = {
        'P'
    },
    Q = {
        'Q'
    },
    R = {
        'R'
    },
    S = {
        'SH',
        'S'
    },
    T = {
        'TH',
        'T'
    },
    U = {
        'UP',
        'U'
    },
    V = {
        'V'
    },
    W = {
        'W'
    },
    X = {
        'X '
    },
    Y = {
        'Y'
    },
    Z = {
        'Z'
    },
}

local Alphabet = { 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
    'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z' }

local function GetPhoneme(nextLetters)
    local firstLetter = nextLetters:sub(1, 1)
    for _, c in pairs(LanguageManager.UnknownCharacters) do
        if c == firstLetter then
            local letterId = ZombRand(26 - 1) + 1
            local randomLetter = Alphabet[letterId]
            return Phonemes[randomLetter][1]
        end
    end
    local letterPhonemes = Phonemes[firstLetter]
    if letterPhonemes == nil then
        return nil
    end
    for _, phoneme in pairs(letterPhonemes) do
        if #nextLetters >= #phoneme and nextLetters:match('^' .. phoneme) then
            return phoneme
        end
    end
    return nil
end

function AVoice:GetSoundPathFromPhoneme(phoneme, isFirstWordLetter, soundPrefix)
    local filePhoneme
    if phoneme == 'K' or phoneme == 'Q' then
        filePhoneme = 'C'
    elseif phoneme == 'Y' and isFirstWordLetter then
        filePhoneme = 'YStart'
    else
        filePhoneme = phoneme
    end

    return soundPrefix .. filePhoneme
end

function AVoice:subscribe()
    if self.event then
        return
    end
    self.event = function()
        self:update()
    end
    Events.OnTick.Add(self.event)
end

function AVoice:unsubscribe()
    if self.event == nil then
        return
    end
    Events.OnTick.Remove(self.event)
    self.event = nil
end

-- Rhythm and melody of the voice. The phoneme clips (100 ms) overlap and crossfade (their
-- fades are in the files): consonants are short and soft, vowels carry the voice.
local VOWEL_STEP_MS = 70
local CONSONANT_STEP_MS = 40
local PAUSE_MS = { space = 30, comma = 200, sentence = 320 }
local CONSONANT_VOLUME = 0.45
local PLOSIVE_VOLUME = 0.7 -- times the consonant volume: t, b, p, d... are the harshest
local PLOSIVES = { T = true, TH = true, B = true, P = true, D = true, G = true, C = true, K = true, Q = true,
    CH = true, J = true }
local MAX_DURATION_MS = 4000 -- a long message is spoken faster rather than babbling for ages
local MAX_VOLUME = 1.2 -- a yelled exclamation in capitals would distort above
-- emphasis: words between * (or _), and words in capitals
local EMPHASIS_PITCH, EMPHASIS_VOLUME = 0.04, 1.15
local CAPITALS_PITCH, CAPITALS_VOLUME = 0.03, 1.2
-- the channel: volume, pitch offset, tempo (durations multiplied: above 1 is slower)
local CHANNELS = {
    whisper = { volume = 0.35, pitch = 0.03, tempo = 0.9 },
    low = { volume = 0.6, pitch = 0, tempo = 1 },
    say = { volume = 1, pitch = 0, tempo = 1 },
    yell = { volume = 1.15, pitch = 0.07, tempo = 1.15 },
}

local function IsVowelPhoneme(phoneme)
    return phoneme:sub(1, 1):match('[AEIOUY]') ~= nil
end

function AVoice:update()
    local elapsed = Calendar.getInstance():getTimeInMillis() - self.startingTime
    while self.nextSoundTableIndex <= self.soundTableSize do
        local nextSound = self.soundTable[self.nextSoundTableIndex]
        if elapsed < nextSound.time then
            return
        end
        self.nextSoundTableIndex = self.nextSoundTableIndex + 1
        if nextSound.sound ~= nil then
            local emitter = getWorld():getFreeEmitter()
            -- Is object already a square or a player? We don't care, they both have getX/Y/Z, we get the square anyway.
            local square = getSquare(self.object:getX(), self.object:getY(), self.object:getZ())
            if square ~= nil then -- false when player just went online and the world is not initialized properly yet or the player is too far
                local soundId = emitter:playSoundImpl(nextSound.sound, square)
                if soundId == nil then
                    return -- player just went online and the world is not initialized properly yet
                end
                -- If it's a character and the one played by the client then we don't want to hear the sound from only one side
                if self.object.getUsername ~= nil and self.object:getUsername() == getPlayer():getUsername() then
                    emitter:set3D(soundId, false)
                end
                -- setPitch with the sound id logs "Set pitch for ToStart" (FMODSoundEmitter) for each sound;
                -- it sets the pitch of every sound of the emitter anyway, and this emitter (a free one) only
                -- plays this sound, so an id matching no sound sets the same pitch without the log
                emitter:setPitch(0, self.pitch + nextSound.pitch)
                emitter:setVolume(soundId, nextSound.volume)
            end
        end
    end
end

local function isPunctuationMark(letter)
    return letter == ','
        or letter == '.'
        or letter == '!'
        or letter == '?'
        or letter == ':'
        or letter == ';'
end

-- true for each character of `text` that is between markdown marks (* or _) in `original`
-- (the text is the original without its marks, as shown in the bubble)
local function EmphasisMask(text, original)
    local mask = {}
    if original == nil then
        return mask
    end
    local emphasized = false
    local j = 1
    local i = 1
    while i <= #original and j <= #text do
        local c = original:sub(i, i)
        if c == text:sub(j, j) then
            mask[j] = emphasized
            j = j + 1
            i = i + 1
        elseif c == '*' or c == '_' then
            -- a run of marks ('*' or '**') opens or closes the emphasis
            while original:sub(i, i) == c do
                i = i + 1
            end
            emphasized = not emphasized
        else
            i = i + 1
        end
    end
    return mask
end

-- true for each character of a word written in capitals (two letters or more)
local function CapitalsMask(text)
    local mask = {}
    local index = 1
    for word in text:gmatch('%S+') do
        local start = text:find(word, index, true)
        local letters = word:gsub('%A', '')
        local capitals = #letters >= 2 and letters == letters:upper() and letters ~= letters:lower()
        for k = start, start + #word - 1 do
            mask[k] = capitals
        end
        index = start + #word
    end
    return mask
end

-- the sounds and pauses of the message, in order
function AVoice:tokenize(soundPrefix)
    local tokens = {}
    local isFirstWordLetter = true
    local index = 1
    local message = self.message
    local messageSize = #message
    while index <= messageSize do
        local firstLetter = message:sub(index, index)
        if firstLetter == ' ' then
            index = index + 1
            isFirstWordLetter = true
            table.insert(tokens, { pause = 'space' })
        elseif isPunctuationMark(firstLetter) then
            index = index + 1
            isFirstWordLetter = true
            local kind = (firstLetter == '.' or firstLetter == '!' or firstLetter == '?') and 'sentence' or 'comma'
            table.insert(tokens, { pause = kind, mark = firstLetter })
        else
            local nextLetters = message:sub(index)
            local phoneme = GetPhoneme(nextLetters)
            if phoneme == nil then
                index = index + 1
                isFirstWordLetter = true
            else
                local startIndex = index
                local soundFile = self:GetSoundPathFromPhoneme(phoneme, isFirstWordLetter, soundPrefix)
                isFirstWordLetter = false
                if #phoneme == 1 or phoneme == 'OO' then
                    local identicalLetters = nextLetters:match('^(' .. phoneme:sub(1, 1) .. '+)')
                    if identicalLetters ~= nil then
                        index = index + #identicalLetters
                    else
                        index = index + #phoneme
                    end
                else
                    index = index + #phoneme
                end
                table.insert(tokens, {
                    sound = soundFile,
                    phoneme = phoneme,
                    startIndex = startIndex,
                    characterIndex = index - 1,
                })
            end
        end
    end
    return tokens
end

function AVoice:createSoundTable(soundPrefix, channel, original)
    local profile = CHANNELS[channel] or CHANNELS.say
    -- every character has its own pace, from their voice pitch (always the same for them)
    local pace = 1 + ((math.floor((self.pitch or 1) * 1000 + 0.5) % 21) - 10) / 100
    local tempo = profile.tempo * pace
    local emphasis = EmphasisMask(self.originalCase, original)
    local capitals = CapitalsMask(self.originalCase)
    local tokens = self:tokenize(soundPrefix)

    -- sentences, for their melody: a statement falls, a question rises at the end
    local soundTable = {}
    local time = 0
    local sentenceStart = 1
    while sentenceStart <= #tokens do
        local sentenceEnd = #tokens
        for k = sentenceStart, #tokens do
            if tokens[k].pause == 'sentence' then
                sentenceEnd = k
                break
            end
        end
        local mark = tokens[sentenceEnd].mark or '.'
        local sounds = 0
        for k = sentenceStart, sentenceEnd do
            if tokens[k].sound then
                sounds = sounds + 1
            end
        end
        local soundIndex = 0
        for k = sentenceStart, sentenceEnd do
            local token = tokens[k]
            if token.pause then
                time = time + PAUSE_MS[token.pause] * tempo
            else
                local progress = sounds > 1 and soundIndex / (sounds - 1) or 0
                soundIndex = soundIndex + 1
                local pitch = profile.pitch + 0.03 - 0.06 * progress
                if mark == '?' and progress > 0.6 then
                    pitch = profile.pitch - 0.01 + 0.2 * (progress - 0.6)
                end
                local volume = profile.volume
                if mark == '!' then
                    pitch = pitch + 0.04
                    volume = volume * 1.12
                end
                local isVowel = IsVowelPhoneme(token.phoneme)
                if not isVowel then
                    volume = volume * CONSONANT_VOLUME * (PLOSIVES[token.phoneme] and PLOSIVE_VOLUME or 1)
                end
                if emphasis[token.startIndex] then
                    pitch = pitch + EMPHASIS_PITCH
                    volume = volume * EMPHASIS_VOLUME
                end
                if capitals[token.startIndex] then
                    pitch = pitch + CAPITALS_PITCH
                    volume = volume * CAPITALS_VOLUME
                end
                table.insert(soundTable, {
                    time = time,
                    sound = token.sound,
                    characterIndex = token.characterIndex,
                    pitch = pitch,
                    volume = math.min(volume, MAX_VOLUME),
                })
                time = time + (isVowel and VOWEL_STEP_MS or CONSONANT_STEP_MS) * tempo
            end
        end
        sentenceStart = sentenceEnd + 1
    end

    local size = #soundTable
    local length = size > 0 and soundTable[size].time or 0
    if length > MAX_DURATION_MS then
        local factor = MAX_DURATION_MS / length
        for _, sound in ipairs(soundTable) do
            sound.time = sound.time * factor
        end
    end
    return soundTable, size
end

function AVoice:currentMessageIndex()
    if self.soundTableSize < 1 or self.soundTableSize <= self.nextSoundTableIndex then
        return #self.message
    end
    return self.soundTable[self.nextSoundTableIndex].characterIndex
end

-- message: the text shown in the bubble; channel: 'whisper', 'low', 'say' or 'yell' (nil: say);
-- original: the message with its markdown marks, for the emphasis (nil: none)
function AVoice:new(message, object, soundPrefix, voicePitch, channel, original)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.originalCase = message
    o.message = message:upper()
    o.object = object
    o.pitch = voicePitch or 1
    o.soundTable, o.soundTableSize = o:createSoundTable(soundPrefix, channel, original)
    o.nextSoundTableIndex = 1
    o.startingTime = Calendar.getInstance():getTimeInMillis()
    return o
end

return AVoice
