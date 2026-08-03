local AVoice = require('tics/client/voice/AVoice')

local KeyboardSound = {}

local function GetRandomInt(min, max)
    return ZombRand(max - min) + min
end

local function GetRandomKeyboardSound()
    local soundId = GetRandomInt(1, 32)
    local formattedId = string.format("%03d", soundId)
    return 'Keypress' .. formattedId
end

local TYPING_DELAY = 120

function KeyboardSound:currentMessageIndex()
    return self.nextSoundIndex - 1
end

local MIN_PITCH_VARIATION = -0.15
local MAX_PITCH_VARIATION = 0.15
local MIN_TYPPING_DELAY = 60
local MAX_TYPPING_DELAY = 120
function KeyboardSound:update()
    if self.nextSoundIndex > self.size then
        return
    end
    local soundCanBePlayed = true
    local soundPlayed = false
    while soundCanBePlayed and self.nextSoundIndex <= self.size do
        local currentTime = Calendar.getInstance():getTimeInMillis()
        if self.lastSoundStartingTime ~= nil and currentTime - self.lastSoundStartingTime < self.typingDelay then
            soundCanBePlayed = false
        else
            if soundPlayed == false then
                self.soundEmitter = getWorld():getFreeEmitter()

                -- Is object already a square or a player? We don't care, they both have getX/Y/Z, we get the square anyway.
                local square = getSquare(self.object:getX(), self.object:getY(), self.object:getZ())
                if square ~= nil then              -- false when player just went online and the world is not initialized properly yet or the player is too far
                    local sound = 'TypewritterKey' -- GetRandomKeyboardSound()
                    self.typingDelay = ZombRandFloat(MIN_TYPPING_DELAY, MAX_TYPPING_DELAY)
                    self.soundId = self.soundEmitter:playSoundImpl(sound, square)
                    self.lastSoundStartingTime = currentTime
                    if self.soundId == nil then
                        return -- player just went online and the world is not initialized properly yet
                    end

                    -- If it's a character and the one played by the client then we don't want to hear the sound from only one side
                    if self.object.getUsername ~= nil and self.object:getUsername() == getPlayer():getUsername() then
                        self.soundEmitter:set3D(self.soundId, false)
                    end
                    local pitchVariation = ZombRandFloat(MIN_PITCH_VARIATION, MAX_PITCH_VARIATION)
                    self.soundEmitter:setPitch(self.soundId, self.pitch + pitchVariation)
                    soundPlayed = true
                end
            end
            self.nextSoundIndex = self.nextSoundIndex + 2
            if self.nextSoundIndex > self.size + 1 then
                self.nextSoundIndex = self.size + 1
            end
        end
    end
end

function KeyboardSound:subscribe()
    if self.event then
        return
    end
    self.event = function()
        self:update()
    end
    Events.OnTick.Add(self.event)
end

function KeyboardSound:unsubscribe()
    if self.event == nil then
        return
    end
    Events.OnTick.Remove(self.event)
    self.event = nil
end

function KeyboardSound:new(message, object, voicePitch)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.message = message
    o.object = object
    o.pitch = voicePitch
    o.lastSoundStartingTime = nil
    o.size = #message
    o.nextSoundIndex = 1
    o.typingDelay = 0
    return o
end

return KeyboardSound
