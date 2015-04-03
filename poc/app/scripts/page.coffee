_.templateSettings.interpolate = /{{([\s\S]+?)}}/g;

$ = (id) -> document.getElementById id

document.addEventListener "DOMContentLoaded", ->
  world = new World(new Clock(500))
  world.clock.start()
  window.world = world
  history = FixedArray(500)
  actionHistory = FixedArray(50)

  historyItemTemplate = _.template """
    <b>{{ displayTime }}</b> - during: {{context}} track - id: {{ track.id }}, genre: {{ track.genre }}, artist: {{ track.artist }}, title: {{ track.title }}
"""

  displayTime = (timeInMinute) ->
    hr = Math.floor(timeInMinute / 60)
    minute = timeInMinute % 60
    "#{hr}:#{minute}"

  _updateBrianInfo = -> world.trainer.brain.visSelf($('brain-info'));

  world.clock.on 'tick', =>
    _.throttle(_updateBrianInfo, 300)()
    updateHistory()

  $('user-activities').innerHTML = (
      for activity in world.user.activities
        "<li><b>#{activity.name}</b> preferred genres:  #{activity.preferredGenres.join(', ')}</li>"
    ).join('\n')

  for event in ['thumb-up','thumb-down','skip']
    callback = (e) -> (track) ->
      actionHistory.push {action: e, track: track, context: world.user.currentActivity?.name }
    world.player.on event, callback(event)

  _updateHistory = ->

    $('play-history').innerHTML = _.map(history.values(), historyItemTemplate).join('<br/>')
    $('user-feedback-history').innerHTML = (for feedback in actionHistory.values()
      "<li><b>#{feedback.action}</b> track-genre: #{ feedback.track.genre } when: #{feedback.context}</li>"
    ).join('\n')
    $('current-time').innerHTML = "Day-#{world.clock.time.day}  #{world.clock.time.hour}:#{world.clock.time.minute} "
    $('current-activity').innerHTML = world.user.currentActivity?.name or "App turned off"

  updateHistory = _.throttle(_updateHistory, 1000)

  world.player.on 'started-track', (track)->
    history.push {time: world.clock.now, track: track, displayTime: world.clock.time.display(), context: world.user.currentActivity?.name }


