@ ============================================================================
@ CompatEvent.inc  -  HnS -> PKMN-World script-macro compatibility shim
@ ----------------------------------------------------------------------------
@ Included AFTER the target's asm/macros/event.inc. It REDEFINES the handful of
@ HnS macros whose bytecode/handler diverges from the target so that transformed
@ HnS scripts emit TARGET-CORRECT bytecode.
@
@ Only divergent macros are redefined here; the ~124 base opcodes (0x00-0x78)
@ are byte-identical between forks and recompile unchanged against the target's
@ own event.inc - they are NOT touched.
@
@ Divergence classes (see phase2-j5-script-shim.md):
@   B  applymovement2  -> applymovement      (HnS 0xe8 dup -> base 0x4f)
@   C  checkpartymove  -> checkfieldmove      (u16 move -> u8 fieldmove + flag)
@   E  Johto-only ops with NO target handler  -> safe nop backfill
@   F  HnS ops whose opcode the target REUSES  -> safe nop backfill
@ Class D (bare `trainerbattle <TYPE>,...`) is handled by the transform tool
@ rewriting the call site, NOT here (the macro signature itself is incompatible).
@ ============================================================================

@ --- Class B: applymovement2 is a pure HnS duplicate of applymovement -------
@ HnS 0xe8 == target SCR_OP_QUESTMENU, so the raw byte must NOT carry over.
@ The 2-arg form is identical to applymovement; the 3-arg (map) form maps to
@ applymovementat-style 0x50. Re-express via the target's own macros.
	.macro applymovement2 localId:req, movements:req, map
		.ifb \map
			applymovement \localId, \movements
		.else
			applymovement \localId, \movements, \map
		.endif
	.endm

@ --- Class C: checkpartymove (u16 move) -> checkfieldmove (u8 fieldmove) -----
@ HnS:    .byte 0x7c ; .2byte <MOVE_*>
@ Target: .byte 0x7c ; .byte <FIELD_MOVE_*> ; .byte <checkUnlocked>
@ The transform tool rewrites the MOVE_* arg to the FIELD_MOVE_* enum before
@ this macro is reached, so here we just forward to the target macro.
	.macro checkpartymove fieldMove:req
		checkfieldmove \fieldMove
	.endm

@ ----------------------------------------------------------------------------
@ Classes E + F: HnS opcodes whose handler the target either lacks (0xec-0xf5)
@ or has REUSED for a different command (0xe3-0xe8). The HnS C handlers are real
@ and portable (they touch only save-block/string-var fields the target also
@ has: battle-frontier BP, named-gift mons Kenya/Shuckie/Eevee, the Odd Egg,
@ Baoba's Safari checks). NOP-ing them would silently break Johto story content,
@ so each is re-expressed as `callnative` to a compat handler that J14 ports
@ verbatim from HnS src/scrcmd.c into src/scrcmd_johto_compat.c. Operands are
@ passed inline exactly as the HnS handler reads them (ScriptReadHalfword etc.),
@ so the byte layout after the callnative pointer is preserved.
@
@ callnative encoding (target 0x23): .byte 0x23 ; .4byte <func> ; <operands...>
@ Each compat handler advances ctx->scriptPtr past its own operands, identical
@ to the original HnS handler body.
@ ----------------------------------------------------------------------------

	.macro givebp number:req
		callnative ScrCmd_givebp_Compat
		.2byte \number
	.endm
	.macro givenamedmon number:req
		callnative ScrCmd_givenamedmon_Compat
		.2byte \number
	.endm
	.macro removenamedmon number:req
		callnative ScrCmd_removenamedmon_Compat
		.2byte \number
	.endm
	.macro remove5mons
		callnative ScrCmd_remove5mons_Compat
	.endm
	.macro removegenericmon number:req
		callnative ScrCmd_removegenericmon_Compat
		.2byte \number
	.endm
	.macro baobacheckmon number:req
		callnative ScrCmd_baobacheckmon_Compat
		.2byte \number
	.endm
	.macro giveoddegg number:req
		callnative ScrCmd_giveoddegg_Compat
		.2byte \number
	.endm
	.macro setwildbattleshiny species:req, level:req, item=ITEM_NONE
		callnative ScrCmd_setwildbattleshiny_Compat
		.2byte \species
		.byte \level
		.2byte \item
	.endm
	.macro buffermoncategory stringVarId:req, species:req
		callnative ScrCmd_buffermoncategory_Compat
		stringvar \stringVarId
		.2byte \species
	.endm
	.macro checknuzlocke
		callnative ScrCmd_checknuzlocke_Compat
	.endm
	.macro checkrandomizer
		callnative ScrCmd_checkrandomizer_Compat
	.endm
	.macro checkpcspace itemId:req, quantity=1
		callnative ScrCmd_checkpcspace_Compat
		.2byte \itemId
		.2byte \quantity
	.endm
	.macro checkpartymonlevel level:req
		callnative ScrCmd_checkpartymonlevel_Compat
		.2byte \level
	.endm
	.macro calculatemonstats
		callnative ScrCmd_calculatemonstats_Compat
	.endm
	.macro deleteparty
		callnative ScrCmd_deleteparty_Compat
	.endm
	.macro callfunc func:req
		callnative ScrCmd_callfunc_Compat
		.4byte \func
	.endm
	@ === Blackthorn area (Ice Path berry puzzle) ===
	@ HnS `chooseitem <pocket>` opens the bag to <pocket> via `special ChooseItemFromBag`
	@ and stores the picked item in VAR_ITEM_ID. That bag-choice UI isn't ported; a literal
	@ expansion (fadescreen + waitstate + no-op special) would soft-lock. For the port stage,
	@ resolve the pick to "nothing" so the caller's `removeitem VAR_ITEM_ID, 1` /
	@ `goto_if_ne VAR_ITEM_ID, ITEM_ASPEAR_BERRY` path falls through to the disliked-berry
	@ branch with no side effects or freeze. \pocket is intentionally unreferenced; the real
	@ bag UI is content-stage work.
	.macro chooseitem pocket:req
		setvar VAR_ITEM_ID, ITEM_NONE
	.endm
