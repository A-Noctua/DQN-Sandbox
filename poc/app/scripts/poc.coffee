log = (msg) =>
#  console.log msg

class WithEvents
  constructor: ->
    _.assign(this, Backbone.Events)

class WithSimulation extends WithEvents
  constructor: (@clock) -> super()

  byChance: (chance, f) ->
    if _.random(1, true) <= chance
      f()

  scheduleAt: (at, work) =>
    if !(at > @clock.time.absoluteMinute)
      console.error("can't schedule at " + at)
    else
      eventName = 'tick-' + at
      @clock.once eventName, work

  scheduleAfter: (after, work) =>
    @scheduleAt @clock.time.absoluteMinute + after, work

  scheduleDaily: (time, work) =>
    log time
    @clock.on 'tick', (t) =>
      if t.hour is time.hour and t.minute is time.minute
        work()



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
#      { name: 'next-preferred'}
    ].concat nextByGenres

    @pendingReward = false
    @currentReward = 0
    @brain = new deepqlearn.Brain(@state().length, @actions.length, temporal_window: 10)
    @registerRewards()
    @player.on('before-play-next', @nextAction)
    @player.on('turned-off', @reportReward)


  nextAction: =>
    @reportReward()
    @executeAction()

  reportReward: =>
    if @pendingReward
      log "reporting reward", @currentReward
      @brain.backward(@currentReward)
      @pendingReward = false

  executeAction: =>
    state = @state()
    log "reporting state", state
    actionIndex = @brain.forward(state)
    log "sending command", @actions[actionIndex]
    @player.sendCommand(@actions[actionIndex])

    @currentReward = 0
    @pendingReward = true

  state: =>
    track = @player.playingTrack or Track.empty()
    [
      track.artistId / 20.0
      track.genreId / 30.0
      @player.preferenceFor(track)
      @player.location.lat / 100.0
      @player.location.lon / 100.0
      @player.clock.time.minuteOfDay / (24 * 60)
    ]

  registerRewards: =>
    rewardsMap = {
      'thumb-up' :  0.8
      'thumb-down' : -0.8
      'skip' : -0.4
      'played-a-tick': 0.002
      'turned-off': 0
    }
    for event, reward of rewardsMap
      handler = (e,r) => =>
        @currentReward += r

      @player.on event, handler(event, reward)


class User extends WithSimulation
  constructor:(clock, @player) ->
    super(clock)
    @player.on 'started-track', @reactToPlayingTrack
    @history = FixedArray(10)
    @currentActivity = new ActivityWithPreferredGenres(this, _.sample(Repo.genres, 4))
    @scheduleDaily(Time.fromHour(6, 30), => @player.playRandom() )
    @scheduleDaily(Time.fromHour(8, 30),  => @player.turnOff() )


  reactToPlayingTrack: (track) =>
    @history.push(track)
    @currentActivity.respondToTrack(track)

class ActivityWithPreferredGenres extends WithSimulation

  constructor: (@user, @preferredGenres) ->
    super(@user.clock)

  respondToTrack: (track) =>
    if _.includes(@preferredGenres, track.genre)
      chance = (6 - _.where(@user.history.values(), genre: track.genre).length ) / 20
      if chance > 0
        @byChance chance, @user.player.thumbUp
    else
      @byChance 0.2, @user.player.thumbDown
      @byChance 0.5, @user.player.skip



class Player extends WithSimulation
  state: 'off'

  nextStrategy: {name: 'random'}

  constructor: (clock, @repo) ->
    super(clock)
    @clock.on 'tick', =>
      if @playingTrack?
        @trigger('played-a-tick', @playingTrack)


  play: (track) =>
    log "playing", track
    @turnOn() #it's implicit turn on action
    @playingTrack = track
    @trigger('started-track', track)
    @scheduleAfter track.length, =>
      if(@playingTrack is track)
        @trigger('finished-track', track)
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


  turnOn: =>
    if @state isnt 'on'
      @state = 'on'
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

class Time
  constructor: (@absoluteMinute) ->
    @minute = @absoluteMinute % 60
    @day =  Math.floor(@absoluteMinute / (24 * 60))
    @hour = Math.floor(@absoluteMinute % (24 * 60) / 60)
    @minuteOfDay = @hour * 60 + @minute

  tick: => new Time(@absoluteMinute + 1)

  display: => "Day-#{@day} #{@hour}:#{@minute}"

  @fromHour: (hour, minute, day = 0) ->
    new Time(minute + 60 * (hour + 24 * day) )

class window.Clock extends WithEvents
  # start at 6Am in the morning
  constructor: (@msPerTick = 1000, startMinute = 5 * 60) ->
    @time = new Time(startMinute)
    super()

  setNewSpeed: (msPerTick) ->
    @stop()
    @msPerTick = msPerTick
    @start()

  _intervalId: null

  realMinute: => @time % (24 * 60) #minute of the day

  hour: => @time.hour
  minute: => @time.minute
  day: => @time.day

  tick: =>
    @time = @time.tick()
    @trigger("tick", @time)
    @trigger("tick-" + @time.absoluteMinute)

  multipleTicks: =>
    if @msPerTick is 0
      for i in [0..100]
        @tick()
    else @tick()


  start: => @_intervalId ?= setInterval(@multipleTicks, @msPerTick)
  stop: =>
    if @_intervalId?
      clearInterval @_intervalId
      @_intervalId = null


class Track
  @empty: => new Track(id: 0, title: "", length: 0)

  constructor: ({@id, @title, @artist, @genre, @length}) ->
    @artistId  = Repo.randomArtists.indexOf(@artist)
    @genreId  = Repo.genres.indexOf(@genre)


class Repo
  constructor: ->
    @tracks = _.times(1000, @randomTrack)

  @genres: ['Hip Pop', 'Hard Rock', 'Alternative', 'Jazz', 'Dance', 'Rap', 'Classical', 'Comedy']
  @randomArtists: ['Kai', 'Marcel', 'Laruent', 'Vipan', 'Amit', 'Tom', 'Matt', 'Adam', 'Josh', 'Trey', 'Lasse' ]
  randomTrack: (id)->
    new Track(
      id     : id
      title  : _.capitalize(_.sample(randomWords, _.random(1, 10)).join(' '))
      artist : _.sample(Repo.randomArtists)
      genre  : _.sample(Repo.genres)
      length : _.random(2, 5)
    )

  nextRandom: => _.sample @tracks

  nextInGenre: (genre) => _.sample _.where(@tracks, genre: genre)





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
