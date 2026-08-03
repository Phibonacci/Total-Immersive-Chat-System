local DateTime     = {}

local YEAR         = 1
local MONTH        = 2
local DAY_OF_MONTH = 5
local HOUR_OF_DAY  = 11
local MINUTE       = 12
local SECOND       = 13
function DateTime.GetISODate()
    local calendar = Calendar.getInstance()
    local year     = calendar:get(YEAR)
    local month    = calendar:get(MONTH) + 1
    local day      = calendar:get(DAY_OF_MONTH)

    return
        string.format('%02d', year) .. '-' ..
        string.format('%02d', month) .. '-' ..
        string.format('%02d', day)
end

function DateTime.GetISOTime()
    local calendar = Calendar.getInstance()
    local hour     = calendar:get(HOUR_OF_DAY)
    local minute   = calendar:get(MINUTE)
    local second   = calendar:get(SECOND)

    return
        string.format('%02d', hour) .. ':' ..
        string.format('%02d', minute) .. ':' ..
        string.format('%02d', second)
end

return DateTime
