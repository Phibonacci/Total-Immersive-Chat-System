-- Appearance of a character as seen by the player: body, skin, hair, beard and the clothes
-- worn with their colors and textures. Captured from a loaded player, rebuilt later as a
-- SurvivorDesc for a 3D model (like the character creation screen), so the journal can show
-- someone who is not around anymore as the player last saw them.

local Appearance = {}

local function ColorOf(color)
    if color == nil then
        return nil
    end
    return { color:getRedFloat(), color:getGreenFloat(), color:getBlueFloat() }
end

local function VisualEntry(fullType, itemVisual)
    local entry = { type = fullType, textureChoice = -1, baseTexture = -1, decal = '' }
    if itemVisual then
        entry.tint = ColorOf(itemVisual:getTint())
        entry.textureChoice = itemVisual:getTextureChoice()
        entry.baseTexture = itemVisual:getBaseTexture()
        local clothingItem = itemVisual:getClothingItem()
        entry.decal = clothingItem and itemVisual:getDecal(clothingItem) or ''
    end
    return entry
end

-- { female, skinIndex, bodyHair, hairModel, hairColor, beardModel, beardColor,
--   items = { { type, tint, textureChoice, baseTexture, decal, custom } } }
function Appearance.capture(player)
    local visual = player:getHumanVisual()
    local data = {
        female = player:isFemale(),
        skinIndex = visual:getSkinTextureIndex(),
        bodyHair = visual:getBodyHairIndex(),
        hairModel = visual:getHairModel() or '',
        hairColor = ColorOf(visual:getHairColor()),
        beardModel = visual:getBeardModel() or '',
        beardColor = ColorOf(visual:getBeardColor()),
        items = {},
    }
    if player:isLocalPlayer() then
        local worn = player:getWornItems()
        for index = 0, worn:size() - 1 do
            local item = worn:get(index):getItem()
            if item then
                local entry = VisualEntry(item:getFullType(), item:getVisual())
                if item:isCustomColor() then
                    entry.custom = { item:getR(), item:getG(), item:getB() }
                end
                table.insert(data.items, entry)
            end
        end
    else
        -- other players: the client only receives the visuals of their clothes, not the items
        local visuals = player:getItemVisuals()
        for index = 0, visuals:size() - 1 do
            local itemVisual = visuals:get(index)
            local fullType = itemVisual:getItemType()
            if fullType then
                table.insert(data.items, VisualEntry(fullType, itemVisual))
            end
        end
    end
    return data
end

local function SetColor(color, setter)
    if color then
        setter(ImmutableColor.new(color[1], color[2], color[3], 1))
    end
end

-- SurvivorDesc for ISUI3DModel:setSurvivorDesc, nil when the data is unusable
function Appearance.buildDesc(data)
    local desc = SurvivorFactory.CreateSurvivor(SurvivorType.Neutral, data.female)
    desc:setFemale(data.female)
    local visual = desc:getHumanVisual()
    visual:clear()
    visual:setSkinTextureIndex(data.skinIndex)
    visual:setBodyHairIndex(data.bodyHair)
    if data.hairModel ~= '' then
        visual:setHairModel(data.hairModel)
    end
    SetColor(data.hairColor, function(color)
        visual:setHairColor(color)
        visual:setNaturalHairColor(color)
    end)
    if data.beardModel ~= '' then
        visual:setBeardModel(data.beardModel)
    end
    SetColor(data.beardColor, function(color)
        visual:setBeardColor(color)
        visual:setNaturalBeardColor(color)
    end)
    desc:getWornItems():clear()
    for _, entry in ipairs(data.items) do
        local item = instanceItem(entry.type)
        if item then
            local itemVisual = item:getVisual()
            if itemVisual then
                SetColor(entry.tint, function(color) itemVisual:setTint(color) end)
                if entry.textureChoice >= 0 then
                    itemVisual:setTextureChoice(entry.textureChoice)
                end
                if entry.baseTexture >= 0 then
                    itemVisual:setBaseTexture(entry.baseTexture)
                end
                if entry.decal ~= '' then
                    itemVisual:setDecal(entry.decal)
                end
            end
            if entry.custom then
                item:setCustomColor(true)
                item:setColor(Color.new(entry.custom[1], entry.custom[2], entry.custom[3], 1))
            end
            local location = item:IsClothing() and item:getBodyLocation() or item:canBeEquipped()
            if location then
                desc:setWornItem(location, item)
            end
        end
    end
    return desc
end

---------------------------------------------------------------------------- text form

local function ColorFields(color)
    if color == nil then
        return '', '', ''
    end
    return string.format('%.3f', color[1]), string.format('%.3f', color[2]), string.format('%.3f', color[3])
end

local function ParseColor(r, g, b)
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if r == nil or g == nil or b == nil then
        return nil
    end
    return { r, g, b }
end

-- lists of fields, one list per line of the appearance file
function Appearance.toFields(data)
    local hr, hg, hb = ColorFields(data.hairColor)
    local br, bg, bb = ColorFields(data.beardColor)
    local lines = {
        { 'P', data.female and 1 or 0, data.skinIndex, data.bodyHair, data.hairModel, hr, hg, hb, data.beardModel, br, bg, bb },
    }
    for _, entry in ipairs(data.items) do
        local tr, tg, tb = ColorFields(entry.tint)
        local cr, cg, cb = ColorFields(entry.custom)
        table.insert(lines, { 'I', entry.type, tr, tg, tb, entry.textureChoice, entry.baseTexture, entry.decal or '', cr, cg, cb })
    end
    return lines
end

function Appearance.fromFields(lines)
    local data = nil
    local items = {}
    for _, fields in ipairs(lines) do
        if fields[1] == 'P' and #fields >= 12 then
            data = {
                female = fields[2] == '1',
                skinIndex = tonumber(fields[3]) or 0,
                bodyHair = tonumber(fields[4]) or -1,
                hairModel = fields[5],
                hairColor = ParseColor(fields[6], fields[7], fields[8]),
                beardModel = fields[9],
                beardColor = ParseColor(fields[10], fields[11], fields[12]),
            }
        elseif fields[1] == 'I' and #fields >= 11 then
            table.insert(items, {
                type = fields[2],
                tint = ParseColor(fields[3], fields[4], fields[5]),
                textureChoice = tonumber(fields[6]) or -1,
                baseTexture = tonumber(fields[7]) or -1,
                decal = fields[8],
                custom = ParseColor(fields[9], fields[10], fields[11]),
            })
        end
    end
    if data then
        data.items = items
    end
    return data
end

return Appearance
