# Lifecycle and spherical sky integration

Baseline: f970e3d (user-verified native transport). Transport remains unchanged.

Implementation gates:
1. Separate active plants, soil-owned litter/mobile dead carbon, and historical records; maintain conservative transfers and backward-readable checkpoints.
2. Verify shedding, death, cancellation, complete removal, decomposition and checkpoint continuation. Keep corpse visuals out of live selection.
3. Measure tree-type baseline across seeds and day/night lifetimes before changing policy or maintenance. Report failed establishment honestly; type 0 is not a tree surrogate.
4. Isolate skybox, engine atmosphere, water scattering and post-effects. Establish explicit above-water/underwater ownership using measured lake submersion rather than planetary radius.
5. Validate geometry/color continuity and radial dawn/noon/dusk/night; run native and Luau regression gates. Studio visual verification remains a distinct gate.

Working findings:
- LakePresentation activates atmosphere and lighting by proximity, even when above water; Celestial also manages atmosphere.
- Existing engine solar fit samples the lake up vector, not the observer's current radial up.
- Dead plants retain organism selection tags; detached organs remain in plant storage until incremental transfer completes.
