package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local H=require('audit_helpers')('JohtoReflectionAudit');local F,S,A=H.F,H.S,H.A;local U=require('bw_symbols')
F.run(function()
 H.boot()
 for i,name in ipairs({'pond','ice','high bridge'}) do
  local tags={};for j=0,15 do tags[j]=F.r16(U.sSpritePaletteTags+j*2) end
  H.cmd(8,i-1)
  F.check(name..' full pool shares parent palette',F.r16(A.gSpecialVar_0x8005)==1)
  F.check(name..' allocation actually exhausted pool',F.r16(A.gSpecialVar_0x8006)>0)
  F.check(name..' retries dedicated palette when space returns',F.r16(A.gSpecialVar_0x8007)==1)
  F.check(name..' avoids crash screen',not F.reportCrash(name))
  for j=0,15 do F.check(name..' palette ownership preserved '..j,F.r16(U.sSpritePaletteTags+j*2)==tags[j]) end
 end
 F.check('reflection tests return control',F.ensureFree());F.finish()
end)
