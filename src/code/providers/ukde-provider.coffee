tr = require '../utils/translate'
isString = require '../utils/is-string'

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
    @_getJWTUCFM()
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

  # Hidden in closure; should not be leaked outside this script.
  _JWTUCFM = undefined

  ##
  # Call this method without any argument to initialize _JWTUCFM and
  # @_originA.  If originA is already known, then call this method with that
  # as argument.
  #
  # This method does nothing on failure.  On success, it will set _JWTUCFM
  # and, if no argument was given, @_originA.  So, these variables will
  # persist over any failed attempts to get JWTUCFM by calling this method
  _getJWTUCFM: (originA) ->
    update_originA = false
    if originA
      if isString originA
        originA = [originA]
      else
        console.error "Unacceptable non-string value '#{originA}' was " \
          + "passed for originA."
        return false
    else
      originA = ['https://ukde.physicsfront.com/',
        'https://ukde-stg.physicsfront.com/',
        'https://ukde-dev.physicsfront.com/']
      update_originA = true
    reqkey = (new Date).getTime() + '--' + \
      Math.round(1000000000000000 * Math.random())
    gotit = false
    call_UKDE = (originA_candidate, retry) =>
      if retry
        error_callback = ((jqXHR) ->
          if not gotit and jqXHR.responseJSON?.error is 'no-such-secret'
            setTimeout (-> not gotit and call_UKDE (originA_candidate)), 1000)
      else
        error_callback = undefined
      $.ajax
        type: "POST"
        url: originA_candidate + "jwt-cfm"
        dataType: 'json'
        data:
          secret: reqkey
        success: (data) =>
          if not gotit and data.JWTCFM
            _JWTUCFM = data.JWTCFM
            if update_originA
              @_originA = originA_candidate
            gotit = true
        error: error_callback
    for url in originA
      if gotit
        break
      if url.indexOf "https://"
        console.warn "originA url must start with https://; skipping '#{url}'."
        continue
      window.top.postMessage "ucfmr-heads-up--" + reqkey, url
      setTimeout (-> call_UKDE url, true), 500
    # just a bit paranoid here, but be mindful of security; make sure that
    # the return value is not leaking any sensitive data
    return !!gotit

  authorized: (authCallback) ->
    authCallback !!_JWTUCFM

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
