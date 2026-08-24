#ifndef GUARD_CONSTANTS_BERRY_H
#define GUARD_CONSTANTS_BERRY_H

#define BERRY_NONE 0

enum BerryFirmness
{
    BERRY_FIRMNESS_UNKNOWN,
    BERRY_FIRMNESS_VERY_SOFT,
    BERRY_FIRMNESS_SOFT,
    BERRY_FIRMNESS_HARD,
    BERRY_FIRMNESS_VERY_HARD,
    BERRY_FIRMNESS_SUPER_HARD,
};

enum BerryColor
{
    BERRY_COLOR_RED,
    BERRY_COLOR_BLUE,
    BERRY_COLOR_PURPLE,
    BERRY_COLOR_GREEN,
    BERRY_COLOR_YELLOW,
    BERRY_COLOR_PINK,
};

enum __attribute__((__packed__)) Flavor
{
    FLAVOR_SPICY,
    FLAVOR_DRY,
    FLAVOR_SWEET,
    FLAVOR_BITTER,
    FLAVOR_SOUR,
    FLAVOR_COUNT,
};

#define BERRY_STAGE_NO_BERRY    0  // there is no tree planted and the soil is completely flat.
#define BERRY_STAGE_PLANTED     1
#define BERRY_STAGE_SPROUTED    2
#define BERRY_STAGE_TALLER      3
#define BERRY_STAGE_FLOWERING   4
#define BERRY_STAGE_BERRIES     5
#define BERRY_STAGE_TRUNK       6 // These follow BERRY_STAGE_BERRIES to preserve save compatibility
#define BERRY_STAGE_BUDDING     7
#define BERRY_STAGE_SPARKLING   255

// Berries can be watered in the following stages:
// - BERRY_STAGE_PLANTED
// - BERRY_STAGE_SPROUTED
// - BERRY_STAGE_TALLER
// - BERRY_STAGE_FLOWERING
#define NUM_WATER_STAGES 4

// IDs for berry tree objects, indexes into berryTrees in SaveBlock1
// Named for whatever berry is initially planted there on a new game
// Those with no initial berry are named "soil"
#define BERRY_TREE_ROUTE_102_PECHA    1
#define BERRY_TREE_ROUTE_102_ORAN     2
#define BERRY_TREE_ROUTE_104_SOIL_1   3
#define BERRY_TREE_ROUTE_104_ORAN_1   4
#define BERRY_TREE_ROUTE_103_CHERI_1  5
#define BERRY_TREE_ROUTE_103_LEPPA    6
#define BERRY_TREE_ROUTE_103_CHERI_2  7
#define BERRY_TREE_ROUTE_104_CHERI_1  8
#define BERRY_TREE_ROUTE_104_SOIL_2   9
#define BERRY_TREE_ROUTE_104_LEPPA    10
#define BERRY_TREE_ROUTE_104_ORAN_2   11
#define BERRY_TREE_ROUTE_104_SOIL_3   12
#define BERRY_TREE_ROUTE_104_PECHA    13
#define BERRY_TREE_ROUTE_123_QUALOT_1 14
#define BERRY_TREE_ROUTE_123_POMEG_1  15
#define BERRY_TREE_ROUTE_110_NANAB_1  16
#define BERRY_TREE_ROUTE_110_NANAB_2  17
#define BERRY_TREE_ROUTE_110_NANAB_3  18
#define BERRY_TREE_ROUTE_111_RAZZ_1   19
#define BERRY_TREE_ROUTE_111_RAZZ_2   20
#define BERRY_TREE_ROUTE_112_RAWST_1  21
#define BERRY_TREE_ROUTE_112_PECHA_1  22
#define BERRY_TREE_ROUTE_112_PECHA_2  23
#define BERRY_TREE_ROUTE_112_RAWST_2  24
#define BERRY_TREE_ROUTE_116_PINAP_1  25
#define BERRY_TREE_ROUTE_116_CHESTO_1 26
#define BERRY_TREE_ROUTE_117_WEPEAR_1 27
#define BERRY_TREE_ROUTE_117_WEPEAR_2 28
#define BERRY_TREE_ROUTE_117_WEPEAR_3 29
#define BERRY_TREE_ROUTE_123_POMEG_2  30
#define BERRY_TREE_ROUTE_118_SITRUS_1 31
#define BERRY_TREE_ROUTE_118_SOIL     32
#define BERRY_TREE_ROUTE_118_SITRUS_2 33
#define BERRY_TREE_ROUTE_119_POMEG_1  34
#define BERRY_TREE_ROUTE_119_POMEG_2  35
#define BERRY_TREE_ROUTE_119_POMEG_3  36
#define BERRY_TREE_ROUTE_120_ASPEAR_1 37
#define BERRY_TREE_ROUTE_120_ASPEAR_2 38
#define BERRY_TREE_ROUTE_120_ASPEAR_3 39
#define BERRY_TREE_ROUTE_120_PECHA_1  40
#define BERRY_TREE_ROUTE_120_PECHA_2  41
#define BERRY_TREE_ROUTE_120_PECHA_3  42
#define BERRY_TREE_ROUTE_120_RAZZ     43
#define BERRY_TREE_ROUTE_120_NANAB    44
#define BERRY_TREE_ROUTE_120_PINAP    45
#define BERRY_TREE_ROUTE_120_WEPEAR   46
#define BERRY_TREE_ROUTE_121_PERSIM   47
#define BERRY_TREE_ROUTE_121_ASPEAR   48
#define BERRY_TREE_ROUTE_121_RAWST    49
#define BERRY_TREE_ROUTE_121_CHESTO   50
#define BERRY_TREE_ROUTE_121_SOIL_1   51
#define BERRY_TREE_ROUTE_121_NANAB_1  52
#define BERRY_TREE_ROUTE_121_NANAB_2  53
#define BERRY_TREE_ROUTE_121_SOIL_2   54
#define BERRY_TREE_ROUTE_115_BLUK_1   55
#define BERRY_TREE_ROUTE_115_BLUK_2   56
#define BERRY_TREE_UNUSED             57
#define BERRY_TREE_ROUTE_123_POMEG_3  58
#define BERRY_TREE_ROUTE_123_POMEG_4  59
#define BERRY_TREE_ROUTE_123_GREPA_1  60
#define BERRY_TREE_ROUTE_123_GREPA_2  61
#define BERRY_TREE_ROUTE_123_LEPPA_1  62
#define BERRY_TREE_ROUTE_123_SOIL     63
#define BERRY_TREE_ROUTE_123_LEPPA_2  64
#define BERRY_TREE_ROUTE_123_GREPA_3  65
#define BERRY_TREE_ROUTE_116_CHESTO_2 66
#define BERRY_TREE_ROUTE_116_PINAP_2  67
#define BERRY_TREE_ROUTE_114_PERSIM_1 68
#define BERRY_TREE_ROUTE_115_KELPSY_1 69
#define BERRY_TREE_ROUTE_115_KELPSY_2 70
#define BERRY_TREE_ROUTE_115_KELPSY_3 71
#define BERRY_TREE_ROUTE_123_GREPA_4  72
#define BERRY_TREE_ROUTE_123_QUALOT_2 73
#define BERRY_TREE_ROUTE_123_QUALOT_3 74
#define BERRY_TREE_ROUTE_104_SOIL_4   75
#define BERRY_TREE_ROUTE_104_CHERI_2  76
#define BERRY_TREE_ROUTE_114_PERSIM_2 77
#define BERRY_TREE_ROUTE_114_PERSIM_3 78
#define BERRY_TREE_ROUTE_123_QUALOT_4 79
#define BERRY_TREE_ROUTE_111_ORAN_1   80
#define BERRY_TREE_ROUTE_111_ORAN_2   81
#define BERRY_TREE_ROUTE_130_LIECHI   82
#define BERRY_TREE_ROUTE_119_HONDEW_1 83
#define BERRY_TREE_ROUTE_119_HONDEW_2 84
#define BERRY_TREE_ROUTE_119_SITRUS   85
#define BERRY_TREE_ROUTE_119_LEPPA    86
#define BERRY_TREE_ROUTE_123_PECHA    87
#define BERRY_TREE_ROUTE_123_SITRUS   88
#define BERRY_TREE_ROUTE_123_RAWST    89

// Region merge (Johto): dedicated slots for the Johto berry trees, carved from the unused tail
// of the 128-slot berryTrees[] array (no save growth). They were aliased onto Hoenn Route-10x
// trees in johto_compat.h, so harvesting/planting a Johto tree mutated the shared Hoenn slot -
// breaking per-region isolation (deep-review task 14).
//
// NOTE: allocating these constants was only half the job, and for a long time it was the only
// half that had been done - every one of these 11 slots sat unused while 11 Johto trees stayed
// on BERRY_TREE_ROUTE_102_ORAN / _PECHA / BERRY_TREE_ROUTE_118_SITRUS_1, which are live Hoenn
// trees. The map.json objects are now repointed here and seeded in data/scripts/new_game.inc.
// If you add a Johto tree, give it its own slot AND a setberrytree line: a shared id is a
// shared save slot, and the symptom (several trees behaving as one, across two regions) is
// invisible until someone harvests.
#define BERRY_TREE_JOHTO_CHERI_1      90
#define BERRY_TREE_JOHTO_CHERI_2      91
#define BERRY_TREE_JOHTO_RAWST_1      92
#define BERRY_TREE_JOHTO_RAWST_2      93
#define BERRY_TREE_JOHTO_SITRUS_1     94
#define BERRY_TREE_JOHTO_ASPEAR_1     95
#define BERRY_TREE_JOHTO_ASPEAR_2     96
#define BERRY_TREE_JOHTO_CHESTO_2     97
#define BERRY_TREE_JOHTO_LEPPA_1      98
#define BERRY_TREE_JOHTO_LEPPA_2      99
#define BERRY_TREE_JOHTO_LUM_1        100

// Region merge (Kanto): FRLG shipped no berry trees at all, so Kanto had no way to grow the
// berries Kurt's Friend Ball (Cheri) and Level Ball (Persim) need. Twelve trees, one per major
// route, carved from the same unused tail of the 128-slot berryTrees[] array - no save growth.
//
// The same rule as the Johto block applies and is the whole reason these constants exist: ONE ID
// IS ONE SAVE SLOT. A new tree needs its own slot here AND a setberrytree line in
// data/scripts/new_game.inc; reusing an id makes two trees share state, and the symptom (harvest
// one, another empties, possibly in another region) is invisible until someone harvests.
//
//   101 Route 1  (12,16)   105 Route 6  (2,4)    109 Route 13 (26,4)
//   102 Route 3  (62,10)   106 Route 7  (5,1)    110 Route 16 (12,2)
//   103 Route 4  (88,16)   107 Route 8  (65,5)   111 Route 24 (3,6)
//   104 Route 5  (14,21)   108 Route 11 (11,7)   112 Route 25 (25,7)
#define BERRY_TREE_KANTO_CHERI_1      101
#define BERRY_TREE_KANTO_PERSIM_1     102
#define BERRY_TREE_KANTO_CHERI_2      103
#define BERRY_TREE_KANTO_PERSIM_2     104
#define BERRY_TREE_KANTO_CHERI_3      105
#define BERRY_TREE_KANTO_PERSIM_3     106
#define BERRY_TREE_KANTO_CHERI_4      107
#define BERRY_TREE_KANTO_PERSIM_4     108
#define BERRY_TREE_KANTO_SITRUS_1     109
#define BERRY_TREE_KANTO_LUM_1        110
#define BERRY_TREE_KANTO_LUM_2        111
#define BERRY_TREE_KANTO_SITRUS_2     112

// Region merge (Johto, second pass): nine Johto trees used to reach these slots through
// BERRY_TREE_* aliases in constants/johto_compat.h that pointed straight at the
// BERRY_TREE_JOHTO_* ids above - so two map objects on different routes wrote the same
// berryTrees[] index and harvesting one emptied the other. The alias block is gone; each of
// the nine now owns a slot here. Issue #163.
//
//   113 Route 38 (21,24)
//   114 Route 39 (12,27)
//   115 Route 47 (51,8)
//   116 Route 44 (7,10)
//   117 Route 45 (24,87)
//   118 Route 42 (40,19)
//   119 Route 43 (3,27)
//   120 Route 43 (4,25)
//   121 Route 46 (9,11)
#define BERRY_TREE_JOHTO_RAWST_3      113
#define BERRY_TREE_JOHTO_RAWST_4      114
#define BERRY_TREE_JOHTO_SITRUS_2     115
#define BERRY_TREE_JOHTO_ASPEAR_3     116
#define BERRY_TREE_JOHTO_ASPEAR_4     117
#define BERRY_TREE_JOHTO_CHESTO_3     118
#define BERRY_TREE_JOHTO_LEPPA_3      119
#define BERRY_TREE_JOHTO_LEPPA_4      120
#define BERRY_TREE_JOHTO_LUM_2        121

// Remainder (122-127, 6 slots) are unused. BERRY_TREES_COUNT sizes
// gSaveBlock1Ptr->berryTrees[] (include/global.h), so it is save layout: growing it is a save
// break. These 6 are the entire remaining budget for the life of the format.

#define BERRY_TREES_COUNT 128

#endif // GUARD_CONSTANTS_BERRY_H
