tr = require '../utils/translate'
isString = require '../utils/is-string'

ProviderInterface = (require './provider-interface').ProviderInterface
cloudContentFactory = (require './provider-interface').cloudContentFactory
CloudMetadata = (require './provider-interface').CloudMetadata

class UkdeProvider extends ProviderInterface

  # UCFM_PROTOCOL: values and formats of possible originA values
  _originA_pool =
    pro: 'https://ukde.physicsfront.com/'
    stg: 'https://ukde-stg.physicsfront.com/'
    dev: 'https://ukde-dev.physicsfront.com/'
  _originA_cands = []
  _originA = undefined

  _init_UKDE_data_connections = 2
  _n_check_UKDE = 0

  # UCFM_PROTOCOL: _JWTUCFM is a masked key, still needing to be protected.
  # Hidden in closure; should not be leaked outside this script.
  _JWTUCFM = undefined
  _getJWTUCFM_running_maybe = false

  constructor: (@options = {}, @client) ->
    if "name" of @options
      if @options.name isnt UkdeProvider.Name
        msg = "(Internal) Error: invalid provider name '#{@options.name}' " \
          + "was passed."
        alert msg
        throw Error msg
    if "originA" of @options
      if isString @options.originA
        _originA_cands=[ _originA_pool[@options.originA] ]
      else
        _originA_cands=(_originA_pool[k_] for k_ in @options.originA)
      for val in _originA_cands
        if not val
          throw Error "Error in options.originA---it must be a string " + \
            "('pro','stg', or 'dev') or an array of these strings."
      if _originA_cands.length > _originA_pool.length * 2
        throw Error "Too many elements passed to options.originA."
    else
      _originA_cands=(v_ for own k_, v_ of _originA_pool)
    console.log '_originA_cands = ' + JSON.stringify _originA_cands
    @ukdeFileType = @options.ukdeFileType
    _getJWTUCFM null, (=>
      @_getDefaultContent()
      @_getLastSavedContent_from_UKDE())
    setTimeout (=> @_check_UKDE_connection()), 1000
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

  @Name: 'ukde'

  _check_UKDE_connection: ->
    _n_check_UKDE++
    console.log "_check_UKDE_connection: called---will check!"
    a_ = []
    if _JWTUCFM is undefined and _originA is undefined
      a_.push "Failed to connect to UKDE---trouble ahead..."
    if @DefaultContent is undefined
      a_.push "Failed to get default content from UKDE---trouble ahead..."
    if @LastSavedContent is undefined
      a_.push "Failed to get last saved document from UKDE---trouble ahead..."
    if not a_.length
      console.log "_check_UKDE_connection: all is well---nice!"
      return
    if _getJWTUCFM_running_maybe or _init_UKDE_data_connections
      if _n_check_UKDE <= 25 # so, it is a total 6 (= 5 + 1) sec wait.
        setTimeout (=> @_check_UKDE_connection()), 200
        console.log "_check_UKDE_connection: will be called again..."
        return
    console.log "_check_UKDE_connection: not all is well... reporting " \
      + "problem(s)..."
    errstr = a_.join "\n"
    console.error errstr
    alert errstr

  _getLastSavedContent_from_UKDE: ->
    if not _originA
      _init_UKDE_data_connections -= 1
      console.error "originA is not ready---can't get lastSavedContent"
      return
    $.ajax
      type: "GET"
      data:
        filetype: @ukdeFileType
      url: _originA + "cfm/doc"
      dataType: 'json'
      success: (data) =>
        @LastSavedContent = JSON.stringify data
        _init_UKDE_data_connections -= 1
        console.log "File of type '#{@ukdeFileType}' was retrieved " \
          + "successfully from UKDE."
      error: (jqXHR) ->
        _init_UKDE_data_connections -= 1
        console.warn "_getLastSavedContent_from_UKDE ajax error!?: " + \
          JSON.stringify jqXHR.responseJSON
      beforeSend: (xhr) ->
        xhr.setRequestHeader "Authorization", "JWTUCFM " + _JWTUCFM

  _getDefaultContent: ->
    if not _originA
      _init_UKDE_data_connections -= 1
      console.error "originA is not ready---can't get DefaultContent"
      return
    $.ajax
      type: "GET"
      data:
        filetype: @ukdeFileType
      url: _originA + "cfm/default-doc"
      dataType: 'json'
      success: (data) =>
        @DefaultContent = JSON.stringify data
        _init_UKDE_data_connections -= 1
        console.log "Default content of type '#{@ukdeFileType}' was " \
          + "retrieved successfully from UKDE."
      error: (jqXHR) ->
        _init_UKDE_data_connections -= 1
        console.warn "_getDefaultContent ajax error!?: " + JSON.stringify \
          jqXHR.responseJSON

  ##
  # Calls up UKDE and obtains _JWTUCFM, the authorization token necessary for
  # all subsequent operations.
  #
  # In the process, this private function goes over all possible UKDE base
  # URLS (_originA_cands or _originA_pool).  The first URL that responds
  # successfully will be remembered as _originA.
  #
  # If originA is already known, then call this method with that value as the
  # first argument.  That value must be one of the values of _originA_cands.
  #
  # On success, this function will set _JWTUCFM and, if originA was a false
  # value, _originA.  So, these variables will persist over any failed calls
  # of this method, as this function does not touch these variables on
  # failure.
  #
  # In addition, callback will be invoked (with no arguments) on success.
  _getJWTUCFM = (originA, callback) ->
    _getJWTUCFM_running_maybe = true
    n_UKDE_calls = 0
    update_originA = true
    if originA
      if isString originA
        if originA not in _originA_cands
          console.error "Illegal value '#{originA}' was passed for originA."
          return
        originA_cands = [originA]
        update_originA = false
      else
        console.error "Illegal type (non-string) value '#{originA}' was " \
          + "passed for originA."
        return
    else
      originA_cands = _originA_cands
    # UCFM_PROTOCOL: reqkey is a short-lived secret for handshaking
    reqkey = (new Date).getTime() + '--' + \
      Math.round 1000000000000000 * Math.random()
    gotit = false
    call_UKDE = (originA_candidate, retry=false) ->
      if retry
        error_callback = (jqXHR) ->
          if gotit
            return
          console.warn "_getJWTUCFM ajax error!?: " + JSON.stringify \
            jqXHR.responseJSON
          if not gotit and jqXHR.responseJSON?.error is 'no-such-secret'
            console.log "handshake with UKDE failed---trying just once more"
            setTimeout ((this_can) -> not gotit and call_UKDE this_can), \
              1000, originA_candidate
          else
            n_UKDE_calls -= 1
            if n_UKDE_calls is 0
              _getJWTUCFM_running_maybe = false
      else
        error_callback = (jqXHR) ->
          if gotit
            return
          n_UKDE_calls -= 1
          if n_UKDE_calls is 0
            _getJWTUCFM_running_maybe = false
          console.warn "_getJWTUCFM ajax error!?: " + JSON.stringify \
            jqXHR.responseJSON
      $.ajax
        type: "POST"
        url: originA_candidate + "cfm/jwt"
        dataType: 'json'
        contentType: 'application/json'
        data: JSON.stringify secret: reqkey
        success: (data) ->
          if not gotit and data.JWTUCFM
            # UCFM_PROTOCOL: JWTUCFM
            _JWTUCFM = data.JWTUCFM
            if update_originA
              _originA = originA_candidate
            callback?()
            gotit = true
            _getJWTUCFM_running_maybe = false
          n_UKDE_calls -= 1
          if n_UKDE_calls is 0
            _getJWTUCFM_running_maybe = false
        error: error_callback
    for url in originA_cands
      if gotit
        break
      if not ((url.startsWith "https://") and (url.endsWith "/"))
        console.error "originA candidate url format error; skipping '#{url}'."
        continue
      # UCFM_PROTOCOL: reqkey is a short-lived secret for handshaking
      window.top.postMessage "ucfmr-heads-up--" + reqkey, url
      # UCFM_PROTOCOL: call_UKDE after a shor wait for handshake coordination
      setTimeout ((this_url) -> call_UKDE this_url, true), 500, url
      n_UKDE_calls += 1

  _renew_JWT_and_save: (content, metadata, callback) ->
    _getJWTUCFM _originA, (=> @save content, metadata, callback, false)

  authorized: (authCallback) ->
    authCallback !!_JWTUCFM

  save: (content, metadata, callback, retry=true) ->
    try
      if not _originA
        throw Error "originA is not ready---can't save"
      #window.localStorage.setItem fileKey, (content.getContentAsJSON?() or content)
      # TODO: String content.  What happens with JSON .codap file?  Call
      # content.getContentAsJSON?() or ...?
      unwrapped_content = content.getContent().content
      if not isString unwrapped_content
        throw Error "non-string content?!"
      $.ajax
        type: "POST"
        url: _originA + "cfm/doc"
        dataType: 'json'
        contentType: 'application/json'
        data: JSON.stringify
          filetype: @ukdeFileType
          DOCUCFM: unwrapped_content
        success: (data) =>
          @LastSavedContent = unwrapped_content
          console.log "File was saved successfully. Return data='#{data}'."
        error: (jqXHR) =>
          if retry and jqXHR.responseJSON?.error is 'Your JWTUCFM expired.'
            @_renew_JWT_and_save content, metadata, callback
          console.warn "save ajax error!?: " + JSON.stringify \
            jqXHR.responseJSON
      # console.log "== save: #{@LastSavedContent}"
      callback? null
    catch e
      callback? "Unable to save: #{e.message}"

  load: (metadata, callback) ->
    try
      content = cloudContentFactory.createEnvelopedCloudContent \
        (@LastSavedContent or @DefaultContent)
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
