local LanguageManager = require('tics/client/languages/LanguageManager')


local ISReadLanguageBook = ISReadABook:derive("ISReadABook");


function ISReadLanguageBook:perform()
    ISReadABook.perform(self)

    if self.language ~= 'Forget' and not LanguageManager.LanguageExists(self.language) then
        print('TICS error: ISReadLanguageBook:perform: unknown language ' .. self.language)
        return
    end

    if self.language == 'Forget' then
        LanguageManager:forgetAll()
        ISChat.sendInfoToCurrentTab(getText('UI_TICS_Messages_languages_forgotten', getText('UI_TICS_Languages_en')))
        return
    else
        local languageTranslated = LanguageManager.GetLanguageTranslated(self.language)
        if LanguageManager:isKnown(self.language) then
            ISChat.sendErrorToCurrentTab(getText('UI_TICS_Messages_language_already_learnt', languageTranslated))
            return
        end
        LanguageManager:registerLanguage(self.language)
        ISChat.sendInfoToCurrentTab(getText('UI_TICS_Messages_language_learnt', languageTranslated))
    end

    local player = getPlayer()
    player:getInventory():Remove(self.item)
    player:removeFromHands(self.item)
end

function ISReadLanguageBook:start(character, item, time)
    self.item:setJobType(getText("ContextMenu_Read") .. ' ' .. self.item:getName());
    self.item:setJobDelta(0.0);
    self:setAnimVariable("ReadType", "book")
    self:setActionAnim(CharacterActionAnims.Read);

    self.displayItem = instanceItem('Base.SmithingMag3')
    self:setOverrideHandModels(nil, self.displayItem);

    self.character:setReading(true)
    self.character:reportEvent("EventRead");
    self.character:playSound("OpenMagazine")
end

function ISReadLanguageBook:new(character, item, language, time)
    local o = ISReadABook.new(self, character, item, time)
    setmetatable(o, self)
    self.__index = self
    o.language = language
    o.maxTime = o.maxTime * 0.1 -- we want to read it fast
    return o
end

return ISReadLanguageBook
