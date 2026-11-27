local AVoice = require('tics/client/voice/AVoice')

local PlayerVoice = {}

-- channel and original (the message with its markdown marks): see AVoice:new
function PlayerVoice:new(message, object, voicePitch, channel, original)
    PlayerVoice.__index = self
    setmetatable(PlayerVoice, { __index = AVoice })
    local o = AVoice:new(message, object, 'Voice1Player', voicePitch, channel, original)
    setmetatable(o, PlayerVoice)
    return o
end

return PlayerVoice
