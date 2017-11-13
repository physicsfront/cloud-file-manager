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
    # These calls are made synchronously, since it is important to initialize
    # key variables.
    @_getJWTUCFM null, (=>
      @_getDefaultContent false
      @_get_lastSavedContent_from_UKDE false), false
    super
      name: UkdeProvider.Name
      displayName: @options.displayName or (tr '~PROVIDER.UKDE')
      urlDisplayName: @options.urlDisplayName
      capabilities: # TODO: Should any "true" here better be "false"?
        save: true
        resave: true
        export: false
        load: true
        list: false
        remove: false
        rename: false
        close: true
    if _JWTUCFM is undefined or @_originA is undefined
      alert "Failed to connect to UKDE---trouble ahead..."
    else if @DefaultContent is undefined
      alert "Failed to get default content from UKDE---trouble ahead..."
    else if @_lastSavedContent is undefined
      alert "Failed to get last saved document from UKDE---trouble ahead..."

  @Name: 'ukde'
  @_defaultContent: {message: '... UKDE is being contacted---please wait ...'}

  # UCFM_PROTOCOL: values and formats of possible originA values
  @_originA_all: ['https://ukde.physicsfront.com/',
                  'https://ukde-stg.physicsfront.com/',
                  'https://ukde-dev.physicsfront.com/']

  # UCFM_PROTOCOL: _JWTUCFM is a masked key, still needing to be protected.
  # Hidden in closure; should not be leaked outside this script.
  _JWTUCFM = undefined

  _get_lastSavedContent_from_UKDE: (async=true) ->
    $.ajax
      type: "GET"
      url: @_originA + "cfm/doc"
      dataType: 'json'
      contentType: 'application/json'
      data: {filetype: @ukdeFileType}
      success: (data) =>
        @_lastSavedContent = data
        consol.log "File of type '#{@ukdeFileType}' was retrieved " \
          + "successfully from UKDE."
      error: (jqXHR) ->
        console.warn "_get_lastSavedContent_from_UKDE ajax error!?: " + \
          JSON.stringify jqXHR.responseJSON
      async: async

  _getDefaultContent: (async=true) ->
    $.ajax
      type: "GET"
      url: @_originA + "cfm/default-doc"
      dataType: 'json'
      contentType: 'application/json'
      data: {filetype: @ukdeFileType}
      success: (data) =>
        @DefaultContent = data
        consol.log "Default content of type '#{@ukdeFileType}' was " \
          + "retrieved successfully from UKDE."
      error: (jqXHR) ->
        console.warn "_getDefaultContent ajax error!?: " + JSON.stringify \
          jqXHR.responseJSON
      async: async

  ##
  # Call this method without any argument, or with false argument for
  # originA, to initialize _JWTUCFM and @_originA.  If originA is already
  # known, then call this method with that as argument.
  #
  # On success, it will set _JWTUCFM and, if originA was false, @_originA.
  # So, these variables will persist over any failed calls of this method.
  # In addition, `callback` will be invoked on success.
  #
  # This method does nothing on failure.
  _getJWTUCFM: (originA, callback, async=true) ->
    update_originA = true
    if originA
      if isString originA
        if originA not in UkdeProvider._originA_all
          console.error "Illegal value '#{originA}' was passed for originA."
          return
        originA_cands = [originA]
        update_originA = false
      else
        console.error "Illegal type (non-string) value '#{originA}' was " \
          + "passed for originA."
        return
    else
      originA_cands = UkdeProvider._originA_all
    # UCFM_PROTOCOL: reqkey is a short-lived secret for handshaking
    reqkey = (new Date).getTime() + '--' + \
      Math.round 1000000000000000 * Math.random()
    gotit = false
    call_UKDE = (originA_candidate, retry=false) =>
      if retry
        error_callback = (jqXHR) ->
          console.warn "_getJWTUCFM ajax error!?: " + JSON.stringify \
            jqXHR.responseJSON
          if not gotit and jqXHR.responseJSON?.error is 'no-such-secret'
            console.log "handshake with UKDE failed---trying just once more"
            setTimeout (-> not gotit and call_UKDE originA_candidate), 1000
      else
        error_callback = (jqXHR) ->
          console.warn "_getJWTUCFM ajax error!?: " + JSON.stringify \
            jqXHR.responseJSON
      $.ajax
        type: "POST"
        url: originA_candidate + "cfm/jwt"
        dataType: 'json'
        contentType: 'application/json'
        data: {secret: reqkey}
        success: (data) =>
          if not gotit and data.JWTUCFM
            # UCFM_PROTOCOL: JWTUCFM
            _JWTUCFM = data.JWTUCFM
            if update_originA
              @_originA = originA_candidate
            gotit = true
            callback?()
        error: error_callback
        async: async
        timeout: 3000
    for url in originA_cands
      if gotit
        break
      if not ((url.startsWith "https://") and (url.endsWith "/"))
        console.error "originA candidate url format error; skipping '#{url}'."
        continue
      # UCFM_PROTOCOL: reqkey is a short-lived secret for handshaking
      window.top.postMessage "ucfmr-heads-up--" + reqkey, url
      # UCFM_PROTOCOL: call_UKDE after a shor wait for handshake coordination
      setTimeout (-> call_UKDE url, true), 500

  _renew_JWT_and_save: (content, metadata, callback, retry=false) ->
    @_getJWTUCFM @_originA, (=> @save content, metadata, callback, retry)

  authorized: (authCallback) ->
    authCallback !!_JWTUCFM

  save: (content, metadata, callback, retry=true) ->
    try
      #window.localStorage.setItem fileKey, (content.getContentAsJSON?() or content)
      # TODO: String content.  What happens with JSON .codap file?  Call
      # content.getContentAsJSON?() or ...?
      unwrapped_content = content.getContent().content
      $.ajax
        type: "POST"
        url: @_originA + "cfm/doc"
        dataType: 'json'
        contentType: 'application/json'
        data:
          filetype: @ukdeFileType
          DOCUCFM: unwrapped_content
        success: (data) =>
          @_lastSavedContent = unwrapped_content
          consol.log "File was saved successfully. Return data='#{data}'."
        error: (jqXHR) =>
          if retry and jqXHR.responseJSON?.error is 'Your JWTUCFM expired.'
            @_renew_JWT_and_save content, metadata, callback
          console.warn "save ajax error!?: " + JSON.stringify \
            jqXHR.responseJSON
      # console.log "== save: #{@_lastSavedContent}"
      callback? null
    catch e
      callback? "Unable to save: #{e.message}"

  load: (metadata, callback) ->
    try
      content = cloudContentFactory.createEnvelopedCloudContent \
        (@_lastSavedContent or @DefaultContent)
    catch e
      callback? "Unable to load '#{metadata.name}': #{e.message}"
      return
    callback? null, content

  # "openSaved" is the only "open" mechanism that this provider supports.
  canOpenSaved: -> true

  # For ukde: filename = metadata.name = openSavedParams = ukdeFileType
  openSaved: (openSavedParams, callback) ->
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

module.exports = UkdeProvider
