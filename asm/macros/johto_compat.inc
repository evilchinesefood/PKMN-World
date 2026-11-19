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

@ Johto-specific commands call the native handlers in scrcmd_johto_compat.c.
@ Each handler reads the inline operands emitted by its macro.
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
	@ === Blackthorn area (Ice Path berry puzzle) ===
	@ HnS `chooseitem <pocket>` opens the bag to <pocket> via `special ChooseItemFromBag` and
	@ stores the picked item in VAR_ITEM_ID. That bag-choice UI is not ported. Resolve the pick
	@ to "nothing" instead: a literal expansion (fadescreen + waitstate + a no-op special) would
	@ soft-lock, because waitstate blocks until the picker's callback resumes the script context
	@ and no picker would ever run. \pocket is intentionally unreferenced.
	@
	@ WONTFIX (issue #66), and the old "the real bag UI is content-stage work" line was doubly
	@ wrong. First, the caller it describes no longer exists: the Ice Path berry puzzle was
	@ reworked to check the bag directly (`checkitem ITEM_ASPEAR_BERRY` / `removeitem
	@ ITEM_ASPEAR_BERRY, 1` in IcePath_B3F/scripts.inc, for both the Swinub and the Delibird),
	@ so the puzzle already completes and hands out TM_BLIZZARD with no bag UI involved. Second,
	@ `chooseitem` now has ZERO invocation sites anywhere in the tree — this macro is dormant,
	@ not degraded, and nothing is waiting on it. Porting a whole bag-selection UI and its
	@ callback contract from HnS to serve no call site is not happening.
	@
	@ It is kept rather than deleted so a future HnS script import still assembles instead of
	@ erroring out, and so this note stays attached to the decision. Do NOT change the macro's
	@ signature or body: test/overworld/ValidateScripts.py parses this file as one of its MACRO_FILES
	@ and derives pointer-vs-value argument slots by symbolically expanding each macro, so
	@ dropping the argument or introducing a `.4byte` here changes what that validator enforces
	@ across every event script in data/.
	.macro chooseitem pocket:req
		setvar VAR_ITEM_ID, ITEM_NONE
	.endm
