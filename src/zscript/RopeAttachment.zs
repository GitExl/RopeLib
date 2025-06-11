class RopeAttachment : Actor {
  default {
    //$Title "Rope attachment point"
    //$Sprite "ROPED0"
    //$Icon "ROPED0"
    //$Color 15
    //$Category "Ropes"
    //$IgnoreRenderstyle

    mass 1;
    radius 1;
    height 1;
    renderstyle "None";

    +NOINTERACTION
  }

  states {
    Spawn:
      TNT1 A -1;
      stop;
  }
}
