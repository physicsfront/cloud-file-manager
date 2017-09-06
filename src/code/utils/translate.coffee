translations =  {}
translations['en'] = require './lang/en-us.json'
defaultLang = 'en'
varRegExp = /%\{\s*([^}\s]*)\s*\}/g

translate = (key, vars={}, lang=defaultLang) ->
  translation = translations[lang]?[key] or key
  if translation
    translation.replace varRegExp, (match, key) ->
      if vars.hasOwnProperty key then vars[key] else "'** UKNOWN KEY: #{key} **"

module.exports = translate
