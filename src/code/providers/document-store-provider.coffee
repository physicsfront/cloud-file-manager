{div, button, span} = React.DOM

getQueryParam = require '../utils/get-query-param'
getHashParam = require '../utils/get-hash-param'
tr = require '../utils/translate'
isString = require '../utils/is-string'
jiff = require 'jiff'
pako = require 'pako'

ProviderInterface = (require './provider-interface').ProviderInterface
cloudContentFactory = (require './provider-interface').cloudContentFactory
CloudMetadata = (require './provider-interface').CloudMetadata

DocumentStoreUrl = require './document-store-url'
PatchableContent = require './patchable-content'

DocumentStoreAuthorizationDialog = React.createFactory React.createClass
  displayName: 'DocumentStoreAuthorizationDialog'

  getInitialState: ->
    docStoreAvailable: false

  componentWillMount: ->
    @props.provider._onDocStoreLoaded =>
      @setState docStoreAvailable: true

  authenticate: ->
    @props.provider.authorize()

  render: ->
    (div {className: 'document-store-auth'},
      (div {className: 'document-store-concord-logo'}, '')
      (div {className: 'document-store-footer'},
        if @state.docStoreAvailable
          (button {onClick: @authenticate}, 'Login to Concord')
        else
          'Trying to log into Concord...'
      )
    )

class DocumentStoreProvider extends ProviderInterface

  constructor: (@options = {}, @client) ->
    @options.deprecationPhase = 3
    super
      name: DocumentStoreProvider.Name
      displayName: @options.displayName or (tr '~PROVIDER.DOCUMENT_STORE')
      urlDisplayName: @options.urlDisplayName
      capabilities:
        save: @isNotDeprecated('save')
        resave: @isNotDeprecated('save')
        export: false
        load: @isNotDeprecated('load')
        list: @isNotDeprecated('list')
        remove: @isNotDeprecated('remove')
        rename: @isNotDeprecated('rename')
        close: false

    @urlParams = {
      documentServer: getQueryParam "documentServer"
      recordid: getQueryParam "recordid"
      runKey: getQueryParam "runKey"
      docName: getQueryParam "doc"
      docOwner: getQueryParam "owner"
    }
    # query params that can be removed after initial processing
    @removableQueryParams = ['recordid', 'doc', 'owner']

    @docStoreUrl = new DocumentStoreUrl @urlParams.documentServer

    @user = null

    @savedContent = new PatchableContent(@options.patchObjectHash)

  @Name: 'documentStore'

  can: (capability, metadata) ->
    # legacy sharing support - can't save to old-style shared documents
    return false if ((capability is 'save') or (capability is 'resave')) and metadata?.providerData?.owner
    super(capability, metadata)

  # if a runKey is specified, we don't need to authenticate at all
  isAuthorizationRequired: ->
    not (@urlParams.runKey or (@urlParams.docName and @urlParams.docOwner))

  authorized: (@authCallback) ->
    if @authCallback
      if @user
        @authCallback true
      else
        @_checkLogin()
    else
      @user isnt null

  authorize: (completionCallback) ->
    @_showLoginWindow(completionCallback)

  _onDocStoreLoaded: (@docStoreLoadedCallback) ->
    if @_docStoreLoaded
      @docStoreLoadedCallback()

  _checkLogin: ->
    loggedIn = (user) =>
      @user = user
      @_docStoreLoaded = true
      @docStoreLoadedCallback?()
      if user
        @_loginWindow?.close()
      @authCallback (user isnt null) if @authCallback

    $.ajax
      dataType: 'json'
      url: @docStoreUrl.checkLogin()
      xhrFields:
        withCredentials: true
      success: (data) -> loggedIn data
      error: -> loggedIn null

  _loginWindow: null

  _showLoginWindow: (completionCallback) ->
    if @_loginWindow and not @_loginWindow.closed
      @_loginWindow.focus()
    else

      computeScreenLocation = (w, h) ->
        screenLeft = window.screenLeft or screen.left
        screenTop  = window.screenTop  or screen.top
        width  = window.innerWidth  or document.documentElement.clientWidth  or screen.width
        height = window.innerHeight or document.documentElement.clientHeight or screen.height

        left = ((width / 2) - (w / 2)) + screenLeft
        top = ((height / 2) - (h / 2)) + screenTop
        return {left, top}

      width = 1000
      height = 480
      position = computeScreenLocation width, height
      windowFeatures = [
        'width=' + width
        'height=' + height
        'top=' + position.top or 200
        'left=' + position.left or 200
        'dependent=yes'
        'resizable=no'
        'location=no'
        'dialog=yes'
        'menubar=no'
      ]

      @_loginWindow = window.open(@docStoreUrl.authorize(), 'auth', windowFeatures.join())

      if @_loginWindow
        pollAction = =>
          try
            if (@_loginWindow.location.host is window.location.host)
              clearInterval poll
              @_loginWindow.close()
              @_checkLogin()
              completionCallback() if completionCallback
          catch e
            # console.log e

        poll = setInterval pollAction, 200

    @_loginWindow

  renderAuthorizationDialog: ->
    (DocumentStoreAuthorizationDialog {provider: @, authCallback: @authCallback})

  renderUser: ->
    if @user
      (span {}, (span {className: 'document-store-icon'}), @user.name)
    else
      null

  filterTabComponent: (capability, defaultComponent) ->
    # allow the save elsewhere button to hide the document provider tab in save
    if capability is 'save' and @disableForNextSave
      @disableForNextSave = false
      null
    else
      defaultComponent

  isNotDeprecated: (capability) ->
    if capability is 'save'
      @options.deprecationPhase < 2
    else
      @options.deprecationPhase < 3

  deprecationMessage: ->
    """
      <div style="text-align: left">
        <p style="margin: 10px 0;">
          <strong>#{tr ~CONCORD_CLOUD_DEPRECATION.SHUT_DOWN_MESSAGE}</strong>
        </p>
        <p style="margin: 10px 0;">
          #{tr ~CONCORD_CLOUD_DEPRECATION.PLEASE_SAVE_ELSEWHERE}
        </p>
      </div>
    """

  onProviderTabSelected: (capability) ->
    if capability is 'save' and @deprecationMessage()
      @client.alert @deprecationMessage(), (tr '~CONCORD_CLOUD_DEPRECATION.ALERT_SAVE_TITLE')

  handleUrlParams: ->
    if @urlParams.recordid
      @client.openProviderFile @name, { id: @urlParams.recordid }
      true # signal that the provider is handling the params
    else if @urlParams.docName and @urlParams.docOwner
      @client.openProviderFile @name, { name: @urlParams.docName, owner: @urlParams.docOwner }
      true # signal that the provider is handling the params
    else
      false

  list: (metadata, callback) ->
    $.ajax
      dataType: 'json'
      url: @docStoreUrl.listDocuments()
      context: @
      xhrFields:
        withCredentials: true
      success: (data) ->
        list = []
        for own key, file of data
          if @matchesExtension file.name
            list.push new CloudMetadata
              name: file.name
              providerData: {id: file.id}
              type: CloudMetadata.File
              provider: @
        callback null, list
      error: ->
        callback null, []
      statusCode:
        403: =>
          @user = null
          @authCallback false

  load: (metadata, callback) ->
    withCredentials = unless metadata.sharedContentId then true else false
    recordid = metadata.providerData?.id or metadata.sharedContentId
    requestData = {}
    requestData.recordid = recordid if recordid
    requestData.runKey = @urlParams.runKey if @urlParams.runKey
    if not recordid
      requestData.recordname = metadata.providerData?.name if metadata.providerData?.name
      requestData.owner = metadata.providerData?.owner if metadata.providerData?.owner
    $.ajax
      url: @docStoreUrl.loadDocument()
      dataType: 'json'
      data: requestData
      context: @
      xhrFields:
        {withCredentials}
      success: (data) ->
        content = cloudContentFactory.createEnvelopedCloudContent data

        # for documents loaded by id or other means (besides name),
        # capture the name for use in the CFM interface.
        # 'docName' at the top level for CFM-wrapped documents
        # 'name' at the top level for unwrapped documents (e.g. CODAP)
        # 'name' at the top level of 'content' for wrapped CODAP documents
        metadata.rename metadata.name or metadata.providerData.name or
                        data.docName or data.name or data.content?.name
        if metadata.name
          content.addMetadata docName: metadata.filename

        callback null, content
      statusCode:
        403: =>
          @user = null
          callback tr("~DOCSTORE.LOAD_403_ERROR", {filename: metadata.name or 'the file'}), 403

      error: (jqXHR) ->
        return if jqXHR.status is 403 # let statusCode handler deal with it
        message = if metadata.sharedContentId
          tr "~DOCSTORE.LOAD_SHARED_404_ERROR"
        else
          tr "~DOCSTORE.LOAD_404_ERROR", {filename: metadata.name or metadata.providerData?.id or 'the file'}
        callback message

  save: (cloudContent, metadata, callback) ->
    content = cloudContent.getContent()

    # See if we can patch
    patchResults = @savedContent.createPatch(content, @options.patch and metadata.overwritable)

    if patchResults.shouldPatch and not patchResults.diffLength
      # no reason to patch if there are no diffs
      callback null # no error indicates success
      return

    params = {}
    if metadata.providerData.id then params.recordid = metadata.providerData.id

    if not patchResults.shouldPatch and metadata.filename
      params.recordname = metadata.filename

    # If we are saving for the first time as a student in a LARA activity, then we do not have
    # authorization on the current document. However, we should have a runKey query parameter.
    # When we save with this runKey, the document will save our changes to a copy of the document,
    # owned by us.
    #
    # When we successfully save, we will get the id of the new document in the response, and use
    # this id for future saving. We can then save via patches, and don't need the runKey.
    if @urlParams.runKey
      params.runKey = @urlParams.runKey

    $.ajax
      dataType: 'json'
      type: 'POST'
      url: if patchResults.shouldPatch \
            then @docStoreUrl.patchDocument(params) \
            else @docStoreUrl.saveDocument(params)
      data: pako.deflate patchResults.sendContent
      contentType: patchResults.mimeType
      processData: false
      beforeSend: (xhr) ->
        xhr.setRequestHeader('Content-Encoding', 'deflate')
      context: @
      xhrFields:
        withCredentials: true
      success: (data) ->
        @savedContent.updateContent(if @options.patch then _.cloneDeep(content) else null)
        if data.id then metadata.providerData.id = data.id

        callback null, data
      statusCode:
        403: =>
          @user = null
          callback tr("~DOCSTORE.SAVE_403_ERROR", {filename: metadata.name}), 403
      error: (jqXHR) ->
        try
          return if jqXHR.status is 403 # let statusCode handler deal with it
          responseJson = JSON.parse jqXHR.responseText
          if responseJson.message is 'error.duplicate'
            callback tr "~DOCSTORE.SAVE_DUPLICATE_ERROR", {filename: metadata.name}
          else
            callback tr "~DOCSTORE.SAVE_ERROR_WITH_MESSAGE", {filename: metadata.name, message: responseJson.message}
        catch
          callback tr "~DOCSTORE.SAVE_ERROR", {filename: metadata.name}

  remove: (metadata, callback) ->
    $.ajax
      url: @docStoreUrl.deleteDocument()
      data:
        recordname: metadata.filename
      context: @
      xhrFields:
        withCredentials: true
      success: (data) ->
        callback null, data
      statusCode:
        403: =>
          @user = null
          callback tr("~DOCSTORE.REMOVE_403_ERROR", {filename: metadata.name}), 403
      error: (jqXHR) ->
        return if jqXHR.status is 403 # let statusCode handler deal with it
        callback tr "~DOCSTORE.REMOVE_ERROR", {filename: metadata.name}

  rename: (metadata, newName, callback) ->
    $.ajax
      url: @docStoreUrl.renameDocument()
      data:
        recordid: metadata.providerData.id
        newRecordname: CloudMetadata.withExtension newName
      context: @
      xhrFields:
        withCredentials: true
      success: (data) ->
        metadata.rename newName
        callback null, metadata
      statusCode:
        403: =>
          @user = null
          callback tr("~DOCSTORE.RENAME_403_ERROR", {filename: metadata.name}), 403
      error: (jqXHR) ->
        return if jqXHR.status is 403 # let statusCode handler deal with it
        callback tr "~DOCSTORE.RENAME_ERROR", {filename: metadata.name}

  canOpenSaved: -> true

  openSaved: (openSavedParams, callback) ->
    providerData = if typeof openSavedParams is "object" \
                      then openSavedParams \
                      else { id: openSavedParams }
    metadata = new CloudMetadata
      type: CloudMetadata.File
      provider: @
      providerData: providerData

    @load metadata, (err, content) =>
      @client.removeQueryParams @removableQueryParams
      callback err, content, metadata

  getOpenSavedParams: (metadata) ->
    metadata.providerData.id

  fileOpened: (content, metadata) ->
    deprecationPhase = @options.deprecationPhase or 0
    fromLara = !!getQueryParam("launchFromLara") or !!getHashParam("lara")
    return if not deprecationPhase or fromLara
    @client.confirmDialog {
      title: tr '~CONCORD_CLOUD_DEPRECATION.CONFIRM_SAVE_TITLE'
      message: @deprecationMessage()
      yesTitle: tr '~CONCORD_CLOUD_DEPRECATION.CONFIRM_SAVE_ELSEWHERE'
      noTitle: tr '~CONCORD_CLOUD_DEPRECATION.CONFIRM_DO_IT_LATER'
      hideNoButton: deprecationPhase >= 3
      callback: =>
        @disableForNextSave = true
        @client.saveFileAsDialog()
      rejectCallback: =>
        if deprecationPhase > 1
          @client.appOptions.autoSaveInterval = null
    }

module.exports = DocumentStoreProvider
