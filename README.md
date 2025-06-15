# RopeLib

A small ZScript library for verlet-based rope simulation for GZDoom.

## Contents

`/src` contains all the ZScript, models, sprites and other things needed for the ropes to work.

`demo.wad` is a small demo level that must be loaded with the data from `src` or the library PK3.

## Usage

Add a Rope controller actor to your map. Tag it to two other actors to create a rope between them. These can be any
actors, but because of Doom physics reasons it is best to use the provided Rope attachment point actor.

### Appearance

- Use the scale value of the controller to make ropes appear thicker or thinner.
- Ropes take on the color and alpha of the controller.
- Ropes are affected by the gravity that applies to the rope controller actor.

### Tightness

You can alter how tight or loose the rope is using the tightness value. This value is in percentage points, and can be
negative to loosen the rope or positive to tighten it.

### Flags

**Loose end** will not attach the end of the rope to the actor it is tagged to. Use this to have loose dangling ropes.

**Always active** will not stop a rope simulation if there is no player or cameras nearby (see limitations). For
performance reasons it is best not to have too many active ropes at the same time.

**Anchor end to rope** will anchor the actor at the end of the rope, to the rope. The actor will go wherever the end
of the rope takes it. Use this together with the "Loose end" flags to have an actor dangle from a rope.

**Interactive** will make the rope respond to hitscan and explosions. Each rope is made up of a number of "particles"
inbetween the segments, so choose a correct number of segments for the rope so that gunfire and projectiles will
not pass through it.

**Settle longer** will let the rope simulation settle for a longer simulation time during map load. Normally ropes
will settle for 20 ticks worth of simulation. With this flag that is extended to 350 ticks worth of simulation. This is
useful for ropes that are visible from starting locations or after exiting a far away teleport, as ropes in those
situations will not have run many simulations yet.

### Wind

To make ropes appear less static, you can add a Rope wind controller. These periodically change a wind vector that is
applied to ropes under its control.Set its angle to where you want the wind to point, and tag it to the rope controllers
you want to be affected by it.

The Maximum magnitude and Maximum magnitude change values are measured in tenths of Doom units. So a maximum magnitude
of 20 will ensure the wind never exceeds a velocity of 2. The Magnitude change delay is the number of octics (8 tics)
between changes to the wind magnitude.

Whenever the change delay runs out, the wind magnitude is updated with a random value between
`-Maximum magnitude change` and `+Maximum magnitude change`. The effect works best if you use relatively frequent but
small changes in magnitude.

## Console variables

### `rope_mesh_quality`

This variable can be set to 0, 1 or 2. At 0 rope meshes will consist of 2 simple planes. Setting it to 1 or 2 will use
an increasingly denser cylinder mesh. The latter values will result in a rope that is much more "part of the scene".
But with a higher mesh quality comes a small performance hit.

### `rope_particle_density`

The number of particles per rope is calculated automatically based on this variable. It indicates the number of
particles to create per 256 map units of rope length (after calculating stiffness). More particles will make ropes
look smoother, at the cost of some performance.

## Limitations

Interactive ropes do not handle collsision with floors, ceilings or walls very well. Try to set up the ropes so that
they interact with those types of surfaces as little as possible.

The rope simulation goes dormant if no camera or player is nearby. If a rope must always be kept active, use the
**Always active** flag.

Many active ropes at the same time can be fairly performance intensive. Even if most of those ropes are not interactive.
Limit the amount of ropes in a given area, limit their length and keep track of VM time spent on them using the
`stat vm` console command.

If you want to attach a rope to a moving actor, flag the rope with **Always active**. Otherwise the actor will continue
moving even when the rope simulation itself has gone dormant.

Ropes cannot intersect with line or sector portals. Their simulation will freak out if you try to do this.

This is only tested with UDMF format maps.

This has not been tested in a multiplayer environment.

## Credits

https://medium.com/@szewczyk.franciszek02/rope-simulator-in-c-a595a3ef956c for the basic rope verlet physics and
Jakobsen constraint implementation.
Kodi and Boondorl for help with making the ropes actually look good.
