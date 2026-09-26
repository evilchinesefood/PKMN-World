#ifndef GUARD_AMBIENT_RIPPLES_H
#define GUARD_AMBIENT_RIPPLES_H

void ResetAmbientRipples(void);
void UpdateAmbientRipples(void);
// Bounded, RNG-free reclamation for higher-priority graphics consumers.
// Returns TRUE only when resources were released; never evicts gameplay effects.
bool32 ReclaimAmbientRipples(void);

#endif
