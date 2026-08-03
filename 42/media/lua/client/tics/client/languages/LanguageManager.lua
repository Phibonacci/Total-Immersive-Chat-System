local LanguageManager = {}

local LanguageRegister = 'ticsKnownLanguages'

LanguageManager.DefaultLanguage = 'English'

local AllLanguages = {
    ['Abkhazian']      = 'ab',
    ['Afar']           = 'aa',
    ['Afrikaans']      = 'af',
    ['Akan']           = 'ak',
    ['Albanian']       = 'sq',
    ['Amharic']        = 'am',
    ['Arabic']         = 'ar',
    ['Aragonese']      = 'an',
    ['Armenian']       = 'hy',
    ['Assamese']       = 'as',
    ['Avaric']         = 'av',
    ['Aymara']         = 'ay',
    ['Azerbaijani']    = 'az',
    ['Bambara']        = 'bm',
    ['Bashkir']        = 'ba',
    ['Basque']         = 'eu',
    ['Belarusian']     = 'be',
    ['Bengali']        = 'bn',
    ['Bislama']        = 'bi',
    ['Bosnian']        = 'bs',
    ['Breton']         = 'br',
    ['Bulgarian']      = 'bg',
    ['Burmese']        = 'my',
    ['Catalan']        = 'ca',
    ['Chamorro']       = 'ch',
    ['Chechen']        = 'ce',
    ['Chichewa']       = 'ny',
    ['Chinese']        = 'zh',
    ['Chuvash']        = 'cv',
    ['Cornish']        = 'kw',
    ['Corsican']       = 'co',
    ['Cree']           = 'cr',
    ['Croatian']       = 'hr',
    ['Czech']          = 'cs',
    ['Danish']         = 'da',
    ['Divehi']         = 'dv',
    ['Dutch']          = 'nl',
    ['Dzongkha']       = 'dz',
    ['English']        = 'en',
    ['Esperanto']      = 'eo',
    ['Estonian']       = 'et',
    ['Ewe']            = 'ee',
    ['Faroese']        = 'fo',
    ['Fijian']         = 'fj',
    ['Finnish']        = 'fi',
    ['French']         = 'fr',
    ['WesternFrisian'] = 'fy',
    ['Fulah']          = 'ff',
    ['Gaelic']         = 'gd',
    ['Galician']       = 'gl',
    ['Ganda']          = 'lg',
    ['Georgian']       = 'ka',
    ['German']         = 'de',
    ['Greek']          = 'el',
    ['Kalaallisut']    = 'kl',
    ['Guarani']        = 'gn',
    ['Gujarati']       = 'gu',
    ['HaitianHaitian'] = 'ht',
    ['Hausa']          = 'ha',
    ['Hebrew']         = 'he',
    ['Herero']         = 'hz',
    ['Hindi']          = 'hi',
    ['HiriMotu']       = 'ho',
    ['Hungarian']      = 'hu',
    ['Icelandic']      = 'is',
    ['Ido']            = 'io',
    ['Igbo']           = 'ig',
    ['Indonesian']     = 'id',
    ['Interlingua']    = 'ia',
    ['Interlingue']    = 'ie',
    ['Inuktitut']      = 'iu',
    ['Inupiaq']        = 'ik',
    ['Irish']          = 'ga',
    ['Italian']        = 'it',
    ['Japanese']       = 'ja',
    ['Javanese']       = 'jv',
    ['Kannada']        = 'kn',
    ['Kanuri']         = 'kr',
    ['Kashmiri']       = 'ks',
    ['Kazakh']         = 'kk',
    ['CentralKhmer']   = 'km',
    ['Kikuyu']         = 'ki',
    ['Kinyarwanda']    = 'rw',
    ['Kirghiz']        = 'ky',
    ['Komi']           = 'kv',
    ['Kongo']          = 'kg',
    ['Korean']         = 'ko',
    ['Kuanyama']       = 'kj',
    ['Kurdish']        = 'ku',
    ['Lao']            = 'lo',
    ['Latin']          = 'la',
    ['Latvian']        = 'lv',
    ['Limburgan']      = 'li',
    ['Lingala']        = 'ln',
    ['Lithuanian']     = 'lt',
    ['Luba']           = 'lu',
    ['Luxembourgish']  = 'lb',
    ['Macedonian']     = 'mk',
    ['Malagasy']       = 'mg',
    ['Malay']          = 'ms',
    ['Malayalam']      = 'ml',
    ['Maltese']        = 'mt',
    ['Manx']           = 'gv',
    ['Maori']          = 'mi',
    ['Marathi']        = 'mr',
    ['Marshallese']    = 'mh',
    ['Mongolian']      = 'mn',
    ['Nauru']          = 'na',
    ['Navajo']         = 'nv',
    ['NorthNdebele']   = 'nd',
    ['SouthNdebele']   = 'nr',
    ['Ndonga']         = 'ng',
    ['Nepali']         = 'ne',
    ['Norwegian']      = 'no',
    ['Bokmal']         = 'nb',
    ['Nynorsk']        = 'nn',
    ['Occitan']        = 'oc',
    ['Ojibwa']         = 'oj',
    ['Oriya']          = 'or',
    ['Oromo']          = 'om',
    ['Ossetian']       = 'os',
    ['Pali']           = 'pi',
    ['Pashto']         = 'ps',
    ['Persian']        = 'fa',
    ['Polish']         = 'pl',
    ['Portuguese']     = 'pt',
    ['Punjabi']        = 'pa',
    ['Quechua']        = 'qu',
    ['Romanian']       = 'ro',
    ['Romansh']        = 'rm',
    ['Rundi']          = 'rn',
    ['Russian']        = 'ru',
    ['NorthernSami']   = 'se',
    ['Samoan']         = 'sm',
    ['Sango']          = 'sg',
    ['Sanskrit']       = 'sa',
    ['Sardinian']      = 'sc',
    ['Serbian']        = 'sr',
    ['Shona']          = 'sn',
    ['Sindhi']         = 'sd',
    ['Sinhala']        = 'si',
    ['Slovak']         = 'sk',
    ['Slovenian']      = 'sl',
    ['Somali']         = 'so',
    ['SouthernSotho']  = 'st',
    ['Spanish']        = 'es',
    ['Sundanese']      = 'su',
    ['Swahili']        = 'sw',
    ['Swati']          = 'ss',
    ['Swedish']        = 'sv',
    ['Tagalog']        = 'tl',
    ['Tahitian']       = 'ty',
    ['Tajik']          = 'tg',
    ['Tamil']          = 'ta',
    ['Tatar']          = 'tt',
    ['Telugu']         = 'te',
    ['Thai']           = 'th',
    ['Tibetan']        = 'bo',
    ['Tigrinya']       = 'ti',
    ['Tonga']          = 'to',
    ['Tsonga']         = 'ts',
    ['Tswana']         = 'tn',
    ['Turkish']        = 'tr',
    ['Turkmen']        = 'tk',
    ['Twi']            = 'tw',
    ['Uighur']         = 'ug',
    ['Ukrainian']      = 'uk',
    ['Urdu']           = 'ur',
    ['Uzbek']          = 'uz',
    ['Venda']          = 've',
    ['Vietnamese']     = 'vi',
    ['Volapük']        = 'vo',
    ['Walloon']        = 'wa',
    ['Welsh']          = 'cy',
    ['Wolof']          = 'wo',
    ['Xhosa']          = 'xh',
    ['SichuanYi']      = 'ii',
    ['Yiddish']        = 'yi',
    ['Yoruba']         = 'yo',
    ['Zhuang']         = 'za',
    ['Zulu']           = 'zu',
}

function LanguageManager:getKnownLanguagesAndInitialize()
    local knownLanguages = ModData.get(LanguageRegister)
    if knownLanguages == nil or knownLanguages[LanguageManager.DefaultLanguage] == nil then
        knownLanguages = {
            [LanguageManager.DefaultLanguage] = AllLanguages[LanguageManager.DefaultLanguage]
        }
        ModData.add(LanguageRegister, knownLanguages)
    end
    return knownLanguages
end

function LanguageManager.GetLanguages()
    return AllLanguages
end

function LanguageManager.GetLanguageCode(languageName)
    return AllLanguages[languageName]
end

function LanguageManager:getKnownLanguages()
    return self:getKnownLanguagesAndInitialize()
end

function LanguageManager:isKnown(language)
    local knownLanguages = self:getKnownLanguagesAndInitialize()
    return knownLanguages[language] ~= nil
end

function LanguageManager:isCodeKnown(languageCode)
    local knownLanguages = self:getKnownLanguagesAndInitialize()
    for _, knownCode in pairs(knownLanguages) do
        if knownCode == languageCode then
            return true
        end
    end
    return false
end

function LanguageManager.LanguageExists(languageName)
    return AllLanguages[languageName] ~= nil
end

function LanguageManager:forgetAll()
    local knownLanguages = {
        [LanguageManager.DefaultLanguage] = AllLanguages[LanguageManager.DefaultLanguage]
    }
    ModData.add(LanguageRegister, knownLanguages)
end

function LanguageManager:registerLanguage(language)
    if not LanguageManager.LanguageExists(language) then
        print('TICS error: language does not exist: ' .. language)
    end
    if self:isKnown(language) then
        print('TICS info: cannot learn language, already known: ' .. language)
    end
    if not LanguageManager.LanguageExists(language) or self:isKnown(language) then
        return false
    end
    local knownLanguages = self:getKnownLanguagesAndInitialize()
    knownLanguages[language] = AllLanguages[language]
    print('TICS info: learning language: ' .. knownLanguages[language])
    ModData.add(LanguageRegister, knownLanguages)
    return true
end

function LanguageManager.GetLanguageTranslatedFromCode(languageCode)
    return getText('UI_TICS_Languages_' .. languageCode)
end

function LanguageManager.GetCodeFromLanguage(language)
    return AllLanguages[language]
end

function LanguageManager.GetLanguageFromCode(languageCode)
    for language, code in pairs(AllLanguages) do
        if languageCode == code then
            return language
        end
    end
    return nil
end

function LanguageManager.GetLanguageTranslated(language)
    local languageCode = AllLanguages[language]
    return LanguageManager.GetLanguageTranslatedFromCode(languageCode)
end

function LanguageManager:setCurrentLanguageFromCode(languageCode)
    local knownLanguages = self:getKnownLanguagesAndInitialize()
    for knownLanguage, knownCode in pairs(knownLanguages) do
        if knownCode == languageCode then
            self.currentLanguage = knownLanguage
        end
    end
end

function LanguageManager:getCurrentLanguage()
    return self.currentLanguage
end

LanguageManager.UnknownCharacters = {
    -- 'ƒ', '¢', '¤', '¥', '§', '¬', '°', '¶', '×', 'ø', 'þ',
    0x83, 0xA2, 0xA4, 0xA5, 0xA7, 0xAC, 0xB0, 0xB6, 0xD7, 0xF8, 0xFE,
}
local newUnknownCharacters = {}
for _, c in pairs(LanguageManager.UnknownCharacters) do
    local newChar = string.char(c)
    table.insert(newUnknownCharacters, newChar)
end
LanguageManager.UnknownCharacters = newUnknownCharacters
LanguageManager.UnknownCharactersLen = #LanguageManager.UnknownCharacters

function LanguageManager:getRandomMessage(message)
    local newMessage = ''
    for i = 1, #message do
        local c = message:sub(i, i)
        if c == '.' or c == '?' or c == '!' or c == ' ' or c == '-' or
            c == ',' or c == ';' or c == '*' or c == '_'
        then
            newMessage = newMessage .. c
        else
            local randomIndex = ZombRand(LanguageManager.UnknownCharactersLen - 1) + 1
            newMessage = newMessage .. LanguageManager.UnknownCharacters[randomIndex]
        end
    end
    return newMessage
end

local function CreateLanguageManager()
    local o = {}
    setmetatable(o, LanguageManager)
    LanguageManager.__index = LanguageManager
    o.currentLanguage = LanguageManager.DefaultLanguage
    return o
end

local instance = CreateLanguageManager()

return instance
