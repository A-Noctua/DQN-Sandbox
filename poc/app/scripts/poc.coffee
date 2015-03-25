class WithEvents
  constructor: ->
    _.assign(this, Backbone.Events)

class WithSimulation extends WithEvents
  constructor: (@clock) -> super()

  byChance: (chance, f) ->
    if _.random(1, true) <= chance
      f()

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
    @trainer = new Trainer(@player)
    @user = new User(clock, @player)


class Trainer
  constructor: (@player, @brainOpts = {}) ->
    nextByGenres = ( {name: 'next-genre', genre: g} for g in Repo.genres )
    @actions = [
      { name: 'next-random'}
      { name: 'next-preferred'}
    ].concat nextByGenres

    @pendingReward = false
    @currentReward = 0
    @brain = new deepqlearn.Brain(@state.length, @actions.length)
    @registerRewards()
    @player.on('before-play-next', @nextAction)
    @player.on('turned-off', @reportReward)


  nextAction: =>
    @reportReward()
    @executeAction()

  reportReward: =>
    if @pendingReward
      console.log "reporting reward", @currentReward
      @brain.backward(@currentReward)
      @pendingReward = false

  executeAction: =>
    actionIndex = @brain.forward(@state())
    console.log "sending command", @actions[actionIndex]
    @player.sendCommand(@actions[actionIndex])

    @currentReward = 0
    @pendingReward = true

  state: =>
    track = @player.playingTrack
    [
      track.artistId
      track.genreId
      @player.preferenceFor(track)
      @player.location.lat
      @player.location.lon
      @player.clock.realMinute()
    ]

  registerRewards: =>
    rewardsMap = {
      'thumb-up' :  100
      'thumb-down' : -100
      'skip' : -100
      'played-a-tick': 1
      'turned-off': -20
    }
    for event, reward of rewardsMap
      handler = (e,r) => =>
        @currentReward += r

      @player.on event, handler(event, reward)


class User extends WithSimulation
  constructor:(clock, @player) ->
    super(clock)
    @player.on 'played-a-tick', @reactToPlayingTrack

  reactToPlayingTrack: (track) =>
    if _.includes(@player.preferredGenres, track.genre)
      @byChance 0.6, @player.thumbUp
    else
      @byChance 0.2, @player.thumbDown


class Player extends WithSimulation
  state: 'off'

  nextStrategy: {name: 'random'}

  constructor: (clock, @repo) ->
    super(clock)
    @preferredGenres = _.sample(Repo.genres, 3)
    @clock.on 'tick', =>
      if @playingTrack?
        @trigger('played-a-tick', @playingTrack)


  play: (track) =>
    console.log "playing", track
    @turnOn() #it's implicit turn on action
    @playingTrack = track
    @scheduleAfter track.length, =>
      if(@playingTrack is track)
        @next()

  sendCommand: (cmd) =>
    if _.startsWith(cmd.name, 'next-')
      @nextStrategy = _.merge({}, cmd, name: cmd.name.replace('next-', ''))

  trackPreference: {}

  thumbUp: =>
    @trackPreference[@playingTrack.id] = 1
    @trigger('thumb-up')

  thumbDown: =>
    @trackPreference[@playingTrack.id] = -1
    @trigger('thumb-down')

  preferenceFor: (track) => @trackPreference[track.id] or 0

  playRandom: => @play @repo.nextRandom()

  playGenre: (genre) => @play @repo.nextInGenre(genre)

  playPreferredGenre: => @playGenre  _.sample(@preferredGenres)

  next: =>
    @trigger('before-play-next')
    switch @nextStrategy.name
      when 'random' then @playRandom()
      when 'preferred' then @playRandom()
      when 'genre'
        @playGenre(@nextStrategy.genre)
      else
        @playingTrack = null

  location: {lat: 30.011, lon: 34.322}

  sessionLength: =>
    if( @state is 'on')
      @clock.currentTime - @sessionStart

  turnOn: =>
    if @state isnt 'on'
      @state = 'on'
      @sessionStart = @clock.currentTime
      @trigger("turned-on")

  skip: =>
    @playingTrack = null
    @trigger("skip")
    @next()

  turnOff: =>
    if @state isnt 'off'
      @playingTrack = null
      @state = 'off'
      @trigger("turned-off")


class Clock extends WithEvents
  # start at 6Am in the morning
  constructor: (@msPerTick = 1000, @currentTime = 5 * 60) -> super()

  _intervalId: null

  realMinute: => @currentTime % (24 * 60)
  tick: =>
    @currentTime += 1
    @trigger("tick", @currentTime)

  start: => @_intervalId ?= setInterval(@tick, @msPerTick)
  stop: =>
    if @_intervalId?
      clearInterval @_intervalId
      @_intervalId = null



class Track
  constructor: ({@id, @title, @artist, @genre, @length}) ->
    @artistId  = randomArtists.indexOf(@artist)
    @genreId  = Repo.genres.indexOf(@genre)


class Repo
  constructor: ->
    @tracks = _.times(1000, @randomTrack)

  @genres: ['Hip Pop', 'Hard Rock', 'Alternative', 'Jazz', 'Dance', 'Rap', 'Classical', 'Comedy']

  randomTrack: (id)->
    new Track(
      id     : id
      title  : _.capitalize(_.sample(randomWords, _.random(1, 10)).join(' '))
      artist : _.sample(randomArtists)
      genre  : _.sample(Repo.genres)
      length : _.random(1, 4)
    )

  nextRandom: => _.sample @tracks

  nextInGenre: (genre) => _.sample _.where(@tracks, genre: genre)



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
