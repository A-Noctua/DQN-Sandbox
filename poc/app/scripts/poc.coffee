class World extends Backbone.Events
  constructor:  ->
    @clock = new Clock()
    @player = new Player(@clock, new Repo)


class User
  constructor:( @player, @clock) ->

class Player extends Backbone.Events
  state: 'off'

  constructor: (@clock, @repo) ->
    @clock.on 'tick', @tick

  lastStart: undefined

  tick: ->


  play: (track) =>
    @lastStart = @clock.currentTime
    @playingTrack = track


  location: [30.011, 34.322]

  turnOn: =>
    if @state isnt 'on'
      @state = 'on'
      @trigger("turned-on")

  turnOff: =>
    if @state isnt 'off'
      @state = 'off'
      @trigger("turned-off")


class Clock extends Backbone.Events
  currentTime: 0
  tick: =>
    @currentTime += 1
    @trigger("tick", @currentTime)


class Track
  constructor: (@title, @aritst, @genre) ->


class Repo
  tracks: [new Track("You are a joke.", "John", "rock"), new Track("Love you forever!", "Cassy", "pop")]

  nextRandom: => @tracks[_.random(@tracks.length - 1)]

