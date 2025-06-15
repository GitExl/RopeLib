enum RopeFlags : uint {
  ROPEF_LOOSE_END     = 0x0001,
  ROPEF_ALWAYS_ACTIVE = 0x0002,
  ROPEF_ANCHOR_END    = 0x0004,
  ROPEF_INTERACTIVE   = 0x0008,
  ROPEF_SETTLE_LONGER = 0x0010,
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

    //$Arg1 "Start thing"
    //$Arg1Type 14
    //$Arg1Tooltip "The TID of thing to attach the start of the rope to."

    //$Arg2 "End thing"
    //$Arg2Type 14
    //$Arg2Tooltip "The TID of thing to attach the end of the rope to."

    //$Arg3 "Flags"
    //$Arg3Type 12
    //$Arg3Enum {1 = "Loose end"; 2 = "Always active"; 4 = "Anchor end to rope"; 8 = "Interactive"; 16 = "Settle longer";}

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

  // Particle actors.
  Array<RopeParticleBase> particles;

  // Desired spacing between particles. The simulation will push particles apart to try to reach this.
  double desiredParticleSpacing;

  // Wind vector normally set from a RopeWindController actor.
  Vector3 wind;

  // If true this rope is not being simulated.
  bool isDormant;

  // How long to wait before updating the dormant state again.
  int dormantCounter;

  // The distance in map units between the rope and a camera, beyond which ropes go dormant. Squared.
  int dormantDistanceSq;

  // How many Jakobsen iteration to run during the rope simulation.
  int iterationCount;

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

    // Determine iteration count from CVar.
    iterationCount = max(1, min(50, CVar.GetCVar("rope_jakobsen_iterations").GetInt()));

    // Determine mesh quality to use.
    int meshQuality = max(0, min(2, CVar.GetCVar("rope_mesh_quality").GetInt()));
    statelabel particleState = "Low";
    if (meshQuality == 1) {
      particleState = "Medium";
    } else if (meshQuality == 2) {
      particleState = "High";
    }

    // Calculate squared dormant distance from CVar.
    dormantDistanceSq = max(128, min(8192, CVar.GetCVar("rope_dormant_distance").GetInt()));
    dormantDistanceSq = dormantDistanceSq * dormantDistanceSq;

    // Toggle between interactive or regular rope particles.
    name particleClass = "RopeParticle";
    if (args[3] & ROPEF_INTERACTIVE) {
      particleClass = "RopeParticleInteractive";
    }

    // Calculate rope length modifier based on desired stiffness.
    double stiffness = Double(-args[4]) / 100.0;
    double ropeLengthModifier = 1.0 + stiffness;

    // Calculate the desired particle count and spacing.
    double ropeLength = Level.Vec3Diff(end.pos, start.pos).Length() * ropeLengthModifier;
    int particleDivider = ceil(256.0 / CVar.GetCVar("rope_particle_density").GetInt());
    int particleCount = 2 + ceil(ropeLength / particleDivider);
    desiredParticleSpacing = ropeLength / (particleCount - 1);

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
      p.SetState(p.FindState(particleState));

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

    // Track initial dormancy state.
    isDormant = false;
    dormantCounter = random(1, 100);

    Settle();
  }

  override void Tick() {

    // Go to sleep if there is no camera nearby.
    if (!(args[3] & ROPEF_ALWAYS_ACTIVE) && !dormantCounter--) {
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
      dormantCounter = 20;
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

  void Settle() {

    // Simulate the rope for a number of ticks to settle it into a stable position.
    int iterations = (args[3] & ROPEF_SETTLE_LONGER) ? CVar.GetCVar("rope_settle_longer_ticks").GetInt() : CVar.GetCVar("rope_settle_ticks").GetInt();
    while (iterations--) {
      Simulate();
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
    for (int i = 0; i < iterationCount; i++) {
      for (int j = 0; j < particles.Size() - 1; j++) {
        RopeParticleBase p1 = particles[j];
        RopeParticleBase p2 = particles[j + 1];

        // Calculate current spacing between the two particles.
        currentSpacing = Level.Vec3Diff(p1.nextPos, p2.nextPos).Length();

        // Get the normalized difference between the desired spacing and current spacing.
        // Use that to calculate how far to move the particles together or apart.
        difference = (desiredParticleSpacing - currentSpacing) / currentSpacing;
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

    // Update particle positions.
    foreach (p : particles) {
      p.SetXYZ(p.nextPos);
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

  bool IsCameraNearby() {
    foreach (p : players) {
      if (!p.Camera) {
        continue;
      }

      // Test the first and last rope particle.
      if (p.Camera.Distance3DSquared(particles[0]) < dormantDistanceSq) {
        return true;
      }
      if (p.Camera.Distance3DSquared(particles[particles.Size() - 1]) < dormantDistanceSq) {
        return true;
      }
    }

    return false;
  }
}
