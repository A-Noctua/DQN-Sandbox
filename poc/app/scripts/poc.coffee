class WithEvents
  constructor: ->
    _.assign(this, Backbone.Events)

class WithSimulation extends WithEvents
  constructor: (@clock) -> super()

  scheduleAt: (at, work) =>
    if !(at > @clock.currentTime)
      console.error("can't schedule at " + at)
    else
      callback = (time) =>
        if at is time
          work()
          @clock.off 'tick', callback
      @clock.on 'tick', callback

  scheduleAfter: (after, work) =>
    @scheduleAt @clock.currentTime + after, work




class window.World extends WithSimulation
  constructor:  (clock = new Clock)->
    super(clock)
    @player = new Player(clock, new Repo)

class User
  constructor:(clock, @player) ->
    super(clock)



class Player extends WithSimulation
  state: 'off'

  constructor: (clock, @repo) -> super(clock)

  lastStart: undefined

  play: (track) =>
    console.log "playing", track
    @lastStart = @clock.currentTime
    @playingTrack = track

  playRandom: =>
    t = @repo.nextRandom()
    @play t
    @scheduleAfter(t.length, @playRandom)

  location: [30.011, 34.322]

  turnOn: =>
    if @state isnt 'on'
      @state = 'on'
      @trigger("turned-on")

  turnOff: =>
    if @state isnt 'off'
      @state = 'off'
      @trigger("turned-off")


class Clock extends WithEvents
  constructor: (@msPerTick = 1000) -> super()

  currentTime: 0
  _intervalId: null

  tick: =>
    if (@currentTime % 10) is 0
      console.log "alive"
    @currentTime += 1
    @trigger("tick", @currentTime)

  start: => @_intervalId ?= setInterval(@tick, @msPerTick)
  stop: =>
    if @_intervalId?
      clearInterval @_intervalId
      @_intervalId = null



class Track
  constructor: ({@id, @title, @artist, @genre, @length}) ->

class Repo
  constructor: ->
    @tracks = _.times(1000, @randomTrack)

  randomTrack: (id)->
    new Track(
      id     : id
      title  : _.capitalize(_.sample(randomWords, _.random(1, 10)).join(' '))
      artist : _.sample(randomArtists)
      genre  : _.sample(genres)
      length : _.random(1, 4)
    )

  nextRandom: => @tracks[_.random(@tracks.length - 1)]

genres = ['Hip Pop', 'Hard Rock', 'Alternative', 'Jazz', 'Dance', 'Rap', 'Classical', 'Comedy']
randomArtists = ['Kai', 'Marcel', 'Laruent', 'Vipan', 'Amit', 'Tom', 'Matt', 'Adam', 'Josh', 'Trey', 'Lasse' ]

billyJoe = """Woah, oh, oh
For the longest time
Woah, oh, oh
For the longest
If you said goodbye to me tonight
There would still be music left to write
What else could I do
I'm so inspired by you
That hasn't happened for the longest time

Once I thought my innocence was gone
Now I know that happiness goes on
That's where you found me
When you put your arms around me
I haven't been there for the longest time

Woah, oh, oh
For the longest time
Woah, oh, oh
For the longest
I'm that voice you're hearing in the hall
And the greatest miracle of all
Is how I need you
And how you needed me too
That hasn't happened for the longest time

Maybe this won't last very long
But you feel so right
And I could be wrong
Maybe I've been hoping too hard
But I've gone this far
And it's more than I hoped for

Who knows how much further we'll go on
Maybe I'll be sorry when you're gone
I'll take my chances
I forgot how nice romance is
I haven't been there for the longest time
I had second thoughts at the start
I said to myself
Hold on to your heart
Now I know the woman that you are
You're wonderful so far
And it's more than I hoped for

I don't care what consequence it brings
I have been a fool for lesser things
I want you so bad
I think you ought to know that
I intend to hold you for
The longest time
"""
randomWords = _.words(billyJoe)
