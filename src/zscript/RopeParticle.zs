class RopeParticleBase : Actor abstract {
  Vector3 nextPos;
  Vector3 prevPos;
  Actor attachTo;
  Actor anchorTo;

  default {
    mass 1;
    radius 1;
    height 1;
    renderstyle "Stencil";

    +FORCEXYBILLBOARD
    +NOGRAVITY
    +NOSPRITESHADOW
    +NOLIFTDROP
    +NOTRIGGER
    +NOBLOOD
    +NOTELEPORT
    +NEVERTARGET
    +MINVISIBLE
    +MVISBLOCKED
    +THRUSPECIES
    +NOBLOCKMONST
    +NOFRICTION
    +DONTSPLASH
    +NOTAUTOAIMED
    +NOPAIN
    +INTERPOLATEANGLES
  }

  states {
    Low:
    Spawn:
      ROPE E -1;
      stop;
    Medium:
      ROPE F -1;
      stop;
    High:
      ROPE G -1;
      stop;
  }
}

class RopeParticle : RopeParticleBase {
  default {
    +NOINTERACTION
  }
}

class RopeParticleInteractive : RopeParticleBase {
  default {
    mass 75;
    radius 16;
    height 8;
    health 666;
    damagefactor 2;
    radiusdamagefactor 0.5;

    +SHOOTABLE
    +BUDDHA
  }
}
