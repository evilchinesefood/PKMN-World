#ifndef COMFY_ANIM_H
#define COMFY_ANIM_H

// t represents progress of the animation, where 0 is the start of the animation and 1 is the end.
// The return value is a Q_24_8 fixed-point value.
typedef s32 (*ComfyAnimEasingFunc)(s32 t /* Q_24_8 */);

struct ComfyAnimEasingConfig {
    // The total duration of the animation in frames (e.g. ~60 frames per second)
    u32 durationFrames;
    // The starting position of the animation. Q_24_8 fixed-point value
    s32 from;
    // The target position of the animation. Q_24_8 fixed-point value
    s32 to;
    // The easing function used for advancing the animation.
    ComfyAnimEasingFunc easingFunc;
};

struct ComfyAnim {
    struct ComfyAnimEasingConfig config;
    u32 curFrame;
    // The current position of the animation. Q_24_8 fixed-point value
    s32 position;
    // Indicates whether or not the animation has completed.
    bool32 completed;
    // Indicates whether or not the animation is currently in use.
    // It's up to the consumer to call ReleaseComfyAnim when finished with it.
    bool32 inUse;
};

#define NUM_COMFY_ANIMS     8
#define INVALID_COMFY_ANIM  NUM_COMFY_ANIMS
extern struct ComfyAnim gComfyAnims[NUM_COMFY_ANIMS];

void TryAdvanceComfyAnim(struct ComfyAnim *anim);
void AdvanceComfyAnimations(void);
void InitComfyAnimConfig_Easing(struct ComfyAnimEasingConfig *config);
void InitComfyAnim_Easing(struct ComfyAnimEasingConfig *config, struct ComfyAnim *out);
u32 CreateComfyAnim_Easing(struct ComfyAnimEasingConfig *config);
void ReleaseComfyAnim(u32 comfyAnimId);
void ReleaseComfyAnims(void);
int ReadComfyAnimValueSmooth(struct ComfyAnim *anim);

// Collection of standard easing functions
s32 ComfyAnimEasing_Linear(s32 t);
s32 ComfyAnimEasing_EaseOutCubic(s32 t);
s32 ComfyAnimEasing_EaseInOutCubic(s32 t);

#endif // COMFY_ANIM_H
