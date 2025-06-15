# Version 2.0.0

- The segment count argument has been removed. The number of segments is now automatically calculated based on the
rope length and the `rope_particle_density` console variable.
- Ropes now have a detail console variable `rope_mesh_quality` where they will use an increasingly denser cylindrical
mesh.
- Simplified the rope dormancy check and made it portal-aware.
- All ropes now settle for 10 ticks of simulation on map load.
- A flag has been added to let ropes settle for 350 ticks of simulation on map load.
- Moved some internal constants into CVars.
- Tuned interactive rope damage factors to make hitscan weapons affect them more and radius damage affect them less.

# Version 1.0.0

- Initial release.
