tr = require '../utils/translate'

ProviderInterface = (require './provider-interface').ProviderInterface
cloudContentFactory = (require './provider-interface').cloudContentFactory
CloudMetadata = (require './provider-interface').CloudMetadata

class UkdeProvider extends ProviderInterface

  constructor: (@options = {}, @client) ->
    if "name" of @options
      if @options.name isnt UkdeProvider.Name
        msg = "(Internal) Error: invalid provider name '#{@options.name}' " \
          + "was passed."
        alert msg
        throw Error msg
    @ukdeFileType = @options.ukdeFileType
    @DefaultContent = UkdeProvider._defaultContent
    # TODO: load _lastSavedContent from UKDE
    @_lastSavedContent = ""
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
        close: true

  @Name: 'ukde'
  @_defaultContent: 'This is the default text.'

  authorized: (authCallback) ->
    # TODO: check UKDE token
    authCallback true

  save: (content, metadata, callback) ->
    try
      # TODO: save to UKDE
      #fileKey = @_getKey(metadata.filename)
      #window.localStorage.setItem fileKey, (content.getContentAsJSON?() or content)
      # String content.  What happens with JSON .codap file?
      unwrapped_content = content.getContent().content
      @_lastSavedContent = unwrapped_content
      # console.log "== save: #{@_lastSavedContent}"
      callback? null
    catch e
      callback? "Unable to save: #{e.message}"

  load: (metadata, callback) ->
    try
      # console.log "== load: #{@_lastSavedContent}"
      # TODO: load _lastSavedContent from UKDE
      callback? null, cloudContentFactory.createEnvelopedCloudContent \
        (@_lastSavedContent or @DefaultContent)
    catch e
      console.error "Unable to load '#{metadata.name}': #{e}"
      # It may be that callback is now called twice in a row---is this OK?
      callback? "Unable to load '#{metadata.name}': #{e.message}"

  # "openSaved" is the only "open" mechanism that this provider supports.
  # For ukde: filename = metadata.name = openSavedParams = ukdeFileType
  canOpenSaved: -> true

  openSaved: (openSavedParams, callback) ->
    # console.log "== openSaved: called with #{openSavedParams}"
    metadata = new CloudMetadata
      name: openSavedParams
      type: CloudMetadata.File
      parent: null
      provider: @
    @load metadata, (err, content) ->
      callback? err, content, metadata

  # For ukde: filename = metadata.name = openSavedParams = ukdeFileType
  getOpenSavedParams: (metadata) ->
    if metadata and @ukdeFileType isnt metadata.name
      console.warn "Incorrect metadata.name (#{metadata.name})?! " \
        + "... reset to #{@ukdeFileType}"
      metadata.name = @ukdeFileType
    @ukdeFileType

  # TODO: not sure if I need this function; for autosave?
  # fileOpened: (content, metadata) -> null

module.exports = UkdeProvider
