/* Embedded DSL for testing overworld scripts in isolation.
 * The overworld is not available, so it is only possible to test
 * commands which don't affect the overworld itself, e.g. givemon can
 * be tested because it only alters gParties[B_TRAINER_PLAYER], but addobject cannot
 * because it affects object events (which aren't loaded).
 *
 * OVERWORLD_SCRIPT(instructions...)
 * Returns a pointer to a compiled overworld script. Cannot be used to
 * initialize global const data, although the pointer IS to const data.
 * Note that each script command must be followed by a ;, e.g.:
 *     const u8 *myScript = OVERWORLD_SCRIPT(
 *         random 2;
 *         addvar VAR_RESULT, 1;
 *     );
 *
 * RUN_OVERWORLD_SCRIPT(instructions...)
 * Runs an overworld script in the immediate script context, which means
 * that commands like waitstate are not supported.
 *     RUN_OVERWORLD_SCRIPT(
 *         setvar VAR_RESULT, 3;
 *     );
 *     EXPECT_EQ(GetVar(VAR_RESULT), 3); */
#ifndef GUARD_TEST_OVERWORLD_SCRIPT
#define GUARD_TEST_OVERWORLD_SCRIPT

#include "script.h"
#include "test/test.h"

#define OVERWORLD_SCRIPT(...) \
    ({ \
        const u8 *_script; \
        asm("mov %0, pc\n" \
            "b 1f\n" \
            STR(__VA_ARGS__) \
            "\n" \
            "end\n" \
            ".balign 2\n" \
            "1:\n" \
        : "=r" (_script)); \
        _script; \
    })

#define RUN_OVERWORLD_SCRIPT(...) RunScriptImmediately(OVERWORLD_SCRIPT(__VA_ARGS__))

// Make important constants available.
// TODO: Find a better approach to this.
asm(".set FALSE, 0\n"
    ".set TRUE, 1\n"
    // enum ComparisonOperators (constants/comparison_operators.h). goto_if_eq and friends now
    // expand to `trycompare <op>, ...` instead of a literal, and nothing cpp-processes this
    // block -- without these, `.byte EQUAL` emits an undefined symbol and make check fails at
    // LINK, which reads as unrelated breakage. Upstream ships the same gap (issue #120).
    ".set LESS_THAN, 0\n"
    ".set EQUAL, 1\n"
    ".set GREATER_THAN, 2\n"
    ".set LESS_THAN_OR_EQUAL, 3\n"
    ".set GREATER_THAN_OR_EQUAL, 4\n"
    ".set NOT_EQUAL, 5\n"
    ".set PARTY_SIZE, " STR(PARTY_SIZE) "\n"
    ".set VARS_START, " STR(VARS_START) "\n"
    ".set VARS_END, " STR(VARS_END) "\n"
    ".set MON_GENDER_MAY_CUTE_CHARM, " STR(MON_GENDER_MAY_CUTE_CHARM) "\n"
    ".set NATURE_MAY_SYNCHRONIZE, " STR(NATURE_MAY_SYNCHRONIZE) "\n"
    ".set SPECIAL_VARS_START, " STR(SPECIAL_VARS_START) "\n"
    ".set SPECIAL_VARS_END, " STR(SPECIAL_VARS_END) "\n");

// Make overworld script macros available.
asm(".include \"constants/gba_constants.inc\"\n"
    ".include \"asm/macros/asm.inc\"\n"
    ".include \"asm/macros/event.inc\"\n");

#endif
