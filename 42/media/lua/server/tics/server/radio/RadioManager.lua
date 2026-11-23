---@diagnostic disable: trailing-space
local Character = require('tics/shared/utils/Character')
local FakeRadio = require('tics/server/radio/FakeRadio')
local World = require('tics/shared/utils/World')

local RadioManager = {}

-- Radios on squares and in vehicles that were seen near players, so a radio message makes
-- noise (zombies) at every radio tuned to its frequency. Only positions are kept: the game
-- recycles square objects when an area unloads, a kept object could point anywhere. A radio is
-- looked up from its position when needed: skipped (but kept) while its area is not loaded,
-- forgotten once its area is loaded and it is not there anymore.
-- squares: "x,y,z" -> { x, y, z }, vehicles: key id -> { x, y, z } (last known position)

local function SquareKey(x, y, z)
    return math.abs(x) .. ',' .. math.abs(y) .. ',' .. math.abs(z)
end

function RadioManager:save()
    local cacheSquares = {}
    for _, pos in pairs(self.squares) do
        table.insert(cacheSquares, { x = pos.x, y = pos.y, z = pos.z })
    end
    local cacheVehicles = {}
    for key, pos in pairs(self.vehicles) do
        cacheVehicles[key] = { x = pos.x, y = pos.y, z = pos.z }
    end
    ModData.add('ticsRadioCache', { squares = cacheSquares, vehicles = cacheVehicles })
end

function RadioManager:load()
    local cache = ModData.getOrCreate('ticsRadioCache')
    self.squares = {}
    self.vehicles = {}
    local squaresCount, vehiclesCount = 0, 0
    for _, pos in pairs(cache['squares'] or {}) do
        if type(pos) == 'table' and pos['x'] and pos['y'] and pos['z'] then
            self.squares[SquareKey(pos['x'], pos['y'], pos['z'])] = { x = pos['x'], y = pos['y'], z = pos['z'] }
            squaresCount = squaresCount + 1
        end
    end
    for key, pos in pairs(cache['vehicles'] or {}) do
        if type(pos) == 'table' and pos['x'] and pos['y'] and pos['z'] then
            self.vehicles[key] = { x = pos['x'], y = pos['y'], z = pos['z'] }
            vehiclesCount = vehiclesCount + 1
        end
    end
    print('TICS info: radio cache loaded: ' .. squaresCount .. ' squares, ' .. vehiclesCount .. ' vehicles')
    self.loaded = true
end

function RadioManager:subscribeSquare(square)
    if square == nil then
        return
    end
    if not self.loaded then
        self:load()
    end
    local key = SquareKey(square:getX(), square:getY(), square:getZ())
    if self.squares[key] == nil then
        self.squares[key] = { x = square:getX(), y = square:getY(), z = square:getZ() }
        self:save()
    end
end

function RadioManager:subscribeVehicle(vehicle)
    if not self.loaded then
        self:load()
    end
    local key = vehicle:getKeyId()
    local pos = { x = math.floor(vehicle:getX()), y = math.floor(vehicle:getY()), z = math.floor(vehicle:getZ()) }
    local known = self.vehicles[key]
    if known == nil or known.x ~= pos.x or known.y ~= pos.y or known.z ~= pos.z then
        self.vehicles[key] = pos
        self:save()
    end
end

-- returns true if an entry was forgotten
function RadioManager:executeSquare(action)
    local forgotten = {}
    for key, pos in pairs(self.squares) do
        local square = getSquare(pos.x, pos.y, pos.z)
        if square ~= nil then -- nil: area not loaded, kept for later
            local radio = World.getFirstSquareItem(square, 'IsoRadio')
            if radio == nil then
                table.insert(forgotten, key)
            else
                action(radio, radio)
            end
        end
    end
    for _, key in ipairs(forgotten) do
        self.squares[key] = nil
    end
    return #forgotten > 0
end

-- returns true if an entry was forgotten
function RadioManager:executeVehicle(action)
    local forgotten = {}
    for key, pos in pairs(self.vehicles) do
        local square = getSquare(pos.x, pos.y, pos.z)
        if square ~= nil then -- nil: area not loaded, kept for later
            local vehicle = square:getVehicleContainer()
            local radio = vehicle and vehicle:getKeyId() == key and vehicle:getPartById('Radio') or nil
            if radio == nil then
                -- the vehicle moved or lost its radio, it is cached again when used near a player
                table.insert(forgotten, key)
            else
                action(vehicle, radio)
            end
        end
    end
    for _, key in ipairs(forgotten) do
        self.vehicles[key] = nil
    end
    return #forgotten > 0
end

function RadioManager:execute(action)
    if not self.loaded then
        self:load()
    end
    local squareForgotten = self:executeSquare(action)
    local vehicleForgotten = self:executeVehicle(action)
    if squareForgotten or vehicleForgotten then
        self:save()
    end
end

function RadioManager:makeNoise(frequency, range)
    if not self.loaded then
        self:load()
    end
    self:execute(
        function(source, radio)
            local radioData = radio:getDeviceData()
            if radioData ~= nil then
                local radioFrequency = radioData:getChannel()

                -- -1 nothing
                --  0 headphones
                --  1 earbuds
                local hasHeadphones = radioData:getHeadphoneType() >= 0
                if radioData:getIsTurnedOn()
                    and radioFrequency == frequency
                    and not hasHeadphones
                then
                    local radioRange = Character.getRadioRange(radioData, range)
                    addSound(source, source:getX(), source:getY(), source:getZ(), radioRange, radioRange)
                end
            end
        end
    )
    World.forAllPlayers(
        function(player)
            local radio = Character.getFirstHandOrBeltItemByGroup(player, 'Radio')
            if radio ~= nil then
                local radioData = radio:getDeviceData()
                if radioData ~= nil then
                    local radioFrequency = radioData:getChannel()
                    local turnedOn = radioData:getIsTurnedOn()
                    -- TODO
                    -- local volume = radioData:getDeviceVolume()

                    -- -1 nothing
                    --  0 headphones
                    --  1 earbuds
                    local hasHeadphones = radioData:getHeadphoneType() >= 0
                    if turnedOn and radioFrequency == frequency and not hasHeadphones then
                        local radioRange = Character.getRadioRange(radioData, range)
                        addSound(player, player:getX(), player:getY(), player:getZ(), radioRange, radioRange)
                    end
                end
            end
        end
    )
end

function RadioManager:getOrCreateFakeBeltRadio(player)
    local username = player:getUsername()
    if self.beltRadioByPlayer[username] == nil then
        self.beltRadioByPlayer[username] = FakeRadio:new()
    end
    return self.beltRadioByPlayer[username]
end

function RadioManager:getFakeBeltRadio(player)
    local username = player:getUsername()
    return self.beltRadioByPlayer[username]
end

local function CreateRadioManager()
    local o = {}
    setmetatable(o, RadioManager)
    RadioManager.__index = RadioManager
    o.squares = {}
    o.vehicles = {}
    o.loaded = false
    o.beltRadioByPlayer = {}
    return o
end

local instance = CreateRadioManager()

-- Since a lua file is only read once, this file will always return the same
-- value. Making this a singleton that cannot be missused.
return instance
