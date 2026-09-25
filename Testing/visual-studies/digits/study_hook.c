// TEST-ONLY callback; linked into verified-unused ROM padding for the font study.
// No changes to World code, saved data layout, menus or font metrics.
#include "global.h"
#include "main.h"
#include "pokemon.h"
#include "pokemon_summary_screen.h"
#include "pokemon_storage_system.h"
#include "swsh_storage_system.h"
#include "item.h"
#include "item_menu.h"
#include "event_data.h"
#include "overworld.h"
#include "text.h"
#include "menu.h"
#include "menu_helpers.h"
#include "gpu_regs.h"
#include "palette.h"
#include "malloc.h"
#include "scanline_effect.h"
#include "window.h"
#include "bg.h"
#include "constants/items.h"
#include "constants/rgb.h"
#include "constants/moves.h"
#include "constants/species.h"

static const u8 sLevels[] = {1,9,10,99,100,100};
static const u16 sMoves[] = {MOVE_TACKLE,MOVE_GROWL,MOVE_HELPING_HAND,MOVE_TAIL_WHIP};
static const u8 sPP[] = {1,40,10,5};
static const u8 sName[] = {0xD1,0xD1,0xD1,0xD1,0xAA,0xAA,0xAA,0xAA,0xAA,0xAA,0xAA,0xAA,0xFF}; // WWWW99999999; forces compact fit in PC nickname
static const u8 sDigits[] = {0xA1,0xA2,0xA3,0xA4,0xA5,0xA6,0xA7,0xA8,0xA9,0xAA,0,0xA2,0xBA,0xAA,0xAA,0xAA,0xAD,0xF0,0,0xA4,0xA2,0,0xA3,0xA6,0xA3,0xBA,0xA6,0xA2,0xA1,0xFF};
static const u8 sControls[] = {0xD4,0xEC,0x1B,0,0xB5,0xB6,0xB9,0xAE,0xBA,0xF0,0xFF}; // Zx é, gender, multiplication, punctuation
static const struct WindowTemplate sTestWindows[] = {{.bg=0,.tilemapLeft=1,.tilemapTop=2,.width=28,.height=9,.paletteNum=15,.baseBlock=1},DUMMY_WIN_TEMPLATE};
static const struct BgTemplate sTestBg[] = {{.bg=0,.charBaseIndex=0,.mapBaseIndex=31,.screenSize=0,.paletteMode=0,.priority=0}};
static const u16 sTestPal[16] = {RGB(31,31,31),RGB(31,31,31),RGB(3,3,3),RGB(26,26,25)};
static void StudyIdle(void) {}
static void StudyVBlank(void) { TransferPlttBuffer(); }
static const u8 sColors[] = {1,2,3};

void DigitsStudyHook(void)
{
    u32 i,j;
    u16 command=gSpecialVar_0x8004;
    if (command==0)
    {
        for (i=0;i<6;i++)
        {
            struct Pokemon *mon=&gParties[B_TRAINER_PLAYER][i];
            u8 ev=252,iv=31;
            CreateMonWithIVs(mon,i==5?SPECIES_MEW:SPECIES_EEVEE,sLevels[i],0x11110000+i,OTID_STRUCT_PLAYER_ID,31);
            for(j=0;j<4;j++) { SetMonData(mon,MON_DATA_MOVE1+j,&sMoves[j]); SetMonData(mon,MON_DATA_PP1+j,&sPP[j]); }
            SetMonData(mon,MON_DATA_HP_EV,&ev); SetMonData(mon,MON_DATA_ATK_EV,&ev);
            ev=6; SetMonData(mon,MON_DATA_DEF_EV,&ev);
            SetMonData(mon,MON_DATA_HP_IV,&iv);
            if (i==5) { u16 move=MOVE_STOMPING_TANTRUM; SetMonData(mon,MON_DATA_NICKNAME,sName); SetMonData(mon,MON_DATA_MOVE4,&move); }
            CalculateMonStats(mon);
            if (i<5) { u16 hp=(i==0?1:i==1?9:i==2?10:i==3?99:100); if(hp>mon->maxHP)hp=mon->maxHP; SetMonData(mon,MON_DATA_HP,&hp); }
            SetBoxMonAt(0,i,&mon->box);
        }
        gPartiesCount[B_TRAINER_PLAYER]=6;
        AddBagItem(ITEM_POTION,1); AddBagItem(ITEM_SUPER_POTION,9); AddBagItem(ITEM_HYPER_POTION,10); AddBagItem(ITEM_MAX_POTION,99); AddBagItem(ITEM_UNREMARKABLE_TEACUP,99);
        AddBagItem(ITEM_TM01,1); AddBagItem(ITEM_TM14,9); AddBagItem(ITEM_TM15,10); AddBagItem(ITEM_TM17,99);
        SetMainCallback2(CB2_Overworld);
    }
    else if(command==1)
        ShowPokemonSummaryScreen(SUMMARY_MODE_NORMAL,gParties[B_TRAINER_PLAYER],gSpecialVar_0x8005,5,CB2_ReturnToField);
    else if(command==2)
        GoToBagMenu(ITEMMENULOCATION_FIELD,gSpecialVar_0x8005,CB2_ReturnToField);
    else if(command==3)
        ShowPokemonPCFromParty_SwSh();
    else if(command==4)
    {
        // A labeled diagnostic capture, not a normal gameplay screen. Uses the
        // production text renderer and original font IDs/width tables in a real window.
        u8 w=0;
        SetVBlankCallback(NULL);
        ScanlineEffect_Stop();
        ResetVramOamAndBgCntRegs();
        ResetBgsAndClearDma3BusyFlags(0);
        InitBgsFromTemplates(0,sTestBg,1);
        SetBgTilemapBuffer(0,AllocZeroed(0x800));
        InitWindows(sTestWindows);
        DeactivateAllTextPrinters();
        ResetPaletteFade();
        LoadPalette(sTestPal,BG_PLTT_ID(15),sizeof(sTestPal));
        LoadPalette(sTestPal,0,2);
        SetGpuReg(REG_OFFSET_BLDCNT,0);
        SetGpuReg(REG_OFFSET_DISPCNT,0);
        ChangeBgX(0,0,BG_COORD_SET); ChangeBgY(0,0,BG_COORD_SET);
        FillWindowPixelBuffer(w,0x11);
        AddTextPrinterParameterized3(w,FONT_SHORT,2,0,sColors,TEXT_SKIP_DRAW,sDigits);
        AddTextPrinterParameterized3(w,FONT_SHORT_NARROW,2,18,sColors,TEXT_SKIP_DRAW,sDigits);
        AddTextPrinterParameterized3(w,FONT_SHORT_NARROWER,2,36,sColors,TEXT_SKIP_DRAW,sDigits);
        AddTextPrinterParameterized3(w,FONT_NORMAL,2,54,sColors,TEXT_SKIP_DRAW,sControls);
        PutWindowTilemap(w); CopyWindowToVram(w,COPYWIN_FULL);
        ShowBg(0);
        SetVBlankCallback(StudyVBlank);
        SetMainCallback2(StudyIdle);
    }
}
