	.section .rodata

@ The Berry Glitch Fix multiboot payload (~15 KB) was removed from this build.
@ The berry-fix program (src/berry_fix_program.c) is no longer reachable (its
@ title-screen triggers were deleted), but it still references these symbols, so
@ a small placeholder is kept here to satisfy the link. The size is > ROM_HEADER_SIZE
@ (0xC0) so the MultiBootStartMaster length computation cannot underflow.
	.align 2
gMultiBootProgram_BerryGlitchFix_Start::
	.space 0x100, 0
gMultiBootProgram_BerryGlitchFix_End::
