-- Names above the characters, drawn by TICS (sandbox option, off by default) so they follow
-- the introductions: the name a character gave, or the description of a stranger. The game's
-- own name above the characters cannot be changed by a mod: the admin turns it off with the
-- server settings DisplayUserName and ShowFirstAndLastName.
-- Drawn from ISChat:prerender like the bubbles and typing dots.

local ChatTheme = require('tics/client/ui/ChatTheme')
local Coordinates = require('tics/client/utils/Coordinates')
local Character = require('tics/shared/utils/Character')
local Introductions = require('tics/client/Introductions')

local NameTag = ISUIElement:derive('TicsNameTag')

local FONT = UIFont.Small
local RANGE = 25          -- squares around the player where names are shown
local PADDING_X = 4
local BACKGROUND_ALPHA = 0.45
local LABEL_REFRESH_MS = 500 -- names and faction tags are looked up again twice a second
local HOVER_FADE_MS = 600    -- 'hover' mode: the name fades out as soon as the mouse leaves
local HOVER_HALF_WIDTH = 22  -- 'hover' mode: half the width of a character on screen, at zoom 1
-- staff colors (sandbox option)
local ADMIN_COLOR = { r = 0.92, g = 0.36, b = 0.32 }
local MODERATOR_COLOR = { r = 0.42, g = 0.62, b = 0.96 }

local NameTags = {}

local tags = {} -- username -> NameTag
local hoveredAt = {} -- username -> last time the mouse was over them ('hover' mode)

function NameTags.isEnabled()
    return TicsServerSettings ~= nil and TicsServerSettings['options'] ~= nil
        and TicsServerSettings['options']['nameTags'] == true
end

function NameTag:setLabel(name, nameColor, tag, tagColor)
    self.nameColor = nameColor
    if name == self.name and tag == self.tag then
        return
    end
    self.name, self.tag, self.tagColor = name, tag, tagColor
    local textManager = getTextManager()
    self.tagWidth = tag and (textManager:MeasureStringX(FONT, '[' .. tag .. '] ')) or 0
    self:setWidth(self.tagWidth + textManager:MeasureStringX(FONT, name) + PADDING_X * 2)
    self:setHeight(textManager:getFontHeight(FONT) + 2)
end

function NameTag:render()
    local x, y = Coordinates.CenterTopOfPlayer(self.player, self.width, self.height)
    if x == nil then
        return
    end
    -- just above the head, under the typing dots and the bubbles
    self:setX(x)
    self:setY(y + 4)
    self:drawRect(0, 0, self.width, self.height, BACKGROUND_ALPHA * self.alpha, 0, 0, 0)
    local textX = PADDING_X
    if self.tag then
        local color = self.tagColor or ChatTheme.textMuted
        self:drawText('[' .. self.tag .. ']', textX, 1, color.r, color.g, color.b, self.alpha, FONT)
        textX = textX + self.tagWidth
    end
    local text = self.nameColor or ChatTheme.textActive
    self:drawText(self.name, textX, 1, text.r, text.g, text.b, self.alpha, FONT)
end

function NameTag:new(player)
    local o = ISUIElement.new(self, 0, 0, 10, 10)
    o.player = player
    o.alpha = 1
    o:instantiate()
    return o
end

-- the name as the player's character knows it
local function Label(player)
    local username = player:getUsername()
    local firstName, lastName = Character.getFirstAndLastName(player)
    local characterName = firstName .. ' ' .. lastName
    if Introductions.isEnabled() then
        return Introductions.displayName(username, characterName) or characterName
    end
    if TicsServerSettings['options']['showCharacterName'] then
        return characterName
    end
    return username
end

-- admins in red, moderators in blue (sandbox option), nil for the default color
local function StaffColor(player)
    if not TicsServerSettings['options']['nameTagsStaffColors'] then
        return nil
    end
    if player:isAccessLevel('admin') then
        return ADMIN_COLOR
    elseif player:isAccessLevel('moderator') then
        return MODERATOR_COLOR
    end
    return nil
end

-- faction tag, shown like the game does: to everyone when the player shows it, else to the
-- members of the same faction
local function FactionTag(player, me)
    local ok, tag, color = pcall(function()
        local faction = Faction.getPlayerFaction(player:getUsername())
        if faction == nil then
            return nil
        end
        local mine = Faction.getPlayerFaction(me:getUsername())
        local sameFaction = mine ~= nil and mine:getName() == faction:getName()
        if player ~= me and not player:isShowTag() and not sameFaction then
            return nil
        end
        local tagColor = faction:getTagColor()
        local rgb = tagColor and { r = tagColor:getR(), g = tagColor:getG(), b = tagColor:getB() } or nil
        return faction:getTag(), rgb
    end)
    if ok then
        return tag, color
    end
    return nil
end

local function Clear()
    tags = {}
end

-- the mouse is over the character: between the top of the head and the feet, about as wide
-- as a body
local function IsMouseOver(player)
    local mouseX, mouseY = getMouseX(), getMouseY()
    local headX, headY = Coordinates.CenterTopOfPlayer(player, 0, 0)
    local _, feetY = Coordinates.CenterFeetOfPlayer(player, 0, 0)
    if headX == nil or feetY == nil then
        return false
    end
    local halfWidth = HOVER_HALF_WIDTH / Coordinates.GetZoom()
    return math.abs(mouseX - headX) <= halfWidth and mouseY >= headY + 10 and mouseY <= feetY
end

-- the player's choice in the chat settings: 'always', 'hover' or 'never'
local function Mode()
    return ISChat and ISChat.instance and ISChat.instance.nameTagsMode or 'always'
end

-- called every frame from ISChat:prerender
function NameTags.render()
    local mode = Mode()
    if not NameTags.isEnabled() or mode == 'never' then
        Clear()
        return
    end
    local me = getPlayer()
    local players = getOnlinePlayers()
    if me == nil or players == nil then
        return
    end
    local playerNum = me:getPlayerNum()
    local showMine = getCore():isShowYourUsername()
    -- like the game: invisible players (admin power) keep their name for viewers who can see
    -- player stats (admins)
    local ok, seesInvisible = pcall(function()
        local role = me:getRole()
        return role ~= nil and role:hasCapability(Capability.CanSeePlayersStats)
    end)
    seesInvisible = ok and seesInvisible == true
    local shown = {}
    for index = 0, players:size() - 1 do
        local other = players:get(index)
        local isMe = other == me or other:getUsername() == me:getUsername()
        local dx, dy = other:getX() - me:getX(), other:getY() - me:getY()
        local alpha = isMe and 1 or other:getAlpha(playerNum)
        local username = other:getUsername()
        local hovered = true
        local fade = 1
        if mode == 'hover' then
            local now = getTimestampMs()
            if IsMouseOver(other) then
                hoveredAt[username] = now
            end
            -- fully shown while the mouse is on them, then fading out
            fade = 1 - (now - (hoveredAt[username] or 0)) / HOVER_FADE_MS
            hovered = fade > 0
        end
        if hovered and (not isMe or showMine) and (seesInvisible or not other:isInvisible()) and alpha > 0.05
            and dx * dx + dy * dy <= RANGE * RANGE
        then
            local tag = tags[username]
            if tag == nil or tag.player ~= other then
                tag = NameTag:new(other)
                tags[username] = tag
            end
            local now = getTimestampMs()
            if now - (tag.labelAt or 0) >= LABEL_REFRESH_MS then
                tag.labelAt = now
                tag:setLabel(Label(other), StaffColor(other), FactionTag(other, me))
            end
            tag.alpha = math.min(1, alpha) * math.min(1, fade)
            tag:render()
            shown[username] = true
        end
    end
    for username in pairs(tags) do
        if not shown[username] then
            tags[username] = nil
        end
    end
end

return NameTags
