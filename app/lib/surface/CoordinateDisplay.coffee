module.exports = class CoordinateDisplay extends createjs.Container
  layerPriority: -10
  subscriptions:
    'surface:mouse-moved': 'onMouseMove'
    'surface:mouse-out': 'onMouseOut'
    'surface:mouse-over': 'onMouseOver'
    'surface:stage-mouse-down': 'onMouseDown'
    'camera:zoom-updated': 'onZoomUpdated'

  constructor: (options) ->
    super()
    @initialize()
    @camera = options.camera
    console.error 'CoordinateDisplay needs camera.' unless @camera
    @build()
    @show = _.debounce @show, 125
    Backbone.Mediator.subscribe(channel, @[func], @) for channel, func of @subscriptions

  destroy: ->
    Backbone.Mediator.unsubscribe(channel, @[func], @) for channel, func of @subscriptions
    @show = null
    @destroyed = true

  build: ->
    @mouseEnabled = @mouseChildren = false
    @addChild @background = new createjs.Shape()
    @addChild @label = new createjs.Text('', 'bold 16px Arial', '#FFFFFF')
    @addChild @pointMarker = new createjs.Shape()
    @label.name = 'Coordinate Display Text'
    @label.shadow = new createjs.Shadow('#000000', 1, 1, 0)
    @background.name = 'Coordinate Display Background'
    @pointMarker.name = 'Point Marker'
    @containerOverlay = new createjs.Shape() # FOR TESTING - REMOVE BEFORE COMMIT

  onMouseOver: (e) -> @mouseInBounds = true
  onMouseOut: (e) -> @mouseInBounds = false

  onMouseMove: (e) ->
    if @mouseInBounds and key.shift
      $('#surface').addClass('flag-cursor') unless $('#surface').hasClass('flag-cursor')
    else if @mouseInBounds
      $('#surface').removeClass('flag-cursor') if $('#surface').hasClass('flag-cursor')
    wop = @camera.screenToWorld x: e.x, y: e.y
    wop.x = Math.round(wop.x)
    wop.y = Math.round(wop.y)
    return if wop.x is @lastPos?.x and wop.y is @lastPos?.y
    @lastPos = wop
    @hide()
    @show()  # debounced

  onMouseDown: (e) ->
    return unless key.shift
    wop = @camera.screenToWorld x: e.x, y: e.y
    wop.x = Math.round wop.x
    wop.y = Math.round wop.y
    Backbone.Mediator.publish 'surface:coordinate-selected', wop

  onZoomUpdated: (e) ->
    @hide()
    @show()

  hide: ->
    return unless @label.parent
    @removeChild @label
    @removeChild @background
    @removeChild @pointMarker
    @removeChild @containerOverlay  # FOR TESTING - REMOVE BEFORE COMMIT
    @uncache()

  updateSize: ->
    margin = 3
    contentWidth = @label.getMeasuredWidth() + (2 * margin)
    contentHeight = @label.getMeasuredHeight() + (2 * margin)

    # Shift all contents up so marker is at pointer (affects container cache position)
    @label.regY = @background.regY = @pointMarker.regY = contentHeight

    pointMarkerStroke = 2
    pointMarkerLength = 8
    contributionsToTotalSize = []
    contributionsToTotalSize = contributionsToTotalSize.concat @updateCoordinates contentWidth, contentHeight, pointMarkerLength
    contributionsToTotalSize = contributionsToTotalSize.concat @updatePointMarker 0, contentHeight, pointMarkerLength, pointMarkerStroke

    totalWidth = contentWidth + contributionsToTotalSize.reduce (a, b) -> a + b
    totalHeight = contentHeight + contributionsToTotalSize.reduce (a, b) -> a + b

    @containerOverlay.graphics
      .clear()
      .beginFill('rgba(255,0,0,0.4)') # Actual position
      .drawRect(0, 0, totalWidth, totalHeight)
      .endFill()
      .beginFill('rgba(0,0,255,0.4)') # Cache position
      .drawRect(-pointMarkerLength, -totalHeight + pointMarkerLength, totalWidth, totalHeight)
      .endFill()

    @cache  -pointMarkerLength, -totalHeight + pointMarkerLength, totalWidth, totalHeight

  updateCoordinates: (contentWidth, contentHeight, initialXYOffset) ->
    offsetForPointMarker = initialXYOffset

    # Center label horizontally and vertically
    @label.x = contentWidth / 2 - (@label.getMeasuredWidth() / 2) + offsetForPointMarker
    @label.y = contentHeight / 2 - (@label.getMeasuredHeight() / 2) - offsetForPointMarker

    @background.graphics
      .clear()
      .beginFill('rgba(0,0,0,0.4)')
      .beginStroke('rgba(0,0,0,0.6)')
      .setStrokeStyle(backgroundStroke = 1)
      .drawRoundRect(offsetForPointMarker, -offsetForPointMarker, contentWidth, contentHeight, radius = 2.5)
      .endFill()
      .endStroke()
    contributionsToTotalSize = [offsetForPointMarker, backgroundStroke]

  updatePointMarker: (centerX, centerY, length, strokeSize) ->
    strokeStyle = 'square'
    @pointMarker.graphics
      .beginStroke('rgb(255, 255, 255)')
      .setStrokeStyle(strokeSize, strokeStyle)
      .moveTo(centerX, centerY - length)
      .lineTo(centerX, centerY + length)
      .moveTo(centerX - length, centerY)
      .lineTo(centerX + length, centerY)
      .endStroke()
    contributionsToTotalSize = [strokeSize, length]

  show: =>
    return unless @mouseInBounds and @lastPos and not @destroyed
    @label.text = "{x: #{@lastPos.x}, y: #{@lastPos.y}}"
    @updateSize()
    sup = @camera.worldToSurface @lastPos
    @x = sup.x
    @y = sup.y
    @addChild @background
    @addChild @label
    @addChild @pointMarker
    @addChild @containerOverlay  # FOR TESTING - REMOVE BEFORE COMMIT
    @updateCache()
    Backbone.Mediator.publish 'surface:coordinates-shown', {}
