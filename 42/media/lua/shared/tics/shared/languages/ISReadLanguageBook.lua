-- Timed action reading a language book (learn a language, or forget them all).
--
-- In multiplayer the server rebuilds timed actions from their global class name (Type) and
-- runs complete() itself, so this class is shared and global. The book is removed in
-- complete(): on the server in multiplayer, locally in single player. perform() only runs on
-- the client, it handles the known languages and the chat messages.

require 'TimedActions/ISReadABook'

ISReadLanguageBook = ISReadABook:derive('ISReadLanguageBook')

local function IsLanguageKnownOnServer(character, language)
    -- server module, also loaded in single player
    local ok, KnownLanguages = pcall(require, 'tics/server/KnownLanguages')
    if not ok or type(KnownLanguages) ~= 'table' then
        return false
    end
    return KnownLanguages.get(character)[language] ~= nil
end

function ISReadLanguageBook:perform()
    ISReadABook.perform(self)
    -- client side modules: perform() never runs on a dedicated server
    local LanguageManager = require('tics/client/languages/LanguageManager')

    if self.language ~= 'Forget' and not LanguageManager.LanguageExists(self.language) then
        print('TICS error: ISReadLanguageBook:perform: unknown language ' .. self.language)
        return
    end

    if self.language == 'Forget' then
        LanguageManager:forgetAll()
        ISChat.sendInfoToCurrentTab(getText('UI_TICS_Messages_languages_forgotten', getText('UI_TICS_Languages_en')))
    else
        local languageTranslated = LanguageManager.GetLanguageTranslated(self.language)
        if LanguageManager:isKnown(self.language) then
            ISChat.sendErrorToCurrentTab(getText('UI_TICS_Messages_language_already_learnt', languageTranslated))
            return
        end
        LanguageManager:registerLanguage(self.language)
        ISChat.sendInfoToCurrentTab(getText('UI_TICS_Messages_language_learnt', languageTranslated))
    end
end

function ISReadLanguageBook:complete()
    self.item:setJobDelta(0.0)
    if isServer() and self.forceStopped then
        return true
    end
    -- a book of an already known language is kept, like the client does not learn it again
    if self.language ~= 'Forget' and IsLanguageKnownOnServer(self.character, self.language) then
        return true
    end
    self.character:removeFromHands(self.item)
    self.character:getInventory():Remove(self.item)
    sendRemoveItemFromContainer(self.character:getInventory(), self.item)
    return true
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
