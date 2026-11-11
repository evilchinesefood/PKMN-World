#include "global.h"
#include "option_rates.h"

u32 ApplyOptionRate(u32 amount, u32 rate)
{
    static const u8 halfUnits[OPTIONS_RATE_COUNT] =
    {
        [OPTIONS_RATE_1X] = 2,
        [OPTIONS_RATE_0_5X] = 1,
        [OPTIONS_RATE_1_5X] = 3,
        [OPTIONS_RATE_2X] = 4,
    };

    return (u64)amount * halfUnits[rate] / 2;
}
