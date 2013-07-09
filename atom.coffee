requestAnimationFrame = window.requestAnimationFrame or
  window.webkitRequestAnimationFrame or
  window.mozRequestAnimationFrame or
  window.oRequestAnimationFrame or
  window.msRequestAnimationFrame or
  (callback) ->
    window.setTimeout((-> callback 1000 / 60), 1000 / 60)

# TODO test this on other browsers
cancelAnimationFrame = window.cancelAnimationFrame or
  window.webkitCancelAnimationFrame or
  window.mozCancelAnimationFrame or
  window.oCancelAnimationFrame or
  window.msCancelAnimationFrame or
  window.clearTimeout

window.atom = atom = {}
atom.input = {
  _bindings: {}
  _down: {}
  _pressed: {}
  _released: []
  _gesture: []
  mouse: { x:0, y:0 }

  bind: (key, action) ->
    @_bindings[key] = action

  onkeydown: (e) ->
    action = @_bindings[eventCode e]
    return unless action

    @_pressed[action] = true unless @_down[action]
    @_down[action] = true

    e.stopPropagation()
    e.preventDefault()

  onkeyup: (e) ->
    action = @_bindings[eventCode e]
    return unless action
    @_released.push action
    e.stopPropagation()
    e.preventDefault()

  clearPressed: ->
    for action in @_released
      @_down[action] = false
    @_released = []
    @_pressed = {}

  pressed: (action) -> @_pressed[action]
  down: (action) -> @_down[action]
  released: (action) -> (action in @_released)

  onmousemove: (e) ->
    @mouse.x = e.pageX
    @mouse.y = e.pageY
  onmousedown: (e) -> @onkeydown(e)
  onmouseup: (e) -> @onkeyup(e)
  onmousewheel: (e) ->
    @onkeydown e
    @onkeyup e
  oncontextmenu: (e) ->
    if @_bindings[atom.button.RIGHT]
      e.stopPropagation()
      e.preventDefault()

  _addTouchToGesture: (e) ->
    touch = e.targetTouches[0]
    pos = { x: touch.clientX, y: touch.clientY }
    @_gesture.push pos

  ontouchstart: (e) ->
    @_gesture = []
    @_addTouchToGesture e
  ontouchmove: (e) ->
    @_addTouchToGesture e
    e.gesture = @_gesture
    @onkeydown e
    @onkeyup e
  ontouchend: (e) ->
    e.gesture = @_gesture
    @onkeydown e
    @onkeyup e
}

document.onkeydown = atom.input.onkeydown.bind(atom.input)
document.onkeyup = atom.input.onkeyup.bind(atom.input)
document.onmouseup = atom.input.onmouseup.bind(atom.input)

window.addEventListener 'touchstart', atom.input.ontouchstart.bind(atom.input)
window.addEventListener 'touchmove', atom.input.ontouchmove.bind(atom.input)
window.addEventListener 'touchend', atom.input.ontouchend.bind(atom.input)

atom.button =
  LEFT: -1
  MIDDLE: -2
  RIGHT: -3
  WHEELDOWN: -4
  WHEELUP: -5
atom.key =
  TAB: 9
  ENTER: 13
  ESC: 27
  SPACE: 32
  LEFT_ARROW: 37
  UP_ARROW: 38
  RIGHT_ARROW: 39
  DOWN_ARROW: 40
atom.touch =
  TAP: -10
  SWIPE_RIGHT: -11
  SWIPE_LEFT: -12
  SWIPE_UP: -13
  SWIPE_DOWN: -14

for c in [65..90]
  atom.key[String.fromCharCode c] = c

determineGesture = (gesture) ->
  if gesture.length is 1
    return atom.touch.TAP
  start = gesture[0]
  end = gesture[gesture.length-1]
  dx = end.x - start.x
  dy = end.y - start.y
  if Math.abs(dx) > Math.abs(dy)
    if dx > 0 then atom.touch.SWIPE_RIGHT
    else atom.touch.SWIPE_LEFT
  else
    if dy > 0 then atom.touch.SWIPE_DOWN
    else atom.touch.SWIPE_UP

eventCode = (e) ->
  if e.type == 'keydown' or e.type == 'keyup'
    e.keyCode
  else if e.type == 'mousedown' or e.type == 'mouseup'
    switch e.button
      when 0 then atom.button.LEFT
      when 1 then atom.button.MIDDLE
      when 2 then atom.button.RIGHT
  else if e.type == 'mousewheel'
    if e.wheel > 0
      atom.button.WHEELUP
    else
      atom.button.WHEELDOWN
  else if e.type == 'touchend' or e.type == 'touchmove'
    determineGesture e.gesture

atom.canvas = document.getElementsByTagName('canvas')[0]
atom.canvas.style.position = "absolute"
atom.canvas.style.top = "0"
atom.canvas.style.left = "0"
atom.context = atom.canvas.getContext '2d'

atom.canvas.onmousemove = atom.input.onmousemove.bind(atom.input)
atom.canvas.onmousedown = atom.input.onmousedown.bind(atom.input)
atom.canvas.onmouseup = atom.input.onmouseup.bind(atom.input)
atom.canvas.onmousewheel = atom.input.onmousewheel.bind(atom.input)
atom.canvas.oncontextmenu = atom.input.oncontextmenu.bind(atom.input)

# upscale the image so it always its always the desired size
atom.setDesiredSurfaceArea = (desiredSurfaceArea) ->
  atom.desiredSurfaceArea = desiredSurfaceArea
  window.onresize()

window.onresize = (e) ->
  upscale = 1
  if atom.desiredSurfaceArea
    actualSurfaceArea = window.innerHeight * window.innerWidth
    upscale = Math.sqrt atom.desiredSurfaceArea / actualSurfaceArea
  atom.canvas.width = window.innerWidth * upscale
  atom.canvas.height = window.innerHeight * upscale
  atom.canvas.style.width = window.innerWidth
  atom.canvas.style.height = window.innerHeight
  atom.width = atom.canvas.width
  atom.height = atom.canvas.height
window.onresize()

class Game
  constructor: ->
  update: (dt) ->
  draw: ->
  run: ->
    return if @running
    @running = true

    s = =>
      @step()
      @frameRequest = requestAnimationFrame s

    @last_step = Date.now()
    @frameRequest = requestAnimationFrame s
  stop: ->
    cancelAnimationFrame @frameRequest if @frameRequest
    @frameRequest = null
    @running = false
  step: ->
    now = Date.now()
    dt = (now - @last_step) / 1000
    @last_step = now
    @update dt
    @draw()
    atom.input.clearPressed()

atom.Game = Game

## Audio

# TODO: firefox support
# TODO: streaming music

atom.audioContext = new webkitAudioContext?()

atom._mixer = atom.audioContext?.createGainNode()
atom._mixer?.connect atom.audioContext.destination

atom.loadSound = (url, callback) ->
  return callback? 'No audio support' unless atom.audioContext

  request = new XMLHttpRequest()
  request.open 'GET', url, true
  request.responseType = 'arraybuffer'

  request.onload = ->
    atom.audioContext.decodeAudioData request.response, (buffer) ->
      callback? null, buffer
    , (error) ->
      callback? error

  try
    request.send()
  catch e
    callback? e.message

atom.sfx = {}
atom.preloadSounds = (sfx, cb) ->
  return cb? 'No audio support' unless atom.audioContext
  # sfx is { name: 'url' }
  toLoad = 0
  for name, url of sfx
    toLoad++
    do (name, url) ->
      atom.loadSound "sounds/#{url}", (error, buffer) ->
        console.error error if error
        atom.sfx[name] = buffer if buffer
        cb?() unless --toLoad

atom.playSound = (name, time = 0) ->
  return unless atom.sfx[name] and atom.audioContext
  source = atom.audioContext.createBufferSource()
  source.buffer = atom.sfx[name]
  source.connect atom._mixer
  source.noteOn time
  source

atom.setVolume = (v) ->
  atom._mixer?.gain.value = v
