// Test-only paired emulator frontend. Uses mGBA's actual GBA SIO coordinator.
#include <mgba/core/core.h>
#include <mgba/core/lockstep.h>
#include <mgba/core/log.h>
#include <mgba/internal/gba/sio/lockstep.h>
#include <mgba-util/vfs.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include "pw-symbols.h"
struct Player { struct mLockstepUser user; struct mCore *core; struct GBASIOLockstepDriver driver; int id; bool asleep; uint32_t video[240*160]; };
static struct Player p[2];
static const char *out;
static void quiet(struct mLogger *l,int c,enum mLogLevel level,const char *f,va_list a) {(void)l;(void)c;(void)level;(void)f;(void)a;}
static struct mLogger logger={.log=quiet};
static void sleepPlayer(struct mLockstepUser *u) { ((struct Player *)u)->asleep=true; }
static void wakePlayer(struct mLockstepUser *u) { ((struct Player *)u)->asleep=false; }
static int playerId(struct mLockstepUser *u) { return ((struct Player *)u)->id; }
static uint32_t r32(int i,uint32_t a) { return p[i].core->busRead32(p[i].core,a); }
static void w32(int i,uint32_t a,uint32_t v) { p[i].core->busWrite32(p[i].core,a,v); }
static bool callback(int i,uint32_t fn) { return (r32(i,PW_gMain+4)&~1u)==fn; }
static bool controller(int i,uint32_t fn) {
 if (!callback(i,PW_BattleMainCB2)) return false;
 for(int b=0;b<4;b++) if((r32(i,PW_gBattlerControllerFuncs+4*b)&~1u)==fn) return true;
 return false;
}
static void shot(int i,const char *name) {
 char path[1024];snprintf(path,sizeof(path),"%s/link_%d_%s.png",out,i,name);
 struct VFile *f=VFileOpen(path,O_WRONLY|O_CREAT|O_TRUNC);
 if(!f || !mCoreTakeScreenshotVF(p[i].core,f)) exit(3);
 f->close(f);
}
static void frames(int n,uint32_t k0,uint32_t k1) {
 uint32_t start[2]={p[0].core->frameCounter(p[0].core),p[1].core->frameCounter(p[1].core)};
 p[0].core->setKeys(p[0].core,k0);p[1].core->setKeys(p[1].core,k1);
 for(unsigned long ticks=0;;ticks++) {
  if(p[0].core->frameCounter(p[0].core)>=start[0]+n && p[1].core->frameCounter(p[1].core)>=start[1]+n) return;
  bool awake=false;
  for(int i=0;i<2;i++) if(!p[i].asleep) { awake=true;p[i].core->runLoop(p[i].core); }
  if(!awake || ticks>100000000) {fprintf(stderr,"lockstep stalled %d %d\n",p[0].asleep,p[1].asleep);exit(4);}
 }
}
static void press(uint32_t key) {frames(4,key,key);frames(40,0,0);}
static void status(const char *label) {
 printf("%s: cb=%08x/%08x controllers=%08x/%08x frames=%u/%u\n",label,r32(0,PW_gMain+4),r32(1,PW_gMain+4),r32(0,PW_gBattlerControllerFuncs),r32(1,PW_gBattlerControllerFuncs),p[0].core->frameCounter(p[0].core),p[1].core->frameCounter(p[1].core));fflush(stdout);
}
static bool waitMenu(uint32_t fn) {
 for(int j=0;j<500;j++) {
  if(j%1==0) { status("waiting"); printf("link=%x/%x remote=%d/%d\n",r32(0,PW_gLinkStatus),r32(1,PW_gLinkStatus),p[0].core->busRead8(p[0].core,PW_gReceivedRemoteLinkPlayers),p[1].core->busRead8(p[1].core,PW_gReceivedRemoteLinkPlayers)); }
  printf("error=%x/%x\n",r32(0,PW_sLinkErrorBuffer),r32(1,PW_sLinkErrorBuffer));
  if (r32(0,PW_sLinkErrorBuffer) || r32(1,PW_sLinkErrorBuffer)) return false;
  if(controller(0,fn)&&controller(1,fn)) {frames(30,0,0);return true;}
  frames(4,controller(0,fn)?0:1,controller(1,fn)?0:1);frames(26,0,0);
 }
 return false;
}
int main(int argc,char **argv) {
 if(argc!=4) {fprintf(stderr,"usage: pw-link fixture.gba synthetic.sav output-dir\n");return 2;}
 mLogSetDefaultLogger(&logger);out=argv[3];setvbuf(stdout,NULL,_IONBF,0);puts("starting");
 struct GBASIOLockstepCoordinator coordinator;
 puts("coordinator init");GBASIOLockstepCoordinatorInit(&coordinator);puts("coordinator initialized");
 for(int i=0;i<2;i++) {
  printf("finding core %d\n",i);p[i].id=i;p[i].core=mCoreFind(argv[1]);struct mCore *c=p[i].core;
  if(!c || !c->init(c)) return 2;
  printf("core %d initialized\n",i);mCoreInitConfig(c,"pw-link");mCoreConfigSetDefaultIntValue(&c->config,"logLevel",0);mCoreLoadConfig(c);
  c->setVideoBuffer(c,p[i].video,240);
  if(!mCoreLoadFile(c,argv[1]) || !mCoreLoadSaveFile(c,argv[2],true)) return 2;
  printf("core %d loaded\n",i);c->rtc.override=RTC_FAKE_EPOCH;c->rtc.value=1704110400;
  p[i].user.sleep=sleepPlayer;p[i].user.wake=wakePlayer;p[i].user.requestedId=playerId;
  GBASIOLockstepDriverCreate(&p[i].driver,&p[i].user);
  GBASIOLockstepCoordinatorAttach(&coordinator,&p[i].driver);
  c->setPeripheral(c,mPERIPH_GBA_LINK_PORT,&p[i].driver.d);c->reset(c);printf("core %d reset\n",i);
 }
 for(int n=0;n<200 && !(callback(0,PW_CB2_Overworld)&&callback(1,PW_CB2_Overworld));n++) press(1);
 frames(120,0,0);status("boot");
 if(!callback(0,PW_CB2_Overworld)||!callback(1,PW_CB2_Overworld)) return 5;
 for(int i=0;i<2;i++) {
  p[i].core->busWrite16(p[i].core,PW_gSpecialVar_0x8004,10);
  p[i].core->busWrite16(p[i].core,PW_gSpecialVar_0x8005,i);
  w32(i,PW_gMain+4,PW_hook);
 }
 if(!waitMenu(PW_HandleInputChooseAction)) {status("intro timeout");shot(0,"intro_timeout");shot(1,"intro_timeout");return 6;}
 status("commands");shot(0,"commands");shot(1,"commands");
 press(1);
 if(!waitMenu(PW_HandleInputChooseMove)) return 7;
 shot(0,"moves");shot(1,"moves");press(512);shot(0,"details");shot(1,"details");press(512);
 press(1);
 if(!waitMenu(PW_HandleInputChooseAction)) {status("turn timeout");return 8;}
 status("completed synchronized turn");shot(0,"turn");shot(1,"turn");
 // Forfeit through the normal link-battle Run control and confirmation.
 press(16);press(128);press(1);press(1);
 for(int j=0;j<500 && !(callback(0,PW_CB2_Overworld)&&callback(1,PW_CB2_Overworld));j++) press(1);
 status("exit");shot(0,"exit");shot(1,"exit");
 if(!callback(0,PW_CB2_Overworld)||!callback(1,PW_CB2_Overworld)) return 9;
 puts("PASS: two SIO-connected cores completed battle commands, move info, a turn and forfeit.");
 return 0;
}
