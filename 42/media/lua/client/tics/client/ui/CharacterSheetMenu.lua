-- Right click on another player: "Examine <name>" opens their character sheet. Only for
-- players close enough to be seen (same range as /say, checked again by the server).

local Character = require('tics/shared/utils/Character')
local CharacterSheetManager = require('tics/client/CharacterSheetManager')
local CharacterSheetWindow = require('tics/client/ui/CharacterSheetWindow')
local ClientSend = require('tics/client/network/ClientSend')
local Introductions = require('tics/client/Introductions')

local function GetSayRange()
    return TicsServerSettings and TicsServerSettings['say'] and TicsServerSettings['say']['range'] or 15
end

-- other players on the clicked squares and around them
local function FindPlayers(me, worldobjects)
    local found = {}
    local list = {}
    for _, object in ipairs(worldobjects) do
        local square = object.getSquare and object:getSquare()
        if square then
            for dx = -1, 1 do
                for dy = -1, 1 do
                    local near = getCell():getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
                    local objects = near and near:getMovingObjects()
                    if objects then
                        for i = 0, objects:size() - 1 do
                            local moving = objects:get(i)
                            if instanceof(moving, 'IsoPlayer') and moving ~= me
                                and not found[moving:getUsername()]
                            then
                                found[moving:getUsername()] = true
                                table.insert(list, moving)
                            end
                        end
                    end
                end
            end
        end
    end
    return list
end

local function OnFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    local sheets = CharacterSheetManager.isEnabled()
    local introductions = Introductions.isEnabled()
    if test or not (sheets or introductions) then
        return
    end
    local me = getSpecificPlayer(playerNum)
    if me == nil then
        return
    end
    local range = GetSayRange()
    for _, other in ipairs(FindPlayers(me, worldobjects)) do
        local dx = other:getX() - me:getX()
        local dy = other:getY() - me:getY()
        if math.sqrt(dx * dx + dy * dy) <= range then
            local username = other:getUsername()
            local firstName, lastName = Character.getFirstAndLastName(other)
            local characterName = firstName .. ' ' .. lastName
            local name = username
            if introductions then
                -- the name the player's character knows them by, or how they look
                name = Introductions.displayName(username, characterName, { lowercase = true })
            elseif TicsServerSettings and TicsServerSettings['options']['showCharacterName'] then
                name = characterName
            end
            if sheets then
                context:addOption(getText('UI_TICS_Sheet_examine', name), nil, function()
                    CharacterSheetWindow.open(username)
                end)
            end
            if introductions then
                context:addOption(getText('UI_TICS_Intro_context', name), nil, function()
                    ClientSend.sendIntroduce(nil, username)
                end)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)
