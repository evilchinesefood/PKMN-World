# Direct SIO diagnostic (not a passing gameplay test)

World's production `LINK_CABLE_CLUB=FALSE` excludes the normal room flow. This
original test frontend connects two mGBA cores with the actual
`GBASIOLockstepCoordinator`, then invokes fixture command 10. It does not fake
received packets or enable production Cable Club. Command 10 uses the field
return callback because the Cable Club return function is compiled out.

Pinned mGBA source: `mgba-emu/mgba` at
`669817d03e4858e65d0b992bcd96d3009236cc1e` (MPL-2.0). Both World baseline
`12934378` and BW establish two low-level players, then report link checksum
errors `0x2268` / `0x2249` before battle presentation. See the retained baseline
and BW diagnostic logs. This is a validation limitation, not a successful link
session. The main integration runner intentionally does not count this as green.

To reproduce, build mGBA statically with scripting/Qt/SDL/headless disabled,
libpng enabled, and add `pw-link.c` as an executable linked to `mgba`. Copy the
library's **actual** compile definitions to the executable:

```cmake
add_executable(pw-link pw-link.c)
target_link_libraries(pw-link mgba)
target_compile_definitions(pw-link PRIVATE $<TARGET_PROPERTY:mgba,COMPILE_DEFINITIONS>)
```

The generated `flags.h` alone omits definitions affecting `struct mCore` in this
configuration. Using a mismatched header layout will crash before emulation.
Generate `pw-symbols.h` using the script here, with the exact fixture and ELF:

```sh
python3 export_symbols.py --fixture /tmp/bw-fixture --elf /path/to/pokemonworld.elf --out /path/to/mgba/pw-symbols.h
/path/to/mgba/build/pw-link /tmp/bw-fixture/VerifyFeatures.gba /tmp/bw-checks/save/VisualReview.sav /tmp/link-output
```

Create the output directory first. The save is synthetic and loaded privately.
The frontend captures both screens and exits nonzero on synchronization failure.
