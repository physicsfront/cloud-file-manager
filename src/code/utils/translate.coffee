urlParams = require './url-params'

languageFiles = {
  'en-US': require './lang/en-US'
  'he': require './lang/he'
  'tr': require './lang/tr'
  'zh-TW': require './lang/zh-TW'
}

translations =  {}
_.each languageFiles, (langContents, langKey) ->
  translations[langKey] = langContents
  # accept full key with region code or just the language code
  if (dashLoc = langKey.indexOf('-')) > 0
    lang = langKey.substring(0, dashLoc)
    translations[lang] = langContents
  return

defaultLang = null
# default to English unless the user expresses another preference (via URL param for now)
defaultLang = urlParams.lang if urlParams.lang and translations[urlParams.lang]
# use language of page, which is used by CODAP, with separate build for each language
if (not defaultLang?) and document.documentElement.lang and (document.documentElement.lang isnt "unknown")
  defaultLang = document.documentElement.lang
defaultLang = 'en' if not defaultLang?

varRegExp = /%\{\s*([^}\s]*)\s*\}/g

translate = (key, vars={}, lang=defaultLang) ->
  translation = translations[lang]?[key]
  translation = key if not translation?
  translation.replace varRegExp, (match, key) ->
    if vars.hasOwnProperty key then vars[key] else "'** UKNOWN KEY: #{key} **"

module.exports = translate
