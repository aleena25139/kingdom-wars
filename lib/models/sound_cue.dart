// Every in-battle sound the engine can ask for. BattleEngine only pushes
// these onto its soundQueue (it knows nothing about audio); KingdomWarsGame
// drains the queue each frame and hands each cue to SoundService, which
// decides the actual file, volume, throttling and music-ducking.
enum SoundCue {
  // --- Your army ---
  arrowShot, // Archer
  swordClash, // Knight (and Storm Knight)
  mageZap, // Mage / Magician
  fireWhoosh, // Dragon / Phoenix / Elf Prince flames
  dragonRoar, // Dragon
  phoenixCry, // Phoenix
  pandaRoar, // Panda Warrior battle cry
  pandaHit, // Panda Warrior strike
  healChime, // Magician heal pulse
  deployHorn, // reinforcement arrives

  // --- Enemies ---
  skeletonRattle,
  goblinCackle, // goblin appears
  goblinHit, // goblin strikes
  lizardRoar, // Lizard appears / dies
  lizardBite, // Lizard strikes
  monsterGrowl, // Monster appears / strikes / dies
  titanRoar, // Thunder Titan
  houndBark, // Ember Hound

  // --- General battle ---
  hitThud,
  explosion,
  thunder,
}
