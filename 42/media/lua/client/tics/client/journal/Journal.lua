-- Journal of the people the player's character met: everyone heard speaking in character,
-- with their character sheet as last received, the scenes shared with them and private notes.
--
-- Stored on the client in Zomboid/Lua/TICS/journal/<save name>/<own character name>/
--   people.txt         one line per person (index, kept in memory)
--   sheets/<id>.txt    personality & background, OOC notes (read when needed)
--   scenes/<id>.txt    the last lines of the scenes shared with them
--   notes/<id>.txt     the player's own notes
--   appearance/<id>.txt how they looked the last time they were seen (for the 3D portrait)
-- A person is a character: the username and the character name, like the server sheets.
--
-- A line belongs to the scene of everyone who spoke in the last minutes or stands within
-- /say range, so a scene keeps the whole conversation and not only the person's own lines.

local Appearance = require('tics/client/journal/Appearance')
local CharacterSheetManager = require('tics/client/CharacterSheetManager')
local ClientSettings = require('tics/client/ClientSettings')
local Character = require('tics/shared/utils/Character')
local World = require('tics/shared/utils/World')

local Journal = {}

local ROOT = 'TICS/journal/'
local SCENE_SPEAKER_MS = 5 * 60 * 1000 -- someone who spoke in the last 5 minutes is in the scene
local SCENE_MAX_LINES = 200
local SCENE_TRIM_AT = 260             -- the scene file is trimmed back to SCENE_MAX_LINES past this
local SAVE_DELAY_MS = 10 * 1000       -- the index is saved at most every 10 seconds
local APPEARANCE_DELAY_MS = 10 * 60 * 1000 -- the appearance of someone around is saved every 10 minutes

local people = {}          -- id -> person
local directory = nil      -- directory the people were loaded from
local dirty = false
local lastSaveMs = 0
local recentSpeakers = {}  -- id -> time of their last line
local sceneStarted = {}    -- id -> true once this session's header is in their scene file
local sheetAsked = {}      -- id -> true once their sheet was asked this session
local sheetsLoaded = false -- every sheet text read (for the search)
local appearanceSavedAt = {} -- id -> time their appearance was last saved this session
local listeners = {}

---------------------------------------------------------------------------- text files

local function Escape(text)
    return (text:gsub('\\', '\\\\'):gsub('\t', '\\t'):gsub('\r', ''):gsub('\n', '\\n'))
end

local function Unescape(text)
    return (text:gsub('\\(.)', function(c)
        if c == 't' then
            return '\t'
        elseif c == 'n' then
            return '\n'
        end
        return c
    end))
end

local function Split(line)
    local fields = {}
    for field in (line .. '\t'):gmatch('([^\t]*)\t') do
        table.insert(fields, Unescape(field))
    end
    return fields
end

local function Join(fields)
    local escaped = {}
    for index, field in ipairs(fields) do
        escaped[index] = Escape(tostring(field))
    end
    return table.concat(escaped, '\t')
end

local function ReadLines(path)
    local reader = getFileReader(path, false)
    if reader == nil then
        return {}
    end
    local lines = {}
    while true do
        local line = reader:readLine()
        if line == nil then
            break
        end
        table.insert(lines, line)
    end
    reader:close()
    return lines
end

local function WriteLines(path, lines, append)
    local writer = getFileWriter(path, true, append == true)
    if writer == nil then
        print('TICS error: Journal: cannot write ' .. path)
        return
    end
    for _, line in ipairs(lines) do
        writer:writeln(line)
    end
    writer:close()
end

-- characters a file name cannot hold on Windows, and '..' that the game refuses in paths
local function SafeName(name)
    return (name:gsub('[\\/:%*%?"<>|%c]', '_'):gsub('%.%.+', '.'))
end

---------------------------------------------------------------------------- people

local function MyCharacter()
    local player = getPlayer()
    if player == nil then
        return nil, nil
    end
    local firstName, lastName = Character.getFirstAndLastName(player)
    return player:getUsername(), firstName .. ' ' .. lastName
end

local function CurrentDirectory()
    local _, myName = MyCharacter()
    if myName == nil then
        return nil
    end
    return ROOT .. ClientSettings.getSaveName() .. '/' .. SafeName(myName) .. '/'
end

function Journal.makeId(username, name)
    return SafeName(username .. '_' .. name)
end

local INDEX_FIELDS = { 'id', 'username', 'name', 'firstSeen', 'lastSeen', 'favorite', 'sceneLines',
    'hasSheet', 'title', 'sheetUpdated', 'sheetGameDate' }

local function ParsePerson(line)
    local fields = Split(line)
    if #fields < #INDEX_FIELDS then
        return nil
    end
    return {
        id = fields[1],
        username = fields[2],
        name = fields[3],
        firstSeen = tonumber(fields[4]) or 0,
        lastSeen = tonumber(fields[5]) or 0,
        favorite = fields[6] == '1',
        sceneLines = tonumber(fields[7]) or 0,
        hasSheet = fields[8] == '1',
        title = fields[9],
        sheetUpdated = tonumber(fields[10]) or 0,
        sheetGameDate = fields[11],
    }
end

local function FormatPerson(person)
    return Join({ person.id, person.username, person.name, person.firstSeen, person.lastSeen,
        person.favorite and 1 or 0, person.sceneLines, person.hasSheet and 1 or 0, person.title,
        person.sheetUpdated, person.sheetGameDate })
end

function Journal.save()
    if directory == nil then
        return
    end
    local lines = {}
    for _, person in pairs(people) do
        table.insert(lines, FormatPerson(person))
    end
    WriteLines(directory .. 'people.txt', lines)
    dirty = false
    lastSaveMs = getTimestampMs()
end

local function Notify()
    for _, listener in ipairs(listeners) do
        listener()
    end
end

-- Loads the journal of the current character (a new character starts a new journal).
-- Returns false while there is no player.
local function EnsureLoaded()
    local current = CurrentDirectory()
    if current == nil then
        return false
    end
    if current == directory then
        return true
    end
    if dirty then
        Journal.save()
    end
    directory = current
    people = {}
    recentSpeakers = {}
    sceneStarted = {}
    appearanceSavedAt = {}
    sheetsLoaded = false
    for _, line in ipairs(ReadLines(directory .. 'people.txt')) do
        local person = ParsePerson(line)
        if person then
            people[person.id] = person
        end
    end
    Notify()
    return true
end

local function GetOrCreate(username, name, now)
    local id = Journal.makeId(username, name)
    local person = people[id]
    if person == nil then
        person = {
            id = id, username = username, name = name, firstSeen = now, lastSeen = now,
            favorite = false, sceneLines = 0, hasSheet = false, title = '', sheetUpdated = 0, sheetGameDate = '',
        }
        people[id] = person
        dirty = true
    end
    return person
end

-- every person of the journal, in no particular order
function Journal.getPeople()
    if not EnsureLoaded() then
        return {}
    end
    local list = {}
    for _, person in pairs(people) do
        table.insert(list, person)
    end
    return list
end

function Journal.setFavorite(person, favorite)
    person.favorite = favorite
    Journal.save()
    Notify()
end

function Journal.addListener(listener)
    table.insert(listeners, listener)
end

function Journal.removeListener(listener)
    for index, existing in ipairs(listeners) do
        if existing == listener then
            table.remove(listeners, index)
            return
        end
    end
end

---------------------------------------------------------------------------- dates

function Journal.gameDate()
    local time = getGameTime()
    return string.format('%04d-%02d-%02d %02d:%02d', time:getYear(), time:getMonth() + 1, time:getDay() + 1,
        time:getHour(), time:getMinutes())
end

-- real date of a timestamp, 'yyyy-MM-dd HH:mm' in the local time zone
function Journal.formatDate(ms)
    local calendar = Calendar.getInstance()
    calendar:setTimeInMillis(ms)
    return SimpleDateFormat.new('yyyy-MM-dd HH:mm', Locale.ENGLISH):format(calendar:getTime())
end

---------------------------------------------------------------------------- sheets

local function SheetPath(person)
    return directory .. 'sheets/' .. person.id .. '.txt'
end

-- personality & background and OOC notes of the saved sheet, read from disk once
function Journal.getSheetText(person)
    if not person.hasSheet then
        return '', ''
    end
    if person.background == nil then
        local lines = ReadLines(SheetPath(person))
        person.background = lines[1] and Unescape(lines[1]) or ''
        person.ooc = lines[2] and Unescape(lines[2]) or ''
    end
    return person.background, person.ooc
end

-- reads every saved sheet, for the search in the sheets
function Journal.loadAllSheets()
    if sheetsLoaded or not EnsureLoaded() then
        return
    end
    sheetsLoaded = true
    for _, person in pairs(people) do
        Journal.getSheetText(person)
    end
end

local function OnSheetReceived(sheet)
    if not EnsureLoaded() then
        return
    end
    local myUsername = MyCharacter()
    if sheet.username:lower() == myUsername:lower() or sheet.firstName == nil then
        return
    end
    local now = getTimestampMs()
    local person = GetOrCreate(sheet.username, sheet.firstName .. ' ' .. sheet.lastName, now)
    person.hasSheet = sheet.title ~= '' or sheet.background ~= '' or sheet.ooc ~= ''
    person.title = sheet.title
    person.background = sheet.background
    person.ooc = sheet.ooc
    person.sheetUpdated = now
    person.sheetGameDate = Journal.gameDate()
    WriteLines(SheetPath(person), { Escape(sheet.background), Escape(sheet.ooc) })
    Journal.save()
    Notify()
end

CharacterSheetManager.addListener(OnSheetReceived)

-- the sheet of someone speaking close enough is refreshed once per session
local function RefreshSheet(person)
    if sheetAsked[person.id] or not CharacterSheetManager.isEnabled() then
        return
    end
    local other = World.getPlayerByUsername(person.username)
    local me = getPlayer()
    if other == nil or me == nil then
        return
    end
    local range = TicsServerSettings and TicsServerSettings['say'] and TicsServerSettings['say']['range'] or 15
    local dx, dy = other:getX() - me:getX(), other:getY() - me:getY()
    if math.sqrt(dx * dx + dy * dy) <= range then
        sheetAsked[person.id] = true
        CharacterSheetManager.ask(person.username)
    end
end

---------------------------------------------------------------------------- appearance

local function AppearancePath(person)
    return directory .. 'appearance/' .. person.id .. '.txt'
end

-- the loaded player of this person (nil when not around, or playing another character)
function Journal.getLivePlayer(person)
    local player = World.getPlayerByUsername(person.username)
    if player == nil then
        return nil
    end
    local firstName, lastName = Character.getFirstAndLastName(player)
    if Journal.makeId(person.username, firstName .. ' ' .. lastName) ~= person.id then
        return nil
    end
    return player
end

-- saves how a loaded player looks, at most every few minutes per person
function Journal.captureAppearance(person, player)
    local now = getTimestampMs()
    if directory == nil or now - (appearanceSavedAt[person.id] or 0) < APPEARANCE_DELAY_MS then
        return
    end
    appearanceSavedAt[person.id] = now
    local ok, data = pcall(Appearance.capture, player)
    if not ok or data == nil then
        print('TICS error: Journal: cannot read the appearance of ' .. person.name .. ': ' .. tostring(data))
        return
    end
    local lines = {}
    for _, fields in ipairs(Appearance.toFields(data)) do
        table.insert(lines, Join(fields))
    end
    WriteLines(AppearancePath(person), lines)
end

-- saved appearance (see Appearance.capture), nil when they were never seen up close
function Journal.getAppearance(person)
    if directory == nil then
        return nil
    end
    local lines = {}
    for _, line in ipairs(ReadLines(AppearancePath(person))) do
        table.insert(lines, Split(line))
    end
    return Appearance.fromFields(lines)
end

---------------------------------------------------------------------------- scenes

local function ScenePath(person)
    return directory .. 'scenes/' .. person.id .. '.txt'
end

-- keeps the last SCENE_MAX_LINES lines, starting with the header of their session
local function TrimScene(person)
    local lines = ReadLines(ScenePath(person))
    if #lines <= SCENE_MAX_LINES then
        person.sceneLines = #lines
        return
    end
    local first = #lines - SCENE_MAX_LINES + 1
    local kept = {}
    if lines[first]:sub(1, 2) ~= 'S\t' then
        for index = first - 1, 1, -1 do
            if lines[index]:sub(1, 2) == 'S\t' then
                table.insert(kept, lines[index])
                break
            end
        end
    end
    for index = first, #lines do
        table.insert(kept, lines[index])
    end
    WriteLines(ScenePath(person), kept)
    person.sceneLines = #kept
end

local function AppendScene(person, now, fromThem, text)
    local lines = {}
    if not sceneStarted[person.id] then
        sceneStarted[person.id] = true
        table.insert(lines, Join({ 'S', now, Journal.gameDate() }))
    end
    table.insert(lines, Join({ 'L', now, fromThem and 1 or 0, text }))
    WriteLines(ScenePath(person), lines, true)
    person.sceneLines = person.sceneLines + #lines
    if person.sceneLines > SCENE_TRIM_AT then
        TrimScene(person)
    end
    dirty = true
end

-- { { header = true, time, gameDate } or { time, fromThem, text } } oldest first
function Journal.getScenes(person)
    if directory == nil then
        return {}
    end
    local scenes = {}
    for _, line in ipairs(ReadLines(ScenePath(person))) do
        local fields = Split(line)
        if fields[1] == 'S' then
            table.insert(scenes, { header = true, time = tonumber(fields[2]) or 0, gameDate = fields[3] or '' })
        elseif fields[1] == 'L' and #fields >= 4 then
            table.insert(scenes, { time = tonumber(fields[2]) or 0, fromThem = fields[3] == '1', text = fields[4] })
        end
    end
    return scenes
end

-- people of the journal within /say range of the player
local function NearbyPeople(me)
    local nearby = {}
    local players = getOnlinePlayers()
    if players == nil then
        return nearby
    end
    local range = TicsServerSettings and TicsServerSettings['say'] and TicsServerSettings['say']['range'] or 15
    for index = 0, players:size() - 1 do
        local other = players:get(index)
        if other ~= me and other:getUsername() ~= me:getUsername() then
            local dx, dy = other:getX() - me:getX(), other:getY() - me:getY()
            if math.sqrt(dx * dx + dy * dy) <= range then
                local firstName, lastName = Character.getFirstAndLastName(other)
                local person = people[Journal.makeId(other:getUsername(), firstName .. ' ' .. lastName)]
                if person then
                    table.insert(nearby, { person = person, player = other })
                end
            end
        end
    end
    return nearby
end

-- An in-character line shown in the chat (plain text, without the time).
-- username / name: its author, nil for lines without one. A line heard on the radio goes to
-- the scenes of its author and of the people around, but its author is not in the scene.
function Journal.addLine(text, username, name, isRadio)
    if not EnsureLoaded() then
        return
    end
    local me = getPlayer()
    local now = getTimestampMs()
    local authorId = nil
    if username and name and username:lower() ~= me:getUsername():lower() then
        local person = GetOrCreate(username, name, now)
        person.lastSeen = now
        authorId = person.id
        if not isRadio then
            recentSpeakers[authorId] = now
            RefreshSheet(person)
            local player = Journal.getLivePlayer(person)
            if player then
                Journal.captureAppearance(person, player)
            end
        end
    end

    local inScene = {}
    for id, time in pairs(recentSpeakers) do
        if now - time <= SCENE_SPEAKER_MS and people[id] then
            inScene[id] = people[id]
        else
            recentSpeakers[id] = nil
        end
    end
    for _, nearby in ipairs(NearbyPeople(me)) do
        nearby.person.lastSeen = now
        inScene[nearby.person.id] = nearby.person
        Journal.captureAppearance(nearby.person, nearby.player)
    end
    if authorId then
        inScene[authorId] = people[authorId]
    end
    for id, person in pairs(inScene) do
        AppendScene(person, now, id == authorId, text)
    end
    dirty = true
    Notify()
end

---------------------------------------------------------------------------- notes

local function NotesPath(person)
    return directory .. 'notes/' .. person.id .. '.txt'
end

function Journal.getNotes(person)
    if directory == nil then
        return ''
    end
    local lines = ReadLines(NotesPath(person))
    return lines[1] and Unescape(lines[1]) or ''
end

function Journal.setNotes(person, notes)
    if directory == nil then
        return
    end
    WriteLines(NotesPath(person), { Escape(notes) })
end

---------------------------------------------------------------------------- saving

Events.EveryOneMinute.Add(function()
    if dirty and getTimestampMs() - lastSaveMs >= SAVE_DELAY_MS then
        Journal.save()
    end
end)

return Journal
