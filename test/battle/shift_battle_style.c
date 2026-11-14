#include "global.h"
#include "test/battle.h"

AI_SINGLE_BATTLE_TEST("Shift style: the foe's replacement gets its switch-in effects when the mon switched in first faints to hazards")
{
    GIVEN {
        ShiftBattleStyle();
        ASSUME(GetMoveEffect(MOVE_SPIKES) == EFFECT_SPIKES);
        PLAYER(SPECIES_WOBBUFFET) { Speed(10); Moves(MOVE_TACKLE, MOVE_CELEBRATE); }
        PLAYER(SPECIES_WYNAUT) { HP(1); Speed(10); }
        PLAYER(SPECIES_WOBBUFFET) { Speed(10); Moves(MOVE_MEMENTO); }
        PLAYER(SPECIES_WYNAUT) { Speed(10); }
        OPPONENT(SPECIES_WOBBUFFET) { HP(1); Speed(1); Moves(MOVE_SPIKES); }
        OPPONENT(SPECIES_POLITOED) { Ability(ABILITY_DRIZZLE); Speed(1); Moves(MOVE_CELEBRATE); }
    } WHEN {
        TURN { MOVE(player, MOVE_CELEBRATE); EXPECT_MOVE(opponent, MOVE_SPIKES); }
        TURN { MOVE(player, MOVE_TACKLE); EXPECT_SEND_OUT(opponent, 1); SEND_OUT(player, 1); SEND_OUT(player, 2); }
        TURN { MOVE(player, MOVE_MEMENTO); EXPECT_MOVE(opponent, MOVE_CELEBRATE); SEND_OUT(player, 3); }
    } SCENE {
        MESSAGE("The opposing Wobbuffet fainted!");
        MESSAGE("Wynaut fainted!");
        ABILITY_POPUP(opponent, ABILITY_DRIZZLE);
        ANIMATION(ANIM_TYPE_MOVE, MOVE_MEMENTO, player);
        MESSAGE("Wobbuffet fainted!");
    }
}
