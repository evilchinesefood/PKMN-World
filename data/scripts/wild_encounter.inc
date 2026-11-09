InteractWithOverworldWildEncounter::
    lock
    @ A region switch can leave the party empty, and then no battle starts to end the waitstate below.
    getpartysize
    goto_if_eq VAR_RESULT, 0, InteractWithOverworldWildEncounter_NoParty
    overworldwildencounterapproach
    applymovement VAR_LAST_TALKED, Common_Movement_ExclamationMark
    facetogether
    getoverworldwildencounterspecies VAR_0x8005
    playmoncry VAR_0x8005, CRY_MODE_DOUBLES
    waitmoncry
    tryoverworldwildencounter
    waitstate
    end

InteractWithOverworldWildEncounter_NoParty::
    release
    end

