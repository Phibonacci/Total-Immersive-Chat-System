-- Volume of the sounds of TICS (the voices, the typing). They are plain sound files, which the
-- game plays outside of its sound banks: its "Sound Volume" option does not reach them, so it
-- is applied here. The voices also have their own slider in Options > Mods.

require 'PZAPI/ModOptions'

local VoiceVolume = {}

local options = PZAPI.ModOptions:create('TICS', 'Total Immersive Chat System')
local voiceSlider = options:addSlider('voiceVolume', getText('UI_TICS_Options_voiceVolume'), 0, 100, 5, 100,
    getText('UI_TICS_Options_voiceVolume_tooltip', getText('UI_optionscreen_sound_volume')))

-- the game reads the saved values of the mod options only when its Options screen opens
PZAPI.ModOptions:load()

-- the game's "Sound Volume", 0 to 1
function VoiceVolume.sound()
    return getCore():getOptionSoundVolume() / 10
end

-- the voices: the game's sound volume and the slider of TICS, 0 to 1
function VoiceVolume.voice()
    local value = tonumber(voiceSlider:getValue()) or 100
    return VoiceVolume.sound() * math.max(0, math.min(value, 100)) / 100
end

return VoiceVolume
