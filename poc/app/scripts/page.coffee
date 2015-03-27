_.templateSettings.interpolate = /{{([\s\S]+?)}}/g;

document.addEventListener "DOMContentLoaded", ->
  world = new World(new Clock(0))
  world.clock.start()
  world.player.playRandom()
  window.world = world
  history = FixedArray(20)

  historyItemTemplate = _.template """
    <b>{{ displayTime }}</b> - id: {{ track.id }}, genre: {{ track.genre }}, artist: {{ track.artist }}, title: {{ track.title }}
"""

  displayTime = (timeInMinute) ->
    hr = Math.floor(timeInMinute / 60)
    minute = timeInMinute % 60
    "#{hr}:#{minute}"

  world.clock.on 'tick', ->
    world.trainer.brain.visSelf(document.getElementById('brain-info'));

#  world.slowdown()

  document.getElementById('preferred-genres').innerText = world.user.preferredGenres.join(', ')


  _updateHistory = ->
    document.getElementById('play-history').innerHTML = _.map(history.values(), historyItemTemplate).join('<br/>')

  updateHistory = _.throttle(_updateHistory, 1000)

  world.player.on 'started-track', (track)->
    history.push {time: world.clock.currentTime, track: track, displayTime: displayTime(world.clock.realMinute()) }
    updateHistory()

