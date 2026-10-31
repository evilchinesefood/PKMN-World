// Struct offsets for the Johto playthrough harness. Built by export.py with the ROM's own flags;
// each value is emitted as the size of a char array (offset + 1) and read back with nm -S.
#include "global.h"
#include "battle.h"
#include "pokemon.h"
#include "event_object_movement.h"
#include "global.fieldmap.h"
#define P(name, expr) char p_##name[(expr) + 1];
P(sb1_flags, offsetof(struct SaveBlock1, flags))
P(sb1_vars, offsetof(struct SaveBlock1, vars))
P(sb1_money, offsetof(struct SaveBlock1, money))
P(bm_size, sizeof(struct BattlePokemon))
P(bm_species, offsetof(struct BattlePokemon, species))
P(bm_moves, offsetof(struct BattlePokemon, moves))
P(bm_pp, offsetof(struct BattlePokemon, pp))
P(bm_hp, offsetof(struct BattlePokemon, hp))
P(bm_maxHP, offsetof(struct BattlePokemon, maxHP))
P(bm_level, offsetof(struct BattlePokemon, level))
P(bm_types, offsetof(struct BattlePokemon, types))
P(bm_ability, offsetof(struct BattlePokemon, ability))
P(mon_size, sizeof(struct Pokemon))
P(mon_hp, offsetof(struct Pokemon, hp))
P(mon_maxHP, offsetof(struct Pokemon, maxHP))
P(mon_level, offsetof(struct Pokemon, level))
P(mon_attack, offsetof(struct Pokemon, attack))
P(mon_spDefense, offsetof(struct Pokemon, spDefense))
P(oe_size, sizeof(struct ObjectEvent))
P(oe_movementType, offsetof(struct ObjectEvent, movementType))
P(oe_trainerType, offsetof(struct ObjectEvent, trainerType))
P(oe_localId, offsetof(struct ObjectEvent, localId))
P(oe_mapNum, offsetof(struct ObjectEvent, mapNum))
P(oe_mapGroup, offsetof(struct ObjectEvent, mapGroup))
P(oe_currentCoords, offsetof(struct ObjectEvent, currentCoords))
P(oe_previousCoords, offsetof(struct ObjectEvent, previousCoords))
P(oe_graphicsId, offsetof(struct ObjectEvent, graphicsId))
P(ote_size, sizeof(struct ObjectEventTemplate))
P(pa_flags, offsetof(struct PlayerAvatar, flags))
P(pa_objectEventId, offsetof(struct PlayerAvatar, objectEventId))
