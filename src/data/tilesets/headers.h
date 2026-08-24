#include "fieldmap.h"


const struct Tileset gTileset_SecretBase =
{
    .isCompressed = FALSE,
    .isSecondary = FALSE,
    .tiles = gTilesetTiles_SecretBase,
    .palettes = gTilesetPalettes_SecretBase,
    TILESET_METATILES(gMetatiles_SecretBasePrimary, gMetatileAttributes_SecretBasePrimary),
    .callback = NULL,
};

const struct Tileset gTileset_SecretBaseRedCave =
{
    .isCompressed = FALSE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SecretBaseRedCave,
    .palettes = gTilesetPalettes_SecretBaseRedCave,
    TILESET_METATILES(gMetatiles_SecretBaseSecondary, gMetatileAttributes_SecretBaseSecondary),
    .callback = NULL,
};

const struct Tileset *const gTilesetPointer_SecretBase = &gTileset_SecretBase;
const struct Tileset *const gTilesetPointer_SecretBaseRedCave = &gTileset_SecretBaseRedCave;

#if !IS_FRLG

const struct Tileset gTileset_General =
{
    .isCompressed = TRUE,
    .isSecondary = FALSE,
    .tiles = gTilesetTiles_General,
    .palettes = gTilesetPalettes_General,
    TILESET_METATILES(gMetatiles_General, gMetatileAttributes_General),
    .callback = InitTilesetAnim_General,
};

const struct Tileset gTileset_Petalburg =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Petalburg,
    .palettes = gTilesetPalettes_Petalburg,
    TILESET_METATILES(gMetatiles_Petalburg, gMetatileAttributes_Petalburg),
    .callback = InitTilesetAnim_Petalburg,
};

const struct Tileset gTileset_Rustboro =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Rustboro,
    .palettes = gTilesetPalettes_Rustboro,
    TILESET_METATILES(gMetatiles_Rustboro, gMetatileAttributes_Rustboro),
    .callback = InitTilesetAnim_Rustboro,
};

const struct Tileset gTileset_Dewford =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Dewford,
    .palettes = gTilesetPalettes_Dewford,
    TILESET_METATILES(gMetatiles_Dewford, gMetatileAttributes_Dewford),
    .callback = InitTilesetAnim_Dewford,
};

const struct Tileset gTileset_Slateport =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Slateport,
    .palettes = gTilesetPalettes_Slateport,
    TILESET_METATILES(gMetatiles_Slateport, gMetatileAttributes_Slateport),
    .callback = InitTilesetAnim_Slateport,
};

const struct Tileset gTileset_Mauville =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Mauville,
    .palettes = gTilesetPalettes_Mauville,
    TILESET_METATILES(gMetatiles_Mauville, gMetatileAttributes_Mauville),
    .callback = InitTilesetAnim_Mauville,
};

const struct Tileset gTileset_Lavaridge =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Lavaridge,
    .palettes = gTilesetPalettes_Lavaridge,
    TILESET_METATILES(gMetatiles_Lavaridge, gMetatileAttributes_Lavaridge),
    .callback = InitTilesetAnim_Lavaridge,
};

const struct Tileset gTileset_Fallarbor =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Fallarbor,
    .palettes = gTilesetPalettes_Fallarbor,
    TILESET_METATILES(gMetatiles_Fallarbor, gMetatileAttributes_Fallarbor),
    .callback = InitTilesetAnim_Fallarbor,
};

const struct Tileset gTileset_Fortree =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Fortree,
    .palettes = gTilesetPalettes_Fortree,
    TILESET_METATILES(gMetatiles_Fortree, gMetatileAttributes_Fortree),
    .callback = InitTilesetAnim_Fortree,
};

const struct Tileset gTileset_Lilycove =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Lilycove,
    .palettes = gTilesetPalettes_Lilycove,
    TILESET_METATILES(gMetatiles_Lilycove, gMetatileAttributes_Lilycove),
    .callback = InitTilesetAnim_Lilycove,
};

const struct Tileset gTileset_Mossdeep =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Mossdeep,
    .palettes = gTilesetPalettes_Mossdeep,
    TILESET_METATILES(gMetatiles_Mossdeep, gMetatileAttributes_Mossdeep),
    .callback = InitTilesetAnim_Mossdeep,
};

const struct Tileset gTileset_EverGrande =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_EverGrande,
    .palettes = gTilesetPalettes_EverGrande,
    TILESET_METATILES(gMetatiles_EverGrande, gMetatileAttributes_EverGrande),
    .callback = InitTilesetAnim_EverGrande,
};

const struct Tileset gTileset_Pacifidlog =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Pacifidlog,
    .palettes = gTilesetPalettes_Pacifidlog,
    TILESET_METATILES(gMetatiles_Pacifidlog, gMetatileAttributes_Pacifidlog),
    .callback = InitTilesetAnim_Pacifidlog,
};

const struct Tileset gTileset_Sootopolis =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Sootopolis,
    .palettes = gTilesetPalettes_Sootopolis,
    TILESET_METATILES(gMetatiles_Sootopolis, gMetatileAttributes_Sootopolis),
    .callback = InitTilesetAnim_Sootopolis,
};

const struct Tileset gTileset_BattleFrontierOutsideWest =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BattleFrontierOutsideWest,
    .palettes = gTilesetPalettes_BattleFrontierOutsideWest,
    TILESET_METATILES(gMetatiles_BattleFrontierOutsideWest, gMetatileAttributes_BattleFrontierOutsideWest),
    .callback = InitTilesetAnim_BattleFrontierOutsideWest,
};

const struct Tileset gTileset_BattleFrontierOutsideEast =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BattleFrontierOutsideEast,
    .palettes = gTilesetPalettes_BattleFrontierOutsideEast,
    TILESET_METATILES(gMetatiles_BattleFrontierOutsideEast, gMetatileAttributes_BattleFrontierOutsideEast),
    .callback = InitTilesetAnim_BattleFrontierOutsideEast,
};

const struct Tileset gTileset_Building =
{
    .isCompressed = TRUE,
    .isSecondary = FALSE,
    .tiles = gTilesetTiles_InsideBuilding,
    .palettes = gTilesetPalettes_InsideBuilding,
    TILESET_METATILES(gMetatiles_InsideBuilding, gMetatileAttributes_InsideBuilding),
    .callback = InitTilesetAnim_Building,
};

const struct Tileset gTileset_Shop =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Shop,
    .palettes = gTilesetPalettes_Shop,
    TILESET_METATILES(gMetatiles_Shop, gMetatileAttributes_Shop),
    .callback = NULL,
};

const struct Tileset gTileset_PokemonCenter =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PokemonCenter,
    .palettes = gTilesetPalettes_PokemonCenter,
    TILESET_METATILES(gMetatiles_PokemonCenter, gMetatileAttributes_PokemonCenter),
    .callback = NULL,
};

const struct Tileset gTileset_Cave =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Cave,
    .palettes = gTilesetPalettes_Cave,
    TILESET_METATILES(gMetatiles_Cave, gMetatileAttributes_Cave),
    .callback = InitTilesetAnim_Cave,
};

const struct Tileset gTileset_PokemonSchool =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PokemonSchool,
    .palettes = gTilesetPalettes_PokemonSchool,
    TILESET_METATILES(gMetatiles_PokemonSchool, gMetatileAttributes_PokemonSchool),
    .callback = NULL,
};

const struct Tileset gTileset_PokemonFanClub =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PokemonFanClub,
    .palettes = gTilesetPalettes_PokemonFanClub,
    TILESET_METATILES(gMetatiles_PokemonFanClub, gMetatileAttributes_PokemonFanClub),
    .callback = NULL,
};

const struct Tileset gTileset_Unused1 =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Unused1,
    .palettes = gTilesetPalettes_Unused1,
    TILESET_METATILES(gMetatiles_Unused1, gMetatileAttributes_Unused1),
    .callback = NULL,
};

const struct Tileset gTileset_MeteorFalls =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_MeteorFalls,
    .palettes = gTilesetPalettes_MeteorFalls,
    TILESET_METATILES(gMetatiles_MeteorFalls, gMetatileAttributes_MeteorFalls),
    .callback = NULL,
};

const struct Tileset gTileset_OceanicMuseum =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_OceanicMuseum,
    .palettes = gTilesetPalettes_OceanicMuseum,
    TILESET_METATILES(gMetatiles_OceanicMuseum, gMetatileAttributes_OceanicMuseum),
    .callback = NULL,
};

const struct Tileset gTileset_CableClub =
{
    .isCompressed = FALSE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_CableClub,
    .palettes = gTilesetPalettes_CableClub,
    TILESET_METATILES(gMetatiles_CableClub, gMetatileAttributes_CableClub),
    .callback = NULL,
};

const struct Tileset gTileset_SeashoreHouse =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SeashoreHouse,
    .palettes = gTilesetPalettes_SeashoreHouse,
    TILESET_METATILES(gMetatiles_SeashoreHouse, gMetatileAttributes_SeashoreHouse),
    .callback = NULL,
};

const struct Tileset gTileset_PrettyPetalFlowerShop =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PrettyPetalFlowerShop,
    .palettes = gTilesetPalettes_PrettyPetalFlowerShop,
    TILESET_METATILES(gMetatiles_PrettyPetalFlowerShop, gMetatileAttributes_PrettyPetalFlowerShop),
    .callback = NULL,
};

const struct Tileset gTileset_PokemonDayCare =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PokemonDayCare,
    .palettes = gTilesetPalettes_PokemonDayCare,
    TILESET_METATILES(gMetatiles_PokemonDayCare, gMetatileAttributes_PokemonDayCare),
    .callback = NULL,
};

const struct Tileset gTileset_Facility =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Facility,
    .palettes = gTilesetPalettes_Facility,
    TILESET_METATILES(gMetatiles_Facility, gMetatileAttributes_Facility),
    .callback = NULL,
};

const struct Tileset gTileset_BikeShop =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BikeShop,
    .palettes = gTilesetPalettes_BikeShop,
    TILESET_METATILES(gMetatiles_BikeShop, gMetatileAttributes_BikeShop),
    .callback = InitTilesetAnim_BikeShop,
};

const struct Tileset gTileset_RusturfTunnel =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_RusturfTunnel,
    .palettes = gTilesetPalettes_RusturfTunnel,
    TILESET_METATILES(gMetatiles_RusturfTunnel, gMetatileAttributes_RusturfTunnel),
    .callback = NULL,
};

const struct Tileset gTileset_SecretBaseBrownCave =
{
    .isCompressed = FALSE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SecretBaseBrownCave,
    .palettes = gTilesetPalettes_SecretBaseBrownCave,
    TILESET_METATILES(gMetatiles_SecretBaseSecondary, gMetatileAttributes_SecretBaseSecondary),
    .callback = NULL,
};

const struct Tileset gTileset_SecretBaseTree =
{
    .isCompressed = FALSE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SecretBaseTree,
    .palettes = gTilesetPalettes_SecretBaseTree,
    TILESET_METATILES(gMetatiles_SecretBaseSecondary, gMetatileAttributes_SecretBaseSecondary),
    .callback = NULL,
};

const struct Tileset gTileset_SecretBaseShrub =
{
    .isCompressed = FALSE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SecretBaseShrub,
    .palettes = gTilesetPalettes_SecretBaseShrub,
    TILESET_METATILES(gMetatiles_SecretBaseSecondary, gMetatileAttributes_SecretBaseSecondary),
    .callback = NULL,
};

const struct Tileset gTileset_SecretBaseBlueCave =
{
    .isCompressed = FALSE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SecretBaseBlueCave,
    .palettes = gTilesetPalettes_SecretBaseBlueCave,
    TILESET_METATILES(gMetatiles_SecretBaseSecondary, gMetatileAttributes_SecretBaseSecondary),
    .callback = NULL,
};

const struct Tileset gTileset_SecretBaseYellowCave =
{
    .isCompressed = FALSE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SecretBaseYellowCave,
    .palettes = gTilesetPalettes_SecretBaseYellowCave,
    TILESET_METATILES(gMetatiles_SecretBaseSecondary, gMetatileAttributes_SecretBaseSecondary),
    .callback = NULL,
};

const struct Tileset gTileset_InsideOfTruck =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_InsideOfTruck,
    .palettes = gTilesetPalettes_InsideOfTruck,
    TILESET_METATILES(gMetatiles_InsideOfTruck, gMetatileAttributes_InsideOfTruck),
    .callback = NULL,
};

const struct Tileset gTileset_Unused2 =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Unused2,
    .palettes = gTilesetPalettes_Unused2,
    TILESET_METATILES(gMetatiles_Unused2, gMetatileAttributes_Unused2),
    .callback = NULL,
};

const struct Tileset gTileset_Contest =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Contest,
    .palettes = gTilesetPalettes_Contest,
    TILESET_METATILES(gMetatiles_Contest, gMetatileAttributes_Contest),
    .callback = NULL,
};

const struct Tileset gTileset_LilycoveMuseum =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_LilycoveMuseum,
    .palettes = gTilesetPalettes_LilycoveMuseum,
    TILESET_METATILES(gMetatiles_LilycoveMuseum, gMetatileAttributes_LilycoveMuseum),
    .callback = NULL,
};

const struct Tileset gTileset_BrendansMaysHouse =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BrendansMaysHouse,
    .palettes = gTilesetPalettes_BrendansMaysHouse,
    TILESET_METATILES(gMetatiles_BrendansMaysHouse, gMetatileAttributes_BrendansMaysHouse),
    .callback = NULL,
};

const struct Tileset gTileset_Lab =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Lab,
    .palettes = gTilesetPalettes_Lab,
    TILESET_METATILES(gMetatiles_Lab, gMetatileAttributes_Lab),
    .callback = NULL,
};

const struct Tileset gTileset_Underwater =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Underwater,
    .palettes = gTilesetPalettes_Underwater,
    TILESET_METATILES(gMetatiles_Underwater, gMetatileAttributes_Underwater),
    .callback = InitTilesetAnim_Underwater,
};

const struct Tileset gTileset_PetalburgGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PetalburgGym,
    .palettes = gTilesetPalettes_PetalburgGym,
    TILESET_METATILES(gMetatiles_PetalburgGym, gMetatileAttributes_PetalburgGym),
    .callback = NULL,
};

const struct Tileset gTileset_SootopolisGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SootopolisGym,
    .palettes = gTilesetPalettes_SootopolisGym,
    TILESET_METATILES(gMetatiles_SootopolisGym, gMetatileAttributes_SootopolisGym),
    .callback = InitTilesetAnim_SootopolisGym,
};

const struct Tileset gTileset_GenericBuilding =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_GenericBuilding,
    .palettes = gTilesetPalettes_GenericBuilding,
    TILESET_METATILES(gMetatiles_GenericBuilding, gMetatileAttributes_GenericBuilding),
    .callback = NULL,
};

const struct Tileset gTileset_MauvilleGameCorner =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_MauvilleGameCorner,
    .palettes = gTilesetPalettes_MauvilleGameCorner,
    TILESET_METATILES(gMetatiles_MauvilleGameCorner, gMetatileAttributes_MauvilleGameCorner),
    .callback = NULL,
};

const struct Tileset gTileset_RustboroGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_RustboroGym,
    .palettes = gTilesetPalettes_RustboroGym,
    TILESET_METATILES(gMetatiles_RustboroGym, gMetatileAttributes_RustboroGym),
    .callback = NULL,
};

const struct Tileset gTileset_DewfordGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_DewfordGym,
    .palettes = gTilesetPalettes_DewfordGym,
    TILESET_METATILES(gMetatiles_DewfordGym, gMetatileAttributes_DewfordGym),
    .callback = NULL,
};

const struct Tileset gTileset_MauvilleGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_MauvilleGym,
    .palettes = gTilesetPalettes_MauvilleGym,
    TILESET_METATILES(gMetatiles_MauvilleGym, gMetatileAttributes_MauvilleGym),
    .callback = InitTilesetAnim_MauvilleGym,
};

const struct Tileset gTileset_LavaridgeGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_LavaridgeGym,
    .palettes = gTilesetPalettes_LavaridgeGym,
    TILESET_METATILES(gMetatiles_LavaridgeGym, gMetatileAttributes_LavaridgeGym),
    .callback = NULL,
};

const struct Tileset gTileset_TrickHousePuzzle =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_TrickHousePuzzle,
    .palettes = gTilesetPalettes_TrickHousePuzzle,
    TILESET_METATILES(gMetatiles_TrickHousePuzzle, gMetatileAttributes_TrickHousePuzzle),
    .callback = NULL,
};

const struct Tileset gTileset_FortreeGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_FortreeGym,
    .palettes = gTilesetPalettes_FortreeGym,
    TILESET_METATILES(gMetatiles_FortreeGym, gMetatileAttributes_FortreeGym),
    .callback = NULL,
};

const struct Tileset gTileset_MossdeepGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_MossdeepGym,
    .palettes = gTilesetPalettes_MossdeepGym,
    TILESET_METATILES(gMetatiles_MossdeepGym, gMetatileAttributes_MossdeepGym),
    .callback = NULL,
};

const struct Tileset gTileset_InsideShip =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_InsideShip,
    .palettes = gTilesetPalettes_InsideShip,
    TILESET_METATILES(gMetatiles_InsideShip, gMetatileAttributes_InsideShip),
    .callback = NULL,
};

const struct Tileset gTileset_EliteFour =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_EliteFour,
    .palettes = gTilesetPalettes_EliteFour,
    TILESET_METATILES(gMetatiles_EliteFour, gMetatileAttributes_EliteFour),
    .callback = InitTilesetAnim_EliteFour,
};

const struct Tileset gTileset_BattleFrontier =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BattleFrontier,
    .palettes = gTilesetPalettes_BattleFrontier,
    TILESET_METATILES(gMetatiles_BattleFrontier, gMetatileAttributes_BattleFrontier),
    .callback = NULL,
};

const struct Tileset gTileset_BattlePalace =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BattlePalace,
    .palettes = gTilesetPalettes_BattlePalace,
    TILESET_METATILES(gMetatiles_BattlePalace, gMetatileAttributes_BattlePalace),
    .callback = NULL,
};

const struct Tileset gTileset_BattleDome =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BattleDome,
    .palettes = gTilesetPalettes_BattleDome,
    TILESET_METATILES(gMetatiles_BattleDome, gMetatileAttributes_BattleDome),
    .callback = InitTilesetAnim_BattleDome,
};

const struct Tileset gTileset_BattleFactory =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BattleFactory,
    .palettes = gTilesetPalettes_BattleFactory,
    TILESET_METATILES(gMetatiles_BattleFactory, gMetatileAttributes_BattleFactory),
    .callback = NULL,
};

const struct Tileset gTileset_BattlePike =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BattlePike,
    .palettes = gTilesetPalettes_BattlePike,
    TILESET_METATILES(gMetatiles_BattlePike, gMetatileAttributes_BattlePike),
    .callback = NULL,
};

const struct Tileset gTileset_BattleArena =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BattleArena,
    .palettes = gTilesetPalettes_BattleArena,
    TILESET_METATILES(gMetatiles_BattleArena, gMetatileAttributes_BattleArena),
    .callback = NULL,
};

const struct Tileset gTileset_BattlePyramid =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BattlePyramid,
    .palettes = gTilesetPalettes_BattlePyramid,
    TILESET_METATILES(gMetatiles_BattlePyramid, gMetatileAttributes_BattlePyramid),
    .callback = InitTilesetAnim_BattlePyramid,
};

const struct Tileset gTileset_MirageTower =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_MirageTower,
    .palettes = gTilesetPalettes_MirageTower,
    TILESET_METATILES(gMetatiles_MirageTower, gMetatileAttributes_MirageTower),
    .callback = NULL,
};

const struct Tileset gTileset_MossdeepGameCorner =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_MossdeepGameCorner,
    .palettes = gTilesetPalettes_MossdeepGameCorner,
    TILESET_METATILES(gMetatiles_MossdeepGameCorner, gMetatileAttributes_MossdeepGameCorner),
    .callback = NULL,
};

const struct Tileset gTileset_IslandHarbor =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_IslandHarbor,
    .palettes = gTilesetPalettes_IslandHarbor,
    TILESET_METATILES(gMetatiles_IslandHarbor, gMetatileAttributes_IslandHarbor),
    .callback = NULL,
};

const struct Tileset gTileset_TrainerHill =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_TrainerHill,
    .palettes = gTilesetPalettes_TrainerHill,
    TILESET_METATILES(gMetatiles_TrainerHill, gMetatileAttributes_TrainerHill),
    .callback = NULL,
};

const struct Tileset gTileset_NavelRock =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_NavelRock,
    .palettes = gTilesetPalettes_NavelRock,
    TILESET_METATILES(gMetatiles_NavelRock, gMetatileAttributes_NavelRock),
    .callback = NULL,
};

const struct Tileset gTileset_BattleFrontierRankingHall =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BattleFrontierRankingHall,
    .palettes = gTilesetPalettes_BattleFrontierRankingHall,
    TILESET_METATILES(gMetatiles_BattleFrontierRankingHall, gMetatileAttributes_BattleFrontierRankingHall),
    .callback = NULL,
};

const struct Tileset gTileset_BattleTent =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BattleTent,
    .palettes = gTilesetPalettes_BattleTent,
    TILESET_METATILES(gMetatiles_BattleTent, gMetatileAttributes_BattleTent),
    .callback = NULL,
};

const struct Tileset gTileset_MysteryEventsHouse =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_MysteryEventsHouse,
    .palettes = gTilesetPalettes_MysteryEventsHouse,
    TILESET_METATILES(gMetatiles_MysteryEventsHouse, gMetatileAttributes_MysteryEventsHouse),
    .callback = NULL,
};

const struct Tileset gTileset_UnionRoom =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_UnionRoom,
    .palettes = gTilesetPalettes_UnionRoom,
    TILESET_METATILES(gMetatiles_UnionRoom, gMetatileAttributes_UnionRoom),
    .callback = NULL,
};

#endif // !IS_FRLG (Hoenn)

#if IS_FRLG || ALL_REGIONS

// FRLG tilesets
const struct Tileset gTileset_BuildingFrlg =
{
    .isCompressed = TRUE,
    .isSecondary = FALSE,
    .tiles = gTilesetTiles_Building_Frlg,
    .palettes = gTilesetPalettes_Building_Frlg,
    TILESET_METATILES(gMetatiles_Building_Frlg, gMetatileAttributes_Building_Frlg),
    .callback = NULL,
};

const struct Tileset gTileset_General_Frlg =
{
    .isCompressed = TRUE,
    .isSecondary = FALSE,
    .tiles = gTilesetTiles_General_Frlg,
    .palettes = gTilesetPalettes_General_Frlg,
    TILESET_METATILES(gMetatiles_General_Frlg, gMetatileAttributes_General_Frlg),
    .callback = InitTilesetAnim_General_Frlg,
};

const struct Tileset gTileset_PalletTown =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PalletTown,
    .palettes = gTilesetPalettes_PalletTown,
    TILESET_METATILES(gMetatiles_PalletTown, gMetatileAttributes_PalletTown),
    .callback = NULL,
};

const struct Tileset gTileset_ViridianCity =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_ViridianCity,
    .palettes = gTilesetPalettes_ViridianCity,
    TILESET_METATILES(gMetatiles_ViridianCity, gMetatileAttributes_ViridianCity),
    .callback = NULL,
};

const struct Tileset gTileset_PewterCity =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PewterCity,
    .palettes = gTilesetPalettes_PewterCity,
    TILESET_METATILES(gMetatiles_PewterCity, gMetatileAttributes_PewterCity),
    .callback = NULL,
};

const struct Tileset gTileset_CeruleanCity =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_CeruleanCity,
    .palettes = gTilesetPalettes_CeruleanCity,
    TILESET_METATILES(gMetatiles_CeruleanCity, gMetatileAttributes_CeruleanCity),
    .callback = NULL,
};

const struct Tileset gTileset_LavenderTown =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_LavenderTown,
    .palettes = gTilesetPalettes_LavenderTown,
    TILESET_METATILES(gMetatiles_LavenderTown, gMetatileAttributes_LavenderTown),
    .callback = NULL,
};

const struct Tileset gTileset_VermilionCity =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_VermilionCity,
    .palettes = gTilesetPalettes_VermilionCity,
    TILESET_METATILES(gMetatiles_VermilionCity, gMetatileAttributes_VermilionCity),
    .callback = NULL,
};

const struct Tileset gTileset_CeladonCity =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_CeladonCity,
    .palettes = gTilesetPalettes_CeladonCity,
    TILESET_METATILES(gMetatiles_CeladonCity, gMetatileAttributes_CeladonCity),
    .callback = InitTilesetAnim_CeladonCity,
};

const struct Tileset gTileset_FuchsiaCity =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_FuchsiaCity,
    .palettes = gTilesetPalettes_FuchsiaCity,
    TILESET_METATILES(gMetatiles_FuchsiaCity, gMetatileAttributes_FuchsiaCity),
    .callback = NULL,
};

const struct Tileset gTileset_CinnabarIsland =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_CinnabarIsland,
    .palettes = gTilesetPalettes_CinnabarIsland,
    TILESET_METATILES(gMetatiles_CinnabarIsland, gMetatileAttributes_CinnabarIsland),
    .callback = NULL,
};

const struct Tileset gTileset_IndigoPlateau =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_IndigoPlateau,
    .palettes = gTilesetPalettes_IndigoPlateau,
    TILESET_METATILES(gMetatiles_IndigoPlateau, gMetatileAttributes_IndigoPlateau),
    .callback = NULL,
};

const struct Tileset gTileset_SaffronCity =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SaffronCity,
    .palettes = gTilesetPalettes_SaffronCity,
    TILESET_METATILES(gMetatiles_SaffronCity, gMetatileAttributes_SaffronCity),
    .callback = NULL,
};

const struct Tileset gTileset_Mart =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Mart,
    .palettes = gTilesetPalettes_Mart,
    TILESET_METATILES(gMetatiles_Mart, gMetatileAttributes_Mart),
    .callback = NULL,
};

const struct Tileset gTileset_PokemonCenterFrlg =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PokemonCenter_Frlg,
    .palettes = gTilesetPalettes_PokemonCenter_Frlg,
    TILESET_METATILES(gMetatiles_PokemonCenter_Frlg, gMetatileAttributes_PokemonCenter_Frlg),
    .callback = NULL,
};

const struct Tileset gTileset_Cave_Frlg =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Cave_Frlg,
    .palettes = gTilesetPalettes_Cave_Frlg,
    TILESET_METATILES(gMetatiles_Cave_Frlg, gMetatileAttributes_Cave_Frlg),
    .callback = NULL,
};

const struct Tileset gTileset_Museum =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Museum,
    .palettes = gTilesetPalettes_Museum,
    TILESET_METATILES(gMetatiles_Museum, gMetatileAttributes_Museum),
    .callback = NULL,
};

const struct Tileset gTileset_CableClub_Frlg =
{
    .isCompressed = FALSE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_CableClub_Frlg,
    .palettes = gTilesetPalettes_CableClub_Frlg,
    TILESET_METATILES(gMetatiles_CableClub_Frlg, gMetatileAttributes_CableClub_Frlg),
    .callback = NULL,
};

const struct Tileset gTileset_BikeShop_Frlg =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BikeShop_Frlg,
    .palettes = gTilesetPalettes_BikeShop_Frlg,
    TILESET_METATILES(gMetatiles_BikeShop_Frlg, gMetatileAttributes_BikeShop_Frlg),
    .callback = NULL,
};

const struct Tileset gTileset_GenericBuilding1 =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_GenericBuilding1,
    .palettes = gTilesetPalettes_GenericBuilding1,
    TILESET_METATILES(gMetatiles_GenericBuilding1, gMetatileAttributes_GenericBuilding1),
    .callback = NULL,
};

const struct Tileset gTileset_Lab_Frlg =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Lab_Frlg,
    .palettes = gTilesetPalettes_Lab_Frlg,
    TILESET_METATILES(gMetatiles_Lab_Frlg, gMetatileAttributes_Lab_Frlg),
    .callback = NULL,
};

const struct Tileset gTileset_FuchsiaGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_FuchsiaGym,
    .palettes = gTilesetPalettes_FuchsiaGym,
    TILESET_METATILES(gMetatiles_FuchsiaGym, gMetatileAttributes_FuchsiaGym),
    .callback = NULL,
};

const struct Tileset gTileset_ViridianGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_ViridianGym,
    .palettes = gTilesetPalettes_ViridianGym,
    TILESET_METATILES(gMetatiles_ViridianGym, gMetatileAttributes_ViridianGym),
    .callback = NULL,
};

const struct Tileset gTileset_HoennBuilding =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_HoennBuilding,
    .palettes = gTilesetPalettes_HoennBuilding,
    TILESET_METATILES(gMetatiles_HoennBuilding, gMetatileAttributes_HoennBuilding),
    .callback = NULL,
};

const struct Tileset gTileset_GameCorner =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_GameCorner,
    .palettes = gTilesetPalettes_GameCorner,
    TILESET_METATILES(gMetatiles_GameCorner, gMetatileAttributes_GameCorner),
    .callback = NULL,
};

const struct Tileset gTileset_PewterGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PewterGym,
    .palettes = gTilesetPalettes_PewterGym,
    TILESET_METATILES(gMetatiles_PewterGym, gMetatileAttributes_PewterGym),
    .callback = NULL,
};

const struct Tileset gTileset_CeruleanGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_CeruleanGym,
    .palettes = gTilesetPalettes_CeruleanGym,
    TILESET_METATILES(gMetatiles_CeruleanGym, gMetatileAttributes_CeruleanGym),
    .callback = NULL,
};

const struct Tileset gTileset_VermilionGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_VermilionGym,
    .palettes = gTilesetPalettes_VermilionGym,
    TILESET_METATILES(gMetatiles_VermilionGym, gMetatileAttributes_VermilionGym),
    .callback = InitTilesetAnim_VermilionGym,
};

const struct Tileset gTileset_CeladonGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_CeladonGym,
    .palettes = gTilesetPalettes_CeladonGym,
    TILESET_METATILES(gMetatiles_CeladonGym, gMetatileAttributes_CeladonGym),
    .callback = InitTilesetAnim_CeladonGym,
};

const struct Tileset gTileset_SaffronGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SaffronGym,
    .palettes = gTilesetPalettes_SaffronGym,
    TILESET_METATILES(gMetatiles_SaffronGym, gMetatileAttributes_SaffronGym),
    .callback = NULL,
};

const struct Tileset gTileset_CinnabarGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_CinnabarGym,
    .palettes = gTilesetPalettes_CinnabarGym,
    TILESET_METATILES(gMetatiles_CinnabarGym, gMetatileAttributes_CinnabarGym),
    .callback = NULL,
};

const struct Tileset gTileset_SSAnne =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SSAnne,
    .palettes = gTilesetPalettes_SSAnne,
    TILESET_METATILES(gMetatiles_SSAnne, gMetatileAttributes_SSAnne),
    .callback = NULL,
};

const struct Tileset gTileset_ViridianForest =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_ViridianForest,
    .palettes = gTilesetPalettes_ViridianForest,
    TILESET_METATILES(gMetatiles_ViridianForest, gMetatileAttributes_ViridianForest),
    .callback = NULL,
};

const struct Tileset gTileset_UnusedGatehouse1 =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_UnusedGatehouse1,
    .palettes = gTilesetPalettes_UnusedGatehouse1,
    TILESET_METATILES(gMetatiles_UnusedGatehouse1, gMetatileAttributes_UnusedGatehouse1),
    .callback = NULL,
};

const struct Tileset gTileset_RockTunnel =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_RockTunnel,
    .palettes = gTilesetPalettes_RockTunnel,
    TILESET_METATILES(gMetatiles_RockTunnel, gMetatileAttributes_RockTunnel),
    .callback = NULL,
};

const struct Tileset gTileset_DiglettsCave =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_DiglettsCave,
    .palettes = gTilesetPalettes_DiglettsCave,
    TILESET_METATILES(gMetatiles_DiglettsCave, gMetatileAttributes_DiglettsCave),
    .callback = NULL,
};

const struct Tileset gTileset_SeafoamIslands =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SeafoamIslands,
    .palettes = gTilesetPalettes_SeafoamIslands,
    TILESET_METATILES(gMetatiles_SeafoamIslands, gMetatileAttributes_SeafoamIslands),
    .callback = NULL,
};

const struct Tileset gTileset_UnusedGatehouse2 =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_UnusedGatehouse2,
    .palettes = gTilesetPalettes_UnusedGatehouse2,
    TILESET_METATILES(gMetatiles_UnusedGatehouse2, gMetatileAttributes_UnusedGatehouse2),
    .callback = NULL,
};

const struct Tileset gTileset_CeruleanCave =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_CeruleanCave,
    .palettes = gTilesetPalettes_CeruleanCave,
    TILESET_METATILES(gMetatiles_CeruleanCave, gMetatileAttributes_CeruleanCave),
    .callback = NULL,
};

const struct Tileset gTileset_DepartmentStore =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_DepartmentStore,
    .palettes = gTilesetPalettes_DepartmentStore,
    TILESET_METATILES(gMetatiles_DepartmentStore, gMetatileAttributes_DepartmentStore),
    .callback = NULL,
};

const struct Tileset gTileset_GenericBuilding2 =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_GenericBuilding2,
    .palettes = gTilesetPalettes_GenericBuilding2,
    TILESET_METATILES(gMetatiles_GenericBuilding2, gMetatileAttributes_GenericBuilding2),
    .callback = NULL,
};

const struct Tileset gTileset_PowerPlant =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PowerPlant,
    .palettes = gTilesetPalettes_PowerPlant,
    TILESET_METATILES(gMetatiles_PowerPlant, gMetatileAttributes_PowerPlant),
    .callback = NULL,
};

const struct Tileset gTileset_SeaCottage =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SeaCottage,
    .palettes = gTilesetPalettes_SeaCottage,
    TILESET_METATILES(gMetatiles_SeaCottage, gMetatileAttributes_SeaCottage),
    .callback = NULL,
};

const struct Tileset gTileset_SilphCo =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Condominiums,
    .palettes = gTilesetPalettes_Condominiums,
    TILESET_METATILES(gMetatiles_SilphCo, gMetatileAttributes_SilphCo),
    .callback = InitTilesetAnim_SilphCo,
};

const struct Tileset gTileset_UndergroundPath =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_UndergroundPath,
    .palettes = gTilesetPalettes_UndergroundPath,
    TILESET_METATILES(gMetatiles_UndergroundPath, gMetatileAttributes_UndergroundPath),
    .callback = NULL,
};

const struct Tileset gTileset_PokemonTower =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PokemonTower,
    .palettes = gTilesetPalettes_PokemonTower,
    TILESET_METATILES(gMetatiles_PokemonTower, gMetatileAttributes_PokemonTower),
    .callback = NULL,
};

const struct Tileset gTileset_SafariZoneBuilding =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SafariZoneBuilding,
    .palettes = gTilesetPalettes_SafariZoneBuilding,
    TILESET_METATILES(gMetatiles_SafariZoneBuilding, gMetatileAttributes_SafariZoneBuilding),
    .callback = NULL,
};

const struct Tileset gTileset_PokemonMansion =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PokemonMansion,
    .palettes = gTilesetPalettes_PokemonMansion,
    TILESET_METATILES(gMetatiles_PokemonMansion, gMetatileAttributes_PokemonMansion),
    .callback = NULL,
};

const struct Tileset gTileset_RestaurantHotel =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_RestaurantHotel,
    .palettes = gTilesetPalettes_RestaurantHotel,
    TILESET_METATILES(gMetatiles_RestaurantHotel, gMetatileAttributes_RestaurantHotel),
    .callback = NULL,
};

const struct Tileset gTileset_School =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_School,
    .palettes = gTilesetPalettes_School,
    TILESET_METATILES(gMetatiles_School, gMetatileAttributes_School),
    .callback = NULL,
};

const struct Tileset gTileset_FanClubDaycare =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_FanClubDaycare,
    .palettes = gTilesetPalettes_FanClubDaycare,
    TILESET_METATILES(gMetatiles_FanClubDaycare, gMetatileAttributes_FanClubDaycare),
    .callback = NULL,
};

const struct Tileset gTileset_Condominiums =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Condominiums,
    .palettes = gTilesetPalettes_Condominiums,
    TILESET_METATILES(gMetatiles_Condominiums, gMetatileAttributes_Condominiums),
    .callback = NULL,
};

const struct Tileset gTileset_BurgledHouse =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BurgledHouse,
    .palettes = gTilesetPalettes_BurgledHouse,
    TILESET_METATILES(gMetatiles_BurgledHouse, gMetatileAttributes_BurgledHouse),
    .callback = NULL,
};

const struct Tileset gTileset_MtEmber =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_MtEmber,
    .palettes = gTilesetPalettes_MtEmber,
    TILESET_METATILES(gMetatiles_MtEmber, gMetatileAttributes_MtEmber),
    .callback = InitTilesetAnim_MtEmber,
};

const struct Tileset gTileset_BerryForest =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BerryForest,
    .palettes = gTilesetPalettes_BerryForest,
    TILESET_METATILES(gMetatiles_BerryForest, gMetatileAttributes_BerryForest),
    .callback = NULL,
};

const struct Tileset gTileset_NavelRock_Frlg =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_NavelRock_Frlg,
    .palettes = gTilesetPalettes_NavelRock_Frlg,
    TILESET_METATILES(gMetatiles_NavelRock_Frlg, gMetatileAttributes_NavelRock_Frlg),
    .callback = NULL,
};

const struct Tileset gTileset_TanobyRuins =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_TanobyRuins,
    .palettes = gTilesetPalettes_TanobyRuins,
    TILESET_METATILES(gMetatiles_TanobyRuins, gMetatileAttributes_TanobyRuins),
    .callback = NULL,
};

const struct Tileset gTileset_SeviiIslands123 =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SeviiIslands123,
    .palettes = gTilesetPalettes_SeviiIslands123,
    TILESET_METATILES(gMetatiles_SeviiIslands123, gMetatileAttributes_SeviiIslands123),
    .callback = NULL,
};

const struct Tileset gTileset_SeviiIslands45 =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SeviiIslands45,
    .palettes = gTilesetPalettes_SeviiIslands45,
    TILESET_METATILES(gMetatiles_SeviiIslands45, gMetatileAttributes_SeviiIslands45),
    .callback = NULL,
};

const struct Tileset gTileset_SeviiIslands67 =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SeviiIslands67,
    .palettes = gTilesetPalettes_SeviiIslands67,
    TILESET_METATILES(gMetatiles_SeviiIslands67, gMetatileAttributes_SeviiIslands67),
    .callback = NULL,
};

const struct Tileset gTileset_TrainerTower =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_TrainerTower,
    .palettes = gTilesetPalettes_TrainerTower,
    TILESET_METATILES(gMetatiles_TrainerTower, gMetatileAttributes_TrainerTower),
    .callback = NULL,
};

const struct Tileset gTileset_IslandHarbor_Frlg =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_IslandHarbor_Frlg,
    .palettes = gTilesetPalettes_IslandHarbor_Frlg,
    TILESET_METATILES(gMetatiles_IslandHarbor_Frlg, gMetatileAttributes_IslandHarbor_Frlg),
    .callback = NULL,
};

const struct Tileset gTileset_PokemonLeague =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PokemonLeague,
    .palettes = gTilesetPalettes_PokemonLeague,
    TILESET_METATILES(gMetatiles_PokemonLeague, gMetatileAttributes_PokemonLeague),
    .callback = NULL,
};

const struct Tileset gTileset_HallOfFame =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_HallOfFame,
    .palettes = gTilesetPalettes_HallOfFame,
    TILESET_METATILES(gMetatiles_HallOfFame, gMetatileAttributes_HallOfFame),
    .callback = NULL,
};

#endif // IS_FRLG || ALL_REGIONS (FRLG)

// === Region merge: Johto starting-area slice tilesets (always-on) ===
const struct Tileset gTileset_Johto_General =
{
    .isCompressed = TRUE,
    .isSecondary = FALSE,
    .tiles = gTilesetTiles_Johto_General,
    .palettes = gTilesetPalettes_Johto_General,
    TILESET_METATILES(gMetatiles_Johto_General, gMetatileAttributes_Johto_General),
    .callback = InitTilesetAnim_JohtoGeneral,
};

const struct Tileset gTileset_Johto_Building =
{
    .isCompressed = TRUE,
    .isSecondary = FALSE,
    .tiles = gTilesetTiles_Johto_Building,
    .palettes = gTilesetPalettes_Johto_Building,
    TILESET_METATILES(gMetatiles_Johto_Building, gMetatileAttributes_Johto_Building),
    .callback = NULL,
};

const struct Tileset gTileset_NewBarkTown =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_NewBarkTown,
    .palettes = gTilesetPalettes_NewBarkTown,
    TILESET_METATILES(gMetatiles_NewBarkTown, gMetatileAttributes_NewBarkTown),
    .callback = NULL,
};

const struct Tileset gTileset_CherrygroveCity =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_CherrygroveCity,
    .palettes = gTilesetPalettes_CherrygroveCity,
    TILESET_METATILES(gMetatiles_CherrygroveCity, gMetatileAttributes_CherrygroveCity),
    .callback = NULL,
};

const struct Tileset gTileset_Kanto_PokemonCenter =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Kanto_PokemonCenter,
    .palettes = gTilesetPalettes_Kanto_PokemonCenter,
    TILESET_METATILES(gMetatiles_Kanto_PokemonCenter, gMetatileAttributes_Kanto_PokemonCenter),
    .callback = NULL,
};

const struct Tileset gTileset_JohtoMart =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_JohtoMart,
    .palettes = gTilesetPalettes_JohtoMart,
    TILESET_METATILES(gMetatiles_JohtoMart, gMetatileAttributes_JohtoMart),
    .callback = NULL,
};

const struct Tileset gTileset_House_Lab =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_House_Lab,
    .palettes = gTilesetPalettes_House_Lab,
    TILESET_METATILES(gMetatiles_House_Lab, gMetatileAttributes_House_Lab),
    .callback = NULL,
};

const struct Tileset gTileset_PlayersHouse =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PlayersHouse,
    .palettes = gTilesetPalettes_PlayersHouse,
    TILESET_METATILES(gMetatiles_PlayersHouse, gMetatileAttributes_PlayersHouse),
    .callback = NULL,
};

// === Region merge: Johto Violet-area tilesets ===
const struct Tileset gTileset_Johto_NorthEast =
{
    .isCompressed = TRUE,
    .isSecondary = FALSE,
    .tiles = gTilesetTiles_Johto_NorthEast,
    .palettes = gTilesetPalettes_Johto_NorthEast,
    TILESET_METATILES(gMetatiles_Johto_NorthEast, gMetatileAttributes_Johto_NorthEast),
    .callback = InitTilesetAnim_JohtoGeneral,
};

const struct Tileset gTileset_Gate_Standard =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Gate_Standard,
    .palettes = gTilesetPalettes_Gate_Standard,
    TILESET_METATILES(gMetatiles_Gate_Standard, gMetatileAttributes_Gate_Standard),
    .callback = NULL,
};

const struct Tileset gTileset_Route32 =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Route32,
    .palettes = gTilesetPalettes_Route32,
    TILESET_METATILES(gMetatiles_Route32, gMetatileAttributes_Route32),
    .callback = NULL,
};

const struct Tileset gTileset_RuinsOfAlph_B1F =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_RuinsOfAlph_B1F,
    .palettes = gTilesetPalettes_RuinsOfAlph_B1F,
    TILESET_METATILES(gMetatiles_RuinsOfAlph_B1F, gMetatileAttributes_RuinsOfAlph_B1F),
    .callback = NULL,
};

const struct Tileset gTileset_RuinsOfAlph_Outside =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_RuinsOfAlph_Outside,
    .palettes = gTilesetPalettes_RuinsOfAlph_Outside,
    TILESET_METATILES(gMetatiles_RuinsOfAlph_Outside, gMetatileAttributes_RuinsOfAlph_Outside),
    .callback = NULL,
};

const struct Tileset gTileset_RuinsOfAlphWriting =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_RuinsOfAlphWriting,
    .palettes = gTilesetPalettes_RuinsOfAlphWriting,
    TILESET_METATILES(gMetatiles_RuinsOfAlphWriting, gMetatileAttributes_RuinsOfAlphWriting),
    .callback = NULL,
};

const struct Tileset gTileset_PowerPlant_GeneratorRoom =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PowerPlant_GeneratorRoom,
    .palettes = gTilesetPalettes_PowerPlant_GeneratorRoom,
    TILESET_METATILES(gMetatiles_PowerPlant_GeneratorRoom, gMetatileAttributes_PowerPlant_GeneratorRoom),
    .callback = NULL,
};

const struct Tileset gTileset_VioletCity =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_VioletCity,
    .palettes = gTilesetPalettes_VioletCity,
    TILESET_METATILES(gMetatiles_VioletCity, gMetatileAttributes_VioletCity),
    .callback = NULL,
};

const struct Tileset gTileset_EcruteakTheater =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_EcruteakTheater,
    .palettes = gTilesetPalettes_EcruteakTheater,
    TILESET_METATILES(gMetatiles_EcruteakTheater, gMetatileAttributes_EcruteakTheater),
    .callback = InitTilesetAnim_EcruteakTheater,
};

const struct Tileset gTileset_TrainerSchool =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_TrainerSchool,
    .palettes = gTilesetPalettes_TrainerSchool,
    TILESET_METATILES(gMetatiles_TrainerSchool, gMetatileAttributes_TrainerSchool),
    .callback = NULL,
};



// === Region merge: Johto Azalea-area tilesets ===
const struct Tileset gTileset_Johto_South =
{
    .isCompressed = TRUE,
    .isSecondary = FALSE,
    .tiles = gTilesetTiles_Johto_South,
    .palettes = gTilesetPalettes_Johto_South,
    TILESET_METATILES(gMetatiles_Johto_South, gMetatileAttributes_Johto_South),
    .callback = InitTilesetAnim_JohtoGeneral,
};

const struct Tileset gTileset_AzaleaTown =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_AzaleaTown,
    .palettes = gTilesetPalettes_AzaleaTown,
    TILESET_METATILES(gMetatiles_AzaleaTown, gMetatileAttributes_AzaleaTown),
    .callback = NULL,
};

const struct Tileset gTileset_AzaleaTown_Gym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_AzaleaTown_Gym,
    .palettes = gTilesetPalettes_AzaleaTown_Gym,
    TILESET_METATILES(gMetatiles_AzaleaTown_Gym, gMetatileAttributes_AzaleaTown_Gym),
    .callback = InitTilesetAnim_AzaleaTownGym,
};

const struct Tileset gTileset_Barn =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Barn,
    .palettes = gTilesetPalettes_Barn,
    TILESET_METATILES(gMetatiles_Barn, gMetatileAttributes_Barn),
    .callback = NULL,
};

const struct Tileset gTileset_Cave_Default =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Cave_Default,
    .palettes = gTilesetPalettes_Cave_Default,
    TILESET_METATILES(gMetatiles_Cave_Default, gMetatileAttributes_Cave_Default),
    .callback = NULL,
};

const struct Tileset gTileset_Cave_Gray =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Cave_Gray,
    .palettes = gTilesetPalettes_Cave_Gray,
    TILESET_METATILES(gMetatiles_Cave_Gray, gMetatileAttributes_Cave_Gray),
    .callback = NULL,
};

const struct Tileset gTileset_Goldenrod =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Goldenrod,
    .palettes = gTilesetPalettes_Goldenrod,
    TILESET_METATILES(gMetatiles_Goldenrod, gMetatileAttributes_Goldenrod),
    .callback = InitTilesetAnim_Goldenrod,
};

const struct Tileset gTileset_IlexForest =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_IlexForest,
    .palettes = gTilesetPalettes_IlexForest,
    TILESET_METATILES(gMetatiles_IlexForest, gMetatileAttributes_IlexForest),
    .callback = NULL,
};

const struct Tileset gTileset_KurtsHouse =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_KurtsHouse,
    .palettes = gTilesetPalettes_KurtsHouse,
    TILESET_METATILES(gMetatiles_KurtsHouse, gMetatileAttributes_KurtsHouse),
    .callback = NULL,
};

// Region merge (Johto port): Goldenrod-area tilesets.
const struct Tileset gTileset_Cafe =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Cafe,
    .palettes = gTilesetPalettes_Cafe,
    TILESET_METATILES(gMetatiles_Cafe, gMetatileAttributes_Cafe),
    .callback = NULL,
};

const struct Tileset gTileset_GoldenrodDepartmentStore =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_GoldenrodDepartmentStore,
    .palettes = gTilesetPalettes_GoldenrodDepartmentStore,
    TILESET_METATILES(gMetatiles_GoldenrodDepartmentStore, gMetatileAttributes_GoldenrodDepartmentStore),
    .callback = NULL,
};

const struct Tileset gTileset_Ecruteak_City =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Ecruteak_City,
    .palettes = gTilesetPalettes_Ecruteak_City,
    TILESET_METATILES(gMetatiles_Ecruteak_City, gMetatileAttributes_Ecruteak_City),
    .callback = NULL,
};

const struct Tileset gTileset_GoldenrodGameCorner =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_GoldenrodGameCorner,
    .palettes = gTilesetPalettes_GoldenrodGameCorner,
    TILESET_METATILES(gMetatiles_GoldenrodGameCorner, gMetatileAttributes_GoldenrodGameCorner),
    .callback = NULL,
};

const struct Tileset gTileset_GoldenrodCity_TrainStation =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_GoldenrodCity_TrainStation,
    .palettes = gTilesetPalettes_GoldenrodCity_TrainStation,
    TILESET_METATILES(gMetatiles_GoldenrodCity_TrainStation, gMetatileAttributes_GoldenrodCity_TrainStation),
    .callback = NULL,
};

const struct Tileset gTileset_GoldenrodUndergroundRocket =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_GoldenrodUndergroundRocket,
    .palettes = gTilesetPalettes_GoldenrodUndergroundRocket,
    TILESET_METATILES(gMetatiles_GoldenrodUndergroundRocket, gMetatileAttributes_GoldenrodUndergroundRocket),
    .callback = NULL,
};

const struct Tileset gTileset_GoldenrodUndergroundTunnel =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_GoldenrodUndergroundTunnel,
    .palettes = gTilesetPalettes_GoldenrodUndergroundTunnel,
    TILESET_METATILES(gMetatiles_GoldenrodUndergroundTunnel, gMetatileAttributes_GoldenrodUndergroundTunnel),
    .callback = NULL,
};

const struct Tileset gTileset_Goldenrod_Underground_Storage =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Goldenrod_Underground_Storage,
    .palettes = gTilesetPalettes_Goldenrod_Underground_Storage,
    TILESET_METATILES(gMetatiles_Goldenrod_Underground_Storage, gMetatileAttributes_Goldenrod_Underground_Storage),
    .callback = NULL,
};

const struct Tileset gTileset_JohtoBikeShop =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_JohtoBikeShop,
    .palettes = gTilesetPalettes_JohtoBikeShop,
    TILESET_METATILES(gMetatiles_JohtoBikeShop, gMetatileAttributes_JohtoBikeShop),
    .callback = NULL,
};

const struct Tileset gTileset_NationalPark =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_NationalPark,
    .palettes = gTilesetPalettes_NationalPark,
    TILESET_METATILES(gMetatiles_NationalPark, gMetatileAttributes_NationalPark),
    .callback = InitTilesetAnim_NationalPark,
};

const struct Tileset gTileset_ShopRooftop =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_ShopRooftop,
    .palettes = gTilesetPalettes_ShopRooftop,
    TILESET_METATILES(gMetatiles_ShopRooftop, gMetatileAttributes_ShopRooftop),
    .callback = NULL,
};


// === Region merge: Johto Ecruteak-area tilesets ===
const struct Tileset gTileset_BellchimeTrail =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BellchimeTrail,
    .palettes = gTilesetPalettes_BellchimeTrail,
    TILESET_METATILES(gMetatiles_BellchimeTrail, gMetatileAttributes_BellchimeTrail),
    .callback = NULL,
};

const struct Tileset gTileset_BurnedTower =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BurnedTower,
    .palettes = gTilesetPalettes_BurnedTower,
    TILESET_METATILES(gMetatiles_BurnedTower, gMetatileAttributes_BurnedTower),
    .callback = NULL,
};

const struct Tileset gTileset_EcruteakCity_Gym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_EcruteakCity_Gym,
    .palettes = gTilesetPalettes_EcruteakCity_Gym,
    TILESET_METATILES(gMetatiles_EcruteakCity_Gym, gMetatileAttributes_EcruteakCity_Gym),
    .callback = NULL,
};

const struct Tileset gTileset_Route38_Farmland =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Route38_Farmland,
    .palettes = gTilesetPalettes_Route38_Farmland,
    TILESET_METATILES(gMetatiles_Route38_Farmland, gMetatileAttributes_Route38_Farmland),
    .callback = NULL,
};

const struct Tileset gTileset_Johto_NorthWest =
{
    .isCompressed = TRUE,
    .isSecondary = FALSE,
    .tiles = gTilesetTiles_Johto_NorthWest,
    .palettes = gTilesetPalettes_Johto_NorthWest,
    TILESET_METATILES(gMetatiles_Johto_NorthWest, gMetatileAttributes_Johto_NorthWest),
    .callback = InitTilesetAnim_JohtoGeneral,
};



// === Region merge: Johto Olivine-area tilesets ===
const struct Tileset gTileset_OlivineCity =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_OlivineCity,
    .palettes = gTilesetPalettes_OlivineCity,
    TILESET_METATILES(gMetatiles_OlivineCity, gMetatileAttributes_OlivineCity),
    .callback = NULL,
};

const struct Tileset gTileset_CianwoodCity =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_CianwoodCity,
    .palettes = gTilesetPalettes_CianwoodCity,
    TILESET_METATILES(gMetatiles_CianwoodCity, gMetatileAttributes_CianwoodCity),
    .callback = NULL,
};

const struct Tileset gTileset_WhirlIslands =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_WhirlIslands,
    .palettes = gTilesetPalettes_WhirlIslands,
    TILESET_METATILES(gMetatiles_WhirlIslands, gMetatileAttributes_WhirlIslands),
    .callback = NULL,
};

const struct Tileset gTileset_PortIndoor =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PortIndoor,
    .palettes = gTilesetPalettes_PortIndoor,
    TILESET_METATILES(gMetatiles_PortIndoor, gMetatileAttributes_PortIndoor),
    .callback = NULL,
};

const struct Tileset gTileset_Lighthouse =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Lighthouse,
    .palettes = gTilesetPalettes_Lighthouse,
    TILESET_METATILES(gMetatiles_Lighthouse, gMetatileAttributes_Lighthouse),
    .callback = NULL,
};

// === Region merge: Johto Cianwood-area tileset ===
const struct Tileset gTileset_CianwoodCity_Gym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_CianwoodCity_Gym,
    .palettes = gTilesetPalettes_CianwoodCity_Gym,
    TILESET_METATILES(gMetatiles_CianwoodCity_Gym, gMetatileAttributes_CianwoodCity_Gym),
    .callback = NULL,
};

// === Region merge: Johto Mahogany-area tilesets ===
const struct Tileset gTileset_MahoganyTown =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_MahoganyTown,
    .palettes = gTilesetPalettes_MahoganyTown,
    TILESET_METATILES(gMetatiles_MahoganyTown, gMetatileAttributes_MahoganyTown),
    .callback = NULL,
};

const struct Tileset gTileset_House_2 =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_House_2,
    .palettes = gTilesetPalettes_House_2,
    TILESET_METATILES(gMetatiles_House_2, gMetatileAttributes_House_2),
    .callback = NULL,
};


// === Region merge: Johto Blackthorn-area tilesets ===
const struct Tileset gTileset_Blackthorn =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Blackthorn,
    .palettes = gTilesetPalettes_Blackthorn,
    TILESET_METATILES(gMetatiles_Blackthorn, gMetatileAttributes_Blackthorn),
    .callback = NULL,
};

const struct Tileset gTileset_Cave_Ice =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Cave_Ice,
    .palettes = gTilesetPalettes_Cave_Ice,
    TILESET_METATILES(gMetatiles_Cave_Ice, gMetatileAttributes_Cave_Ice),
    .callback = NULL,
};

const struct Tileset gTileset_Cave_DragonsDen =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_Cave_DragonsDen,
    .palettes = gTilesetPalettes_Cave_DragonsDen,
    TILESET_METATILES(gMetatiles_Cave_DragonsDen, gMetatileAttributes_Cave_DragonsDen),
    .callback = NULL,
};

const struct Tileset gTileset_DragonsDen_Shrine =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_DragonsDen_Shrine,
    .palettes = gTilesetPalettes_DragonsDen_Shrine,
    TILESET_METATILES(gMetatiles_DragonsDen_Shrine, gMetatileAttributes_DragonsDen_Shrine),
    .callback = NULL,
};

const struct Tileset gTileset_BlackthornGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BlackthornGym,
    .palettes = gTilesetPalettes_BlackthornGym,
    TILESET_METATILES(gMetatiles_BlackthornGym, gMetatileAttributes_BlackthornGym),
    .callback = NULL,
};

const struct Tileset gTileset_ssaqua =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_ssaqua,
    .palettes = gTilesetPalettes_ssaqua,
    TILESET_METATILES(gMetatiles_ssaqua, gMetatileAttributes_ssaqua),
    .callback = NULL,
};

const struct Tileset gTileset_BattleTowerInner =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_BattleTowerInner,
    .palettes = gTilesetPalettes_BattleTowerInner,
    TILESET_METATILES(gMetatiles_BattleTowerInner, gMetatileAttributes_BattleTowerInner),
    .callback = NULL,
};

const struct Tileset gTileset_SafariZoneJohto =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SafariZoneJohto,
    .palettes = gTilesetPalettes_SafariZoneJohto,
    TILESET_METATILES(gMetatiles_SafariZoneJohto, gMetatileAttributes_SafariZoneJohto),
    .callback = NULL,
};

const struct Tileset gTileset_SafariZone_Entrance =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_SafariZone_Entrance,
    .palettes = gTilesetPalettes_SafariZone_Entrance,
    TILESET_METATILES(gMetatiles_SafariZone_Entrance, gMetatileAttributes_SafariZone_Entrance),
    .callback = NULL,
};

const struct Tileset gTileset_MtSilverSnow =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_MtSilverSnow,
    .palettes = gTilesetPalettes_MtSilverSnow,
    TILESET_METATILES(gMetatiles_MtSilverSnow, gMetatileAttributes_MtSilverSnow),
    .callback = NULL,
};

const struct Tileset gTileset_PokemonCenter_White =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_PokemonCenter_White,
    .palettes = gTilesetPalettes_PokemonCenter_White,
    TILESET_METATILES(gMetatiles_PokemonCenter_White, gMetatileAttributes_PokemonCenter_White),
    .callback = NULL,
};

const struct Tileset gTileset_JohtoDayCare =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_JohtoDayCare,
    .palettes = gTilesetPalettes_JohtoDayCare,
    TILESET_METATILES(gMetatiles_JohtoDayCare, gMetatileAttributes_JohtoDayCare),
    .callback = InitTilesetAnim_JohtoDayCare,
};

const struct Tileset gTileset_MahoganyTownGym =
{
    .isCompressed = TRUE,
    .isSecondary = TRUE,
    .tiles = gTilesetTiles_MahoganyTownGym,
    .palettes = gTilesetPalettes_MahoganyTownGym,
    TILESET_METATILES(gMetatiles_MahoganyTownGym, gMetatileAttributes_MahoganyTownGym),
    .callback = NULL,
};
