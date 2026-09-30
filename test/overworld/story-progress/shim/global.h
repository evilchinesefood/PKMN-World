#ifndef STORY_TEST_GLOBAL_H
#define STORY_TEST_GLOBAL_H
#define GUARD_GLOBAL_H
#include <stdint.h>
#include <stddef.h>
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint8_t bool8;
typedef uint32_t bool32;
#define TRUE 1
#define FALSE 0
#define ARRAY_COUNT(a) (sizeof(a) / sizeof((a)[0]))
#define COMPOUND_STRING(x) ((const u8 *)(x))
struct SaveBlock2 { u8 kantoIntroDone, johtoIntroDone, hoennIntroDone; };
extern struct SaveBlock2 *gSaveBlock2Ptr;
#endif
