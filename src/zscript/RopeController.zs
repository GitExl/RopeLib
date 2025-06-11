const ROPE_ITERATIONS = 6;

enum RopeFlags : uint {
  ROPEF_LOOSE_END      = 0x0001,
  ROPEF_ALWAYS_ACTIVE  = 0x0002,
  ROPEF_ANCHOR_END     = 0x0004,
  ROPEF_INTERACTIVE    = 0x0008,
}

class RopeController : Actor {
  default {
    //$Title "Rope controller"
    //$Sprite "ROPEB0"
    //$Icon "ROPEB0"
    //$Color 15
    //$Category "Ropes"
    //$IgnoreRenderstyle
    //$NotAngled

    //$Arg0 "Segments"
    //$Arg0Type 11
    //$Arg0Enum {0 = "7 segments"; 1 = "15 segments"; 2 = "23 segments"; 3 = "31 segments";}
    //$Arg0Tooltip "The number of segments of the rope. More segments look better but perform worse."

    //$Arg1 "Start thing"
    //$Arg1Type 14
    //$Arg1Tooltip "The TID of thing to attach the start of the rope to."

    //$Arg2 "End thing"
    //$Arg2Type 14
    //$Arg2Tooltip "The TID of thing to attach the end of the rope to."

    //$Arg3 "Flags"
    //$Arg3Type 12
    //$Arg3Enum {1 = "Loose end"; 2 = "Always active"; 4 = "Anchor end to rope"; 8 = "Interactive";}

    //$Arg4 "Stiffness"
    //$Arg4Type 0
    //$Arg4Tooltip "Rope stiffness, in percentage points. Negative values loosen the rope, positive values stiffen it."

    radius 16;
    height 16;
    mass 0;
    renderstyle "STYLE_None";
    scale 1.0;

    +NOBLOCKMAP
    +NOLIFTDROP
    +NOTRIGGER
    +NOFRICTION
    +NONSHOOTABLE
    +NOCLIP
    +DONTSPLASH
    +NOSPRITESHADOW
    +NOINTERACTION
  }

  states {
    Spawn:
      TNT1 A -1;
      stop;
  }

  Array<RopeParticleBase> particles;
  double desiredSpacing;
  Vector3 wind;
  Vector3 bbox1;
  Vector3 bbox2;
  Vector3 ropeSleepDistance;
  bool isDormant;
  int dormantCounter;

  override void PostBeginPlay() {
    super.PostBeginPlay();

    Actor start = Level.CreateActorIterator(args[1]).Next();
    if (!start) {
      console.printf("No start spot for rope controller at %d, %d, %d.", pos.x, pos.y, pos.z);
      return;
    }

    Actor end = Level.CreateActorIterator(args[2]).Next();
    if (!end) {
      console.printf("No end spot for rope controller at %d, %d, %d.", pos.x, pos.y, pos.z);
      return;
    }

    // Toggle between interactive or regular rope particles.
    name particleClass = "RopeParticle";
    if (args[3] & ROPEF_INTERACTIVE) {
      particleClass = "RopeParticleInteractive";
    }

    // Spawn particle actors.
    int particleCount = 8 + args[0] * 8;
    for (int i = 0; i < particleCount; i++) {
      double w = Double(i) / (particleCount - 1);

      Vector3 destPos = (
        w * end.pos.x + (1 - w) * start.pos.x,
        w * end.pos.y + (1 - w) * start.pos.y,
        w * end.pos.z + (1 - w) * start.pos.z
      );

      // Spawn the particle. The first and last particles are never interactive so that the
      // rope can be placed near surfaces.
      RopeParticleBase p;
      if (i == 0 || (i == particleCount - 1 && !(args[3] & ROPEF_LOOSE_END))) {
        p = RopeParticleBase(Spawn("RopeParticle", destPos));
      }
      else {
        p = RopeParticleBase(Spawn(particleClass, destPos));
      }

      p.prevPos = p.nextPos = destPos;
      p.scale = scale;
      p.alpha = alpha;
      p.SetShade(fillcolor);

      particles.push(p);
    }

    // Attach rope to start and end actors.
    particles[0].attachTo = start;
    if (!(args[3] & ROPEF_LOOSE_END)) {
      particles[particleCount - 1].attachTo = end;
    }

    // Anchor an actor to the end particle.
    if (args[3] & ROPEF_ANCHOR_END) {
      particles[particleCount - 1].anchorTo = end;
    }
    particles[particleCount - 1].A_SetRenderStyle(1.0, STYLE_None);

    // Calculate rope length modifier based on desired stiffness.
    double stiffness = Double(-args[4]) / 100.0;
    double ropeLengthModifier = 1.0 + stiffness;

    // Calculate the desired particle spacing.
    double ropeLength = Level.Vec3Diff(end.pos, start.pos).Length() * ropeLengthModifier;
    desiredSpacing = ropeLength / (particleCount - 1);

    // Track initial dormancy state.
    ropeSleepDistance = (768, 768, -768);
    UpdateBBox();
    isDormant = false;
    dormantCounter = random(1, 50);
  }

  override void Tick() {

    // Go to sleep if there is no camera nearby.
    if (!(args[3] & ROPEF_ALWAYS_ACTIVE) && !dormantCounter--) {
      UpdateBBox();
      bool shouldBeDormant = !IsCameraNearby();
      if (shouldBeDormant != isDormant) {
        isDormant = shouldBeDormant;

        // Hide shootable particle types.
        foreach (p : particles) {
          if (p.bSHOOTABLE) {
            p.bNOINTERACTION = isDormant;
            p.A_ChangeLinkFlags(isDormant ? 1 : 0);
          }
        }
      }
      dormantCounter = 15;
    }

    if (!isDormant) {
      Simulate();
    }

    // Anchor actors to particles.
    foreach (p : particles) {
      if (!p.anchorTo) {
        continue;
      }
      p.anchorTo.SetOrigin(p.nextPos - (0, 0, p.anchorTo.height), true);
      p.anchorTo.vel = (0, 0, 0);
    }

    if (!isDormant) {
      UpdateModels();
    }
  }

  void Simulate() {

    // Combine wind and gravity forces. Gravity is normalized to a timestep value.
    double timestep = 1.0 / double(TICRATE);
    Vector3 forces = wind + (0, 0, -GetGravity() * (800 / 35.0) * timestep);

    // Verlet integration.
    foreach (p : particles) {
      if (p.attachTo) {
        p.nextPos = p.prevPos = p.attachTo.pos;
        continue;
      }

      // Get current position from the actor, in case it was moved since the last tick.
      p.nextPos = p.pos;

      // Store current position to use as previous position after integration.
      Vector3 posCopy = p.nextPos;

      // Integrate over previous position and add external forces.
      // Adding in the particle actor velocity ensures it can be affected by explosions and gunshots.
      // The particle actor velocity is reset at the end of the tick.
      p.nextPos += (p.nextPos - p.prevPos) + p.vel + forces;

      p.prevPos = posCopy;
    }

    // Enforce constraints between particles.
    double currentSpacing;
    double difference;
    for (int i = 0; i < ROPE_ITERATIONS; i++) {
      for (int j = 0; j < particles.Size() - 1; j++) {
        RopeParticleBase p1 = particles[j];
        RopeParticleBase p2 = particles[j + 1];

        // Calculate current spacing between the two particles.
        currentSpacing = Level.Vec3Diff(p1.nextPos, p2.nextPos).Length();

        // Get the normalized difference between the desired spacing and current spacing.
        // Use that to calculate how far to move the particles together or apart.
        difference = (desiredSpacing - currentSpacing) / currentSpacing;
        Vector3 delta = p1.nextPos - p2.nextPos;
        delta *= difference;

        // Update particle positions.
        if (!p1.attachTo && !p2.attachTo) {
          delta *= 0.5;
          p1.nextPos += delta;
          p2.nextPos -= delta;
        } else if (p1.attachTo && !p2.attachTo) {
          p2.nextPos -= delta;
        } else if (p2.attachTo && !p1.attachTo) {
          p1.nextPos += delta;
        }
      }
    }

    // Update particle actor positions.
    foreach (p : particles) {
      p.SetOrigin(p.nextPos, true);
      p.vel = (0, 0, 0);
    }
  }

  void UpdateModels() {

    // Orient and scale the particle models to make them look like a rope.
    RopeParticleBase p1;
    RopeParticleBase p2;
    double segmentLength;
    for (int j = 0; j < particles.Size() - 1; j++) {
      p1 = particles[j];
      p2 = particles[j + 1];

      // todo: limit angle and pitch changes to prevent euler wrapping issues?
      segmentLength = Level.Vec3Diff(p2.pos, p1.pos).Length();
      p1.A_SetAngle(p1.AngleTo(p2, true), SPF_INTERPOLATE);
      p1.A_SetPitch(p1.PitchTo(p2, 0, 0, true) - 90.0, SPF_INTERPOLATE);
      p1.scale.y = segmentLength;
    }
  }

  void UpdateBBox() {
    bbox1 = bbox2 = particles[particles.Size() / 2].pos;

    foreach (p : particles) {
      bbox1.x = min(bbox1.x, p.pos.x);
      bbox1.y = min(bbox1.y, p.pos.y);
      bbox1.z = max(bbox1.y, p.pos.z);
      bbox2.x = max(bbox2.x, p.pos.x);
      bbox2.y = max(bbox2.y, p.pos.y);
      bbox2.z = min(bbox2.z, p.pos.z);
    }

    bbox1 -= ropeSleepDistance;
    bbox2 += ropeSleepDistance;
  }

  bool IsCameraNearby() {

    // Check for any remote camera for the consoleplayer.
    if (players[consoleplayer].camera != players[consoleplayer].mo) {
      Vector3 cam = players[consoleplayer].camera.pos;
      if (cam.x < bbox1.x || cam.y < bbox1.y || cam.z < bbox1.z || cam.x > bbox2.x || cam.y > bbox2.y || cam.z > bbox2.z) {
        return false;
      }
    }

    // Regular distance check.
    else {
      Vector3 size = bbox2 - bbox1;
      Vector3 center = bbox1 + (size / 2);
      BlockThingsIterator it = BlockThingsIterator.CreateFromPos(center.x, center.y, center.z, 0.0, max(size.x, size.y, size.z), false);
      while (it.Next()) {
        if (it.thing is "PlayerPawn") {
          return true;
        }
      }
    }

    return false;
  }
}
