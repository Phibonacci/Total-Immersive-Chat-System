-- Timed action reading a language book (learn a language, or forget them all).
--
-- In multiplayer the server rebuilds timed actions from their global class name (Type) and
-- runs complete() itself, so this class is shared and global. The book is applied in
-- complete(), on the server in multiplayer and locally in single player: the known languages
-- are stored on the server (KnownLanguages), the book is removed, and the player receives
-- the new list and the result to show in the chat.
--
-- Nothing is done in perform() on purpose: in multiplayer, once the server removed the book,
-- the client action is no longer valid (the book is not in the inventory) and is stopped,
-- so its perform() is not called.

require 'TimedActions/ISReadABook'

ISReadLanguageBook = ISReadABook:derive('ISReadLanguageBook')

-- 'learnt', 'already_known', 'forgotten' or nil when the book is invalid
local function ApplyBook(character, language)
    -- server modules, also loaded in single player; complete() never runs on a multiplayer client
    local KnownLanguages = require('tics/server/KnownLanguages')
    local Languages = require('tics/shared/languages/Languages')
    if language == 'Forget' then
        KnownLanguages.forgetAll(character)
        return 'forgotten'
    elseif Languages[language] == nil then
        print('TICS error: ISReadLanguageBook: unknown language ' .. tostring(language))
        return nil
    elseif KnownLanguages.isKnown(character, language) then
        return 'already_known'
    end
    KnownLanguages.learn(character, language)
    return 'learnt'
end

function ISReadLanguageBook:complete()
    self.item:setJobDelta(0.0)
    if isServer() and self.forceStopped then
        return true
    end

    local result = ApplyBook(self.character, self.language)
    if result == 'learnt' or result == 'forgotten' then
        self.character:removeFromHands(self.item)
        self.character:getInventory():Remove(self.item)
        sendRemoveItemFromContainer(self.character:getInventory(), self.item)
    end
    if result then
        local KnownLanguages = require('tics/server/KnownLanguages')
        local ServerSend = require('tics/server/network/ServerSend')
        ServerSend.KnownLanguages(self.character, KnownLanguages.get(self.character))
        ServerSend.LanguageBookRead(self.character, result, self.language)
    end
    return true
end

-- see ISReadABook.perform, without the book container: the book may already be removed
function ISReadLanguageBook:perform()
    self.character:setReading(false)
    self.item:setJobDelta(0.0)
    local container = self.item:getContainer()
    if container then
        container:setDrawDirty(true)
    end
    self.character:playSound('CloseMagazine')

    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self)
end

function ISReadLanguageBook:start()
    self.item:setJobType(getText('ContextMenu_Read') .. ' ' .. self.item:getName())
    self.item:setJobDelta(0.0)
    self:setAnimVariable('ReadType', 'book')
    self:setActionAnim(CharacterActionAnims.Read)

    self.displayItem = instanceItem('Base.SmithingMag3')
    self:setOverrideHandModels(nil, self.displayItem)

    self.character:setReading(true)
    self.character:reportEvent('EventRead')
    self.character:playSound('OpenMagazine')
end

-- the parameter names matter: the server rebuilds the action by calling new() with the
-- fields of the same names (character, item, language)
function ISReadLanguageBook:new(character, item, language)
    local o = ISReadABook.new(self, character, item)
    o.language = language
    o.maxTime = o.maxTime * 0.1 -- we want to read it fast
    return o
end

return ISReadLanguageBook
