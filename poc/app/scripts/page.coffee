document.addEventListener "DOMContentLoaded", ->
  world = new World(new Clock(0))
  world.clock.start()
  world.player.playRandom()
  window.world = world


  world.clock.on 'tick', ->
    world.trainer.brain.visSelf(document.getElementById('brain-info'));
