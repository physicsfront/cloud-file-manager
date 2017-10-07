tr = require '../utils/translate'

ProviderInterface = (require './provider-interface').ProviderInterface
cloudContentFactory = (require './provider-interface').cloudContentFactory
CloudMetadata = (require './provider-interface').CloudMetadata

class UkdeProvider extends ProviderInterface

  constructor: (@options = {}, @client) ->
    super
      name: UkdeProvider.Name
      displayName: @options.displayName or (tr '~PROVIDER.UKDE')
      urlDisplayName: @options.urlDisplayName
      capabilities:
        save: true
        resave: true
        export: false
        load: true
        list: false
        remove: false
        rename: false
        close: false

  @Name: 'ukde'
  @Available: ->
    result = try
      # must be a singleton function
      # carry out initial ukde startup if necessary, store answer, and return
      # answer
      #test = 'LocalStorageProvider::auth'
      #window.localStorage.setItem(test, test)
      #window.localStorage.removeItem(test)
      true
    catch
      false

  save: (content, metadata, callback) ->
    try
      # TODO: replace this with UKDE stuff
      #fileKey = @_getKey(metadata.filename)
      #window.localStorage.setItem fileKey, (content.getContentAsJSON?() or content)
      callback? null
    catch e
      callback? "Unable to save: #{e.message}"

  load: (metadata, callback) ->
    try
      # TODO: replace this with UKDE stuff
      #content = window.localStorage.getItem @_getKey metadata.filename
      #callback? null, cloudContentFactory.createEnvelopedCloudContent content
    catch e
      callback? "Unable to load '#{metadata.name}': #{e.message}"

  # not using any url hash
  canOpenSaved: -> false

  openSaved: (openSavedParams, callback) ->
    # This seems to be one place where metadata is assigned
    metadata = new CloudMetadata
      name: openSavedParams
      type: CloudMetadata.File
      parent: null
      provider: @
    @load metadata, (err, content) -> callback err, content, metadata

  getOpenSavedParams: (metadata) -> metadata.name

  _getKey: (name = '') ->
    "cfm::#{name.replace /\t/g, ' '}"

module.exports = UkdeProvider
