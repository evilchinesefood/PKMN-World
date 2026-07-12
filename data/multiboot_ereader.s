	.section .rodata

@ The e-Reader multiboot payload (~12 KB) was removed from this build. The
@ e-Reader screen (src/ereader_screen.c) still references these symbols via the
@ static EReader_Load()/EReader_Transfer() path, so a small placeholder is kept
@ to satisfy the link. If the (unreachable without e-Reader hardware) screen is
@ ever entered, the transfer simply fails and returns.
	.align 2
gMultiBootProgram_EReader_Start::
	.space 0x40, 0
gMultiBootProgram_EReader_End::
