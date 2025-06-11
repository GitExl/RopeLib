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
    +INTERPOLATEANGLES
  }

  states {
    Spawn:
      ROPE A -1;
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
    mass 50;
    radius 16;
    height 4;
    health 666;

    +SHOOTABLE
    +BUDDHA
  }
}
