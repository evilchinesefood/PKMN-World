package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook=require('bw_helpers')('BWSave')
F.run(function()
 assert(F.boot(100));hook(0);hook(4,0,300);hook(9,0,1200)
 F.check('synthetic save written',F.r16(X.gSpecialVar_0x8005)==1,'status='..F.r16(X.gSpecialVar_0x8005))
 client.reboot_core();F.idle(5);F.check('synthetic save reloads',F.boot(0))
 F.check('prepared party persisted',F.r8(S.gPartiesCount)==6);F.finish()
end)
