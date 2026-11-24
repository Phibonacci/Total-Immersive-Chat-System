local StringBuilder = {}

function StringBuilder.BuildAsteriskColorString(color)
    return '*' .. color[1] .. ',' .. color[2] .. ',' .. color[3] .. '*'
end

function StringBuilder.BuildBracketColorString(color)
    return '<RGB:'
        .. string.format('%.3f', color[1] / 255) .. ','
        .. string.format('%.3f', color[2] / 255) .. ','
        .. string.format('%.3f', color[3] / 255) .. '>'
end

-- milliseconds to add to a timestamp (UTC) to get the player's local time, daylight saving included
local function LocalOffsetMs()
    local calendar = Calendar.getInstance()
    return calendar:get(Calendar.ZONE_OFFSET) + calendar:get(Calendar.DST_OFFSET)
end

-- local hours, minutes and seconds of a timestamp in milliseconds
local function LocalTime(time)
    local seconds = math.floor((time + LocalOffsetMs()) / 1000)
    return math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60, seconds % 60
end

function StringBuilder.GetCurrentFormatedTime(time)
    local h, m, s = LocalTime(time)
    return string.format('%02d:%02d:%02d', h, m, s)
end

-- chat line prefix: hours and minutes in a dark grey, the message stays the focus
function StringBuilder.BuildTimePrefixString(time)
    local h, m = LocalTime(time)
    return StringBuilder.BuildBracketColorString({ 100, 100, 100 }) .. string.format('%02d:%02d', h, m) .. ' '
end

function StringBuilder.BuildFontSizeString(size)
    return '<SIZE:' .. size .. '>'
end

function StringBuilder.BuildNewLine()
    return '<LINE>'
end

return StringBuilder
