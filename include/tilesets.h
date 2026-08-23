#ifndef GUARD_tilesets_H
#define GUARD_tilesets_H

extern const u32 gTilesetTiles_General[];
extern const u16 gTilesetPalettes_General[][16];

extern const struct Tileset *const gTilesetPointer_SecretBase;
extern const struct Tileset *const gTilesetPointer_SecretBaseRedCave;

extern const struct Tileset gTileset_Building;
extern const struct Tileset gTileset_BuildingFrlg;
extern const struct Tileset gTileset_BrendansMaysHouse;
extern const struct Tileset gTileset_GenericBuilding1;
extern const struct Tileset gTileset_PlayersHouse;
extern const struct Tileset gTileset_General;
extern const struct Tileset gTileset_Petalburg;
extern const struct Tileset gTileset_Rustboro;
extern const struct Tileset gTileset_Fallarbor;
extern const struct Tileset gTileset_Mauville;
extern const struct Tileset gTileset_Slateport;
extern const struct Tileset gTileset_Dewford;
extern const struct Tileset gTileset_Lilycove;
extern const struct Tileset gTileset_Mossdeep;
extern const struct Tileset gTileset_Sootopolis;
extern const struct Tileset gTileset_EverGrande;
extern const struct Tileset gTileset_Pacifidlog;
extern const struct Tileset gTileset_PetalburgGym;
extern const struct Tileset gTileset_PokemonCenter;
extern const struct Tileset gTileset_InsideShip;
extern const struct Tileset gTileset_Fallarbor;
extern const struct Tileset gTileset_Shop;
extern const struct Tileset gTileset_Dewford;
extern const struct Tileset gTileset_BattleFrontier;
extern const struct Tileset gTileset_BattleFrontierOutsideWest;
extern const struct Tileset gTileset_BattleFrontierOutsideEast;
extern const struct Tileset gTileset_BattleArena;
extern const struct Tileset gTileset_BattleDome;
extern const struct Tileset gTileset_BattlePalace;
extern const struct Tileset gTileset_Slateport;
extern const struct Tileset gTileset_Mauville;
extern const struct Tileset gTileset_BattleFrontierOutsideWest;
extern const struct Tileset gTileset_BattleTent;
extern const struct Tileset gTileset_TrainerHill;
extern const struct Tileset gTileset_General_Frlg;
extern const struct Tileset gTileset_PalletTown;
extern const struct Tileset gTileset_ViridianCity;
extern const struct Tileset gTileset_PewterCity;
extern const struct Tileset gTileset_SaffronCity;
extern const struct Tileset gTileset_CeruleanCity;
extern const struct Tileset gTileset_LavenderTown;
extern const struct Tileset gTileset_VermilionCity;
extern const struct Tileset gTileset_CeladonCity;
extern const struct Tileset gTileset_FuchsiaCity;
extern const struct Tileset gTileset_CinnabarIsland;
extern const struct Tileset gTileset_SeviiIslands123;
extern const struct Tileset gTileset_SeviiIslands45;
extern const struct Tileset gTileset_SeviiIslands67;
extern const struct Tileset gTileset_DepartmentStore;
extern const struct Tileset gTileset_PokemonCenterFrlg;
extern const struct Tileset gTileset_SilphCo;
extern const struct Tileset gTileset_SSAnne;
// S.S. Aqua is the Johto port of this interior and kept its door metatile, so it needs naming
// here for the same pointer-match reason as the Johto_General recolours below.
extern const struct Tileset gTileset_ssaqua;
extern const struct Tileset gTileset_SeaCottage;
extern const struct Tileset gTileset_TrainerTower;
extern const struct Tileset gTileset_Johto_General;
// Regional recolours of Johto_General. They keep its door metatiles, so field_door.c has to
// name them explicitly -- door lookup matches on the tileset pointer, not on the metatile alone.
extern const struct Tileset gTileset_Johto_South;
extern const struct Tileset gTileset_Johto_NorthEast;
extern const struct Tileset gTileset_Johto_NorthWest;
// Johto's Pokemon Centers borrow the FRLG counter art, so field_effect.c picks the heal
// monitor sprite off these rather than off the region.
extern const struct Tileset gTileset_Kanto_PokemonCenter;
extern const struct Tileset gTileset_PokemonCenter_White;
extern const struct Tileset gTileset_NewBarkTown;
extern const struct Tileset gTileset_CherrygroveCity;
extern const struct Tileset gTileset_VioletCity;
// Dragon's Den carries Violet City's dojo door metatile under a different id (0x2FF vs 0x32B),
// so it needs naming here -- door lookup matches on the tileset pointer, not the metatile alone.
extern const struct Tileset gTileset_Cave_DragonsDen;
extern const struct Tileset gTileset_Goldenrod;
extern const struct Tileset gTileset_CianwoodCity;
extern const struct Tileset gTileset_OlivineCity;
extern const struct Tileset gTileset_Ecruteak_City;
// Bellchime Trail carries Ecruteak City's door metatile unchanged, so it needs naming here for
// the same pointer-match reason as the Johto_General recolours above.
extern const struct Tileset gTileset_BellchimeTrail;
extern const struct Tileset gTileset_Blackthorn;
extern const struct Tileset gTileset_MahoganyTown;
extern const struct Tileset gTileset_SafariZoneJohto;
extern const struct Tileset gTileset_GoldenrodDepartmentStore;
extern const struct Tileset gTileset_ssaqua;
extern const struct Tileset gTileset_Johto_South;
extern const struct Tileset gTileset_Johto_NorthEast;
extern const struct Tileset gTileset_Johto_NorthWest;
extern const struct Tileset gTileset_Cave_DragonsDen;
extern const struct Tileset gTileset_BellchimeTrail;
extern const struct Tileset gTileset_MahoganyTown;
extern const struct Tileset gTileset_BattleTowerInner;

#endif //GUARD_tilesets_H
extern const struct Tileset gTileset_JohtoDayCare;
extern const struct Tileset gTileset_MahoganyTownGym;
