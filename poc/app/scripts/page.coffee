_.templateSettings.interpolate = /{{([\s\S]+?)}}/g;

$ = (id) -> document.getElementById id

document.addEventListener "DOMContentLoaded", ->
  world = new World(new Clock(500))
  world.clock.start()
  window.world = world
  history = FixedArray(100)

  historyItemTemplate = _.template """
    <b>{{ displayTime }}</b> - id: {{ track.id }}, genre: {{ track.genre }}, artist: {{ track.artist }}, title: {{ track.title }}
"""

  displayTime = (timeInMinute) ->
    hr = Math.floor(timeInMinute / 60)
    minute = timeInMinute % 60
    "#{hr}:#{minute}"

  _updateBrianInfo = -> world.trainer.brain.visSelf($('brain-info'));

  world.clock.on 'tick', =>
    _.throttle(_updateBrianInfo, 300)()
    updateHistory()


  $('preferred-genres').innerText = world.user.currentActivity.preferredGenres.join(', ')

  _updateHistory = ->
    $('play-history').innerHTML = _.map(history.values(), historyItemTemplate).join('<br/>')
    $('current-time').innerHTML = "Day-#{world.clock.time.day}  #{world.clock.time.hour}:#{world.clock.time.minute} "

  updateHistory = _.throttle(_updateHistory, 1000)

  world.player.on 'started-track', (track)->
    history.push {time: world.clock.now, track: track, displayTime: world.clock.time.display() }


