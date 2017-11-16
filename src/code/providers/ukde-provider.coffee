tr = require '../utils/translate'
isString = require '../utils/is-string'
jsststringify = require 'json-stable-stringify'

ProviderInterface = (require './provider-interface').ProviderInterface
cloudContentFactory = (require './provider-interface').cloudContentFactory
CloudMetadata = (require './provider-interface').CloudMetadata

class UkdeProvider extends ProviderInterface

  ##
  # UCFM_PROTOCOL: values and formats of possible originA values
  #
  # A client is advised to specify one originA through options.originA when
  # registering this provider (see below).  Having said this, it is worth
  # noting that there is no harm done at all for unspecifying
  # options.originA.  In such a case, there will be some error messages
  # printed out to console.  That's all.
  #
  # In the future, the default value for options.originA may change to a
  # single value rather than all possible values (current default).
  #
  # Multiple options.originA values (which must be valid keys to
  # _originA_pool) cause this script to try all and take the first URL that
  # responds successfully.
  _originA_pool =
    pro: 'https://ukde.physicsfront.com/'
    stg: 'https://ukde-stg.physicsfront.com/'
    dev: 'https://ukde-dev.physicsfront.com/'
  # It has been observed to be critical that this initial assignment of
  # _originA_cands appears before constructor, which assigns _originA_cands
  # based on options.originA.
  _originA_cands = []
  _originA = undefined

  _init_UKDE_data_connections = 2
  _n_check_UKDE = 0

  # UCFM_PROTOCOL: _JWTUCFM is a masked key, still needing to be protected.
  # Hidden in closure; should not be leaked outside this script.
  _JWTUCFM = undefined
  _getJWTUCFM_running_maybe = false

  _OK = false

  ##
  # Calls up UKDE and obtains _JWTUCFM, the authorization token necessary for
  # all subsequent operations.
  #
  # In the process, this private function goes over all possible UKDE base
  # URLS (_originA_cands).  The first URL that responds successfully will be
  # remembered as _originA.
  #
  # If _originA is already known, then call this method with that value as
  # the first argument.  That value must be one of the values of
  # _originA_cands (checked).
  #
  # On success, this function will set _JWTUCFM and, if originA argument was
  # passed a false value, _originA.  So, variables _JWTUCFM and _originA will
  # persist over any failed calls of this method, as this function does not
  # touch them in any way by failed calls of this function.
  #
  # In addition, callback will be invoked (no arguments) on success.
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
            console.log "handshake with UKDE failed---trying one more time"
            setTimeout ((this_cand) -> not gotit and call_UKDE this_cand), \
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
      # UCFM_PROTOCOL: necessary format of originA candidates
      if not ((url.startsWith "https://") and (url.endsWith "/"))
        console.error "originA candidate url format error; skipping '#{url}'."
        continue
      # UCFM_PROTOCOL: reqkey is a short-lived secret for handshaking
      window.top.postMessage "ucfmr-heads-up--" + reqkey, url
      # UCFM_PROTOCOL: call_UKDE after a shor wait for handshake coordination
      setTimeout ((this_url) -> call_UKDE this_url, true), 500, url
      n_UKDE_calls += 1

  constructor: (@options = {}, @client) ->
    if "name" of @options
      if @options.name isnt UkdeProvider.Name
        msg = "(Internal) Error: invalid provider name '#{@options.name}' " \
          + "was passed."
        alert msg
        throw Error msg
    if "originA" of @options
      # possible values?---see "throw Error" below.
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
    if "autoOpen" not of @options
      @options.autoOpen = true
    @ukdeFileType = @options.ukdeFileType
    _getJWTUCFM null, (=>
      @_getDefaultContent()
      @_getLastSavedContent_from_UKDE())
    # Just passing @_check_UKDE_connection to setTimeout causes problems in
    # recursive calls of @_check_UKDE_connection.  Inside that method, it
    # turns out @_check_UKDE_connection is undefined!  Some sort of scope
    # issue?
    setTimeout (=> @_check_UKDE_connection()), 500
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

  _check_UKDE_connection: ->
    _n_check_UKDE++
    console.log "_check_UKDE_connection: called to duty---will do!"
    a_ = []
    if _JWTUCFM is undefined and _originA is undefined
      a_.push "Failed to connect to UKDE---trouble ahead..."
    if @DefaultContent is undefined
      a_.push "Failed to get default content from UKDE---trouble ahead..."
    if @LastSavedContent is undefined
      a_.push "Failed to get last saved document from UKDE---trouble ahead..."
    if not a_.length
      console.log "_check_UKDE_connection: all is well---nice!"
      if @options.autoOpen
        console.log '_check_UKDE_connection: auto-opening ukde file...'
        @client.openProviderFile UkdeProvider.Name, @ukdeFileType
      _OK = true
      return
    if _getJWTUCFM_running_maybe or _init_UKDE_data_connections
      if _n_check_UKDE <= 16 # so, it is a total 5 (= 4 + 1) sec wait.
        setTimeout (=> @_check_UKDE_connection()), 250
        console.log "_check_UKDE_connection: script may be busy... will " \
          + "wait a little and call again."
        return
    console.warn "_check_UKDE_connection: not all is well... reporting " \
      + "problem(s)..."
    errstr = a_.join "\n"
    console.error errstr
    alert errstr

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
        data = data.DOCUCFM
        if isString data
          data = JSON.parse data
        @DefaultContent = data
        _init_UKDE_data_connections -= 1
        console.log "Default content of type '#{@ukdeFileType}' was " \
          + "retrieved successfully from UKDE."
      error: (jqXHR) ->
        _init_UKDE_data_connections -= 1
        console.warn "_getDefaultContent ajax error!?: " + JSON.stringify \
          jqXHR.responseJSON

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
        data = data.DOCUCFM
        if isString data
          data = JSON.parse data
        @LastSavedContent = data
        _init_UKDE_data_connections -= 1
        console.log "File of type '#{@ukdeFileType}' was retrieved " \
          + "successfully from UKDE."
      error: (jqXHR) ->
        _init_UKDE_data_connections -= 1
        console.warn "_getLastSavedContent_from_UKDE ajax error!?: " + \
          JSON.stringify jqXHR.responseJSON
      beforeSend: (xhr) ->
        xhr.setRequestHeader "Authorization", "JWTUCFM " + _JWTUCFM

  _renew_JWT_and_save: (content, metadata, callback) ->
    _getJWTUCFM _originA, (=> @save content, metadata, callback, false)

  authorized: (authCallback) ->
    authCallback !!_JWTUCFM

  # "openSaved" is the only "open" mechanism that this provider supports.
  canOpenSaved: -> true

  close: (metadata, callback) ->
    if not _originA
      throw Error "originA is not ready---can't save"
    $.ajax
      type: "POST"
      url: _originA + "cfm/doc"
      dataType: 'json'
      contentType: 'application/json'
      data: JSON.stringify
        filetype: @ukdeFileType
        action: "close"
      success: (data) ->
        console.log "File was closed successfully."
        callback?()
      error: (jqXHR) ->
        console.warn "close ajax error!?: " + JSON.stringify \
          jqXHR.responseJSON
      beforeSend: (xhr) ->
        xhr.setRequestHeader "Authorization", "JWTUCFM " + _JWTUCFM

  # For ukde: filename = metadata.name = openSavedParams = ukdeFileType
  getOpenSavedParams: (metadata) ->
    if metadata and @ukdeFileType isnt metadata.name
      console.warn "Incorrect metadata.name (#{metadata.name})?! " \
        + "... reset to #{@ukdeFileType}"
      metadata.name = @ukdeFileType
    @ukdeFileType

  load: (metadata, callback) ->
    try
      # @LastSavedContent or @DefaultContent are objects, not JSON's anymore.
      content = cloudContentFactory.createEnvelopedCloudContent \
        (@LastSavedContent or @DefaultContent)
    catch e
      callback? "Unable to load '#{metadata.name}': #{e.message}"
      return
    callback? null, content

  # For ukde: filename = metadata.name = openSavedParams = ukdeFileType
  openSaved: (openSavedParams, callback) ->
    metadata = new CloudMetadata
      name: openSavedParams
      type: CloudMetadata.File
      parent: null
      provider: @
    @load metadata, (err, content) ->
      callback? err, content, metadata

  save: (content, metadata, callback, retry=true) ->
    try
      if not _originA
        throw Error "originA is not ready---can't save"
      unwrapped_content = content.getContent().content
      unwrapped_content_json = unwrapped_content
      if isString unwrapped_content_json
        unwrapped_content = JSON.parse (unwrapped_content)
      else
        unwrapped_content_json = JSON.stringify (unwrapped_content_json)
      $.ajax
        type: "POST"
        url: _originA + "cfm/doc"
        dataType: 'json'
        contentType: 'application/json'
        data: JSON.stringify
          filetype: @ukdeFileType
          DOCUCFM: unwrapped_content_json
        success: (data) =>
          @LastSavedContent = unwrapped_content
          console.log "File was saved successfully.  Return " + \
            "data='#{JSON.stringify data}'."
        error: (jqXHR) =>
          if retry and jqXHR.responseJSON?.error is 'Your JWTUCFM expired.'
            @_renew_JWT_and_save content, metadata, callback
          console.warn "save ajax error!?: " + JSON.stringify \
            jqXHR.responseJSON
        beforeSend: (xhr) ->
          xhr.setRequestHeader "Authorization", "JWTUCFM " + _JWTUCFM
      callback? null
    catch e
      callback? "Unable to save: #{e.message}"

  ##
  # Returns standard "pretty-print" JSON for use with UCFM.  If obj is
  # already is a string, then it is parsed and then stringified again by
  # default.  However, if it is a trusted stardard JSON, then trust_str can
  # be passed a true value, and the string will be returned as is.
  #
  # This method is currently not used in this module.  It is kept here as a
  # utiltiy method.
  standardDOCUCFMJSON: (obj, trust_str = false) ->
    if isString obj
      if trust_str
        return obj
      else
        obj = JSON.parse obj
    jsststringify obj, space: 3

  working: ->
    _OK

module.exports = UkdeProvider
