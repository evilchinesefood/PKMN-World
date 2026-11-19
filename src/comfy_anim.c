#include "global.h"
#include "comfy_anim.h"
#include "math_util.h"

EWRAM_DATA struct ComfyAnim gComfyAnims[NUM_COMFY_ANIMS] = {0};

static void AdvanceComfyAnim_Easing(struct ComfyAnim *anim)
{
    s32 t, x;
    struct ComfyAnimEasingConfig *config = &anim->config;

    anim->curFrame++;

    // Determine progress of animation, normalized to (0, 1]. The result is a Q_24_8 fixed-point representation.
    // This is simply calculated as: curFrame / durationFrames
    t = MathUtil_Div32(Q_24_8(anim->curFrame), Q_24_8(anim->config.durationFrames));

    // Early exit if we know we're at the end of the animation--no need to invoke the easing function.
    if (t == Q_24_8(1))
    {
        anim->position = config->to;
        anim->completed = TRUE;
        return;
    }

    // Invoke the easing function to interpolate between the start and end states of the animation.
    x = anim->config.easingFunc(t);
    anim->position = config->from + MathUtil_Mul32(x, (config->to - config->from));

    if (anim->curFrame >= config->durationFrames)
        anim->completed = TRUE;
}

void TryAdvanceComfyAnim(struct ComfyAnim *anim)
{
    if (anim->inUse && !anim->completed)
        AdvanceComfyAnim_Easing(anim);
}

void AdvanceComfyAnimations(void)
{
    int i;

    for (i = 0; i < NUM_COMFY_ANIMS; i++)
    {
        if (gComfyAnims[i].inUse)
            TryAdvanceComfyAnim(&gComfyAnims[i]);
    }
}

static u32 GetAvailableComfyAnim(void)
{
    int i;

    // Find the first free comfy anim.
    for (i = 0; i < NUM_COMFY_ANIMS; i++)
    {
        if (!gComfyAnims[i].inUse)
            return i;
    }

    return INVALID_COMFY_ANIM;
}

void InitComfyAnimConfig_Easing(struct ComfyAnimEasingConfig *config)
{
    memset(config, 0, sizeof(struct ComfyAnimEasingConfig));
    config->easingFunc = ComfyAnimEasing_Linear;
}

void InitComfyAnim_Easing(struct ComfyAnimEasingConfig *config, struct ComfyAnim *out)
{
    out->inUse = TRUE;
    out->completed = FALSE;
    out->position = config->from;
    out->config = *config;
    out->curFrame = 0;
}

u32 CreateComfyAnim_Easing(struct ComfyAnimEasingConfig *config)
{
    struct ComfyAnim *anim;
    int i = GetAvailableComfyAnim();

    if (i == INVALID_COMFY_ANIM)
        return i;

    anim = &gComfyAnims[i];
    InitComfyAnim_Easing(config, anim);
    return i;
}

void ReleaseComfyAnim(u32 comfyAnimId)
{
    if (comfyAnimId < NUM_COMFY_ANIMS)
        gComfyAnims[comfyAnimId].inUse = FALSE;
}

void ReleaseComfyAnims(void)
{
    int i;

    for (i = 0; i < NUM_COMFY_ANIMS; i++)
        ReleaseComfyAnim(i);
}

int ReadComfyAnimValueSmooth(struct ComfyAnim *anim)
{
    return Q_24_8_TO_INT(anim->position + 0x80);
}

// Easing functions borrowed from easings.net library
// https://github.com/ai/easings.net/blob/master/src/easings/easingsFunctions.ts

s32 ComfyAnimEasing_Linear(s32 t /* Q_24_8 */)
{
    return t;
}

s32 ComfyAnimEasing_EaseOutCubic(s32 t /* Q_24_8 */)
{
    s32 v = Q_24_8(1) - t;
    return Q_24_8(1) - MathUtil_Mul32(v, MathUtil_Mul32(v, v));
}

s32 ComfyAnimEasing_EaseInOutCubic(s32 t /* Q_24_8 */)
{
    if (t < (Q_24_8(1) >> 1))
        return 4 * MathUtil_Mul32(t, MathUtil_Mul32(t, t));
    else
    {
        s32 v = -2 * t + Q_24_8(2);
        return Q_24_8(1) - (MathUtil_Mul32(v, MathUtil_Mul32(v, v)) >> 1);
    }
}
