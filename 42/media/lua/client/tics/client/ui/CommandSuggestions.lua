-- Suggestions while typing a command in the chat: a list above the input box with the
-- commands matching what is typed ("/w" -> /whisper, /w), and the values of some arguments
-- (the known languages after /language, the players online in the private message channel).
-- Up and down choose a suggestion, tab completes it; without suggestions these keys keep
-- their usual use (message history, channel switch).

local ChatDropdown = require('tics/client/ui/ChatDropdown')
local ChatTheme = require('tics/client/ui/ChatTheme')
local ChatUI = require('tics/client/ui/ChatUI')
local Character = require('tics/shared/utils/Character')
local LanguageManager = require('tics/client/languages/LanguageManager')

local CommandSuggestions = {}

local MAX_ITEMS = 8

-- example argument of the TICS commands, shown next to them (like the help window)
local EXAMPLES = {
    color = '255,120,0',
    pitch = '1.2',
    roll = '2d6',
    language = 'en',
    introduce = 'Johnny',
}

local list = nil -- the open ChatDropdown, nil when hidden

local function Trim(command)
    return (command:gsub('%s+$', ''))
end

local function StartsWith(text, prefix)
    return text:sub(1, #prefix):lower() == prefix:lower()
end

local function ChannelAvailable(stream, settings, me)
    local setting = settings[stream.name]
    if stream.command == nil or setting == nil or not setting['enabled'] then
        return false
    end
    local username = me:getUsername()
    if stream.name == 'faction' then
        return Faction.getPlayerFaction(username) ~= nil
    elseif stream.name == 'safehouse' then
        return SafeHouse.hasSafehouse(username) ~= nil
    elseif stream.name == 'admin' then
        return Character.isAdmin(me)
    elseif stream.name == 'do' then
        return not setting['adminOnly'] or Character.isAdmin(me)
    end
    return true
end

local function CommandAvailable(command, settings, me)
    local options = settings['options'] or {}
    if command.name == 'language' then
        return options['languages'] == true
    elseif command.name == 'introduce' then
        return options['introductions'] ~= nil and options['introductions']['enabled'] == true
    elseif command.name == 'resetintroductions' then
        return Character.isAdmin(me)
    end
    return true
end

-- the commands matching what is typed ('/' and the start of a command)
local function CommandItems(typed)
    local settings = TicsServerSettings
    local me = getPlayer()
    local items = {}
    if settings == nil or me == nil then
        return items
    end
    for _, stream in ipairs(ISChat.allChatStreams) do
        if ChannelAvailable(stream, settings, me) then
            local command = Trim(stream.command)
            local short = stream.shortCommand and Trim(stream.shortCommand) or nil
            if StartsWith(command, typed) or (short and StartsWith(short, typed)) then
                table.insert(items, {
                    label = short and (command .. '  ' .. short) or command,
                    value = command,
                    detail = ChatUI.getChipLabel(stream),
                    color = ChatUI.getChipColor(stream),
                    exact = short == typed or command == typed,
                })
            end
        end
    end
    if settings['pm'] and settings['pm']['enabled'] and StartsWith('/r', typed) then
        table.insert(items, { label = '/r', value = '/r', detail = ChatUI.getChipLabel({ name = 'pm' }), exact = typed == '/r' })
    end
    for _, command in pairs(ISChat.ticsCommand) do
        if CommandAvailable(command, settings, me) then
            local short = command.shortCommand
            if StartsWith(command.command, typed) or (short and StartsWith(short, typed)) then
                table.insert(items, {
                    label = short and (command.command .. '  ' .. short) or command.command,
                    value = command.command,
                    detail = EXAMPLES[command.name],
                    exact = short == typed or command.command == typed,
                })
            end
        end
    end
    -- the command typed exactly first (its short form), then the channels in the order of the
    -- chat (say, whisper, low, yell...) and the other commands
    for index, item in ipairs(items) do
        item.order = index
    end
    table.sort(items, function(a, b)
        if a.exact ~= b.exact then
            return a.exact
        end
        return a.order < b.order
    end)
    return items
end

-- after /language or /la: the known languages starting with what is typed
local function LanguageItems(typed)
    local items = {}
    for language in pairs(LanguageManager:getKnownLanguages()) do
        local code = LanguageManager.GetCodeFromLanguage(language)
        if code and StartsWith(code, typed) then
            table.insert(items, {
                label = code,
                value = code,
                detail = LanguageManager.GetLanguageTranslated(language),
            })
        end
    end
    table.sort(items, function(a, b) return a.value < b.value end)
    return items
end

-- in the private message channel, before the first space: the players online
local function PlayerItems(typed)
    local items = {}
    local me = getPlayer():getUsername()
    local players = getOnlinePlayers()
    for index = 0, players:size() - 1 do
        local username = players:get(index):getUsername()
        if username ~= me and StartsWith(username, typed) then
            table.insert(items, { label = username, value = username })
        end
    end
    table.sort(items, function(a, b) return a.value:lower() < b.value:lower() end)
    return items
end

-- What the suggestions are for: 'command', 'language' or 'player', and the part being typed
local function Context(chat)
    local typed = chat.textEntry:getInternalText() or ''
    local chip = chat.inputChip
    if chip and chip.stream and chip.stream.name == 'pm' and not typed:find(' ', 1, true) then
        return 'player', typed
    end
    if typed:sub(1, 1) ~= '/' then
        return nil
    end
    if not typed:find(' ', 1, true) then
        return 'command', typed
    end
    local command, argument = typed:match('^(/%a+) (%S*)$')
    if command == '/language' or command == '/la' then
        return 'language', argument, command
    end
    return nil
end

function CommandSuggestions.isOpen()
    return list ~= nil and list:isOpen()
end

function CommandSuggestions.hide()
    if list then
        list:close()
        list = nil
    end
end

local function Accept(value)
    local chat = ISChat.instance
    local kind, _, command = Context(chat)
    CommandSuggestions.hide()
    if kind == 'command' and value == '/r' then
        chat:setInputText('/r') -- becomes '/pm <last author> ' in the private message tab
    elseif kind == 'command' then
        -- a channel command becomes the channel chip, a TICS command waits for its argument
        chat:setInputText(value .. ' ')
    elseif kind == 'language' then
        chat.textEntry:setText(command .. ' ' .. value)
    elseif kind == 'player' then
        chat.textEntry:setText(value .. ' ')
    end
    ISChat.onTextChange()
end

local function Place(chat)
    local entry = chat.textEntry
    local left = entry:getAbsoluteX() - (entry.chipWidth or 0)
    local top = entry:getAbsoluteY()
    list:placeAbove(left + list.width, top, top + entry:getHeight())
end

-- called when the text of the input box changes
function CommandSuggestions.update(chat)
    if chat == nil or not ISChat.focused or chat.textEntry == nil then
        CommandSuggestions.hide()
        return
    end
    local kind, typed = Context(chat)
    local items = {}
    if kind == 'command' then
        items = CommandItems(typed)
    elseif kind == 'language' then
        items = LanguageItems(typed)
    elseif kind == 'player' and typed ~= '' then
        items = PlayerItems(typed)
    end
    -- nothing to suggest, or only what is already typed in full
    if #items == 0 or (#items == 1 and items[1].value == typed) then
        CommandSuggestions.hide()
        return
    end
    while #items > MAX_ITEMS do
        table.remove(items)
    end
    if list == nil or not list:isOpen() then
        list = ChatDropdown:new(items, chat.textEntry, Accept, true)
        list:initialise()
        list:show()
    else
        list:setItems(items)
    end
    list.selected = 1
    Place(chat)
end

-- up / down: the previous / next suggestion; false when there is no list (history instead)
function CommandSuggestions.move(step)
    if not CommandSuggestions.isOpen() then
        return false
    end
    local count = #list.items
    list.selected = ((list.selected or 1) - 1 + step) % count + 1
    return true
end

-- tab: completes the chosen suggestion; false when there is no list (usual tab instead)
function CommandSuggestions.accept()
    if not CommandSuggestions.isOpen() then
        return false
    end
    local item = list.items[list.selected or 1]
    if item then
        Accept(item.value)
    end
    return true
end

return CommandSuggestions
