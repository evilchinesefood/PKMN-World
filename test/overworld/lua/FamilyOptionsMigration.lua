local here=(debug.getinfo(1,"S").source:sub(2)):match("^(.*[/\\])") or ""
package.path=here.."?.lua;"..package.path
local S=require("symbols")
local F=require("lib").new(S,"FamilyOptionsMigration")
local version=tonumber(os.getenv("PW_FAMILY_VERSION") or "11")
local hard=(os.getenv("PW_FAMILY_HARD") or "1")=="1"
local expectedBox="c75d29ea323305abbce9dadaddd9ffcde3e90202c1bfc5c3ffffff00bad90000f592d041f36e2c41f56e2c41ac6e1941ab6c7243ff610469f56fc8100a91d37ef56e2c413f162c41b52c635df56e2d77"
F.run(function()
  F.L("fixture version="..version.." oldHard="..tostring(hard))
  if not F.boot(2,true) then F.check("supported fixture loads through Continue",false);F.finish();return end
  F.check("migration reaches current format",F.r8(F.sb2()+S.SaveBlock2.saveVersion)==S.SAVE_FORMAT_VERSION)
  local text=version<12 and ((version-7)%3) or 3
  F.check("saved text and adjacent preferences survive",F.r16(F.sb2()+0x14)==(0x1000|text))
  local expected=(version<12 and 0xFC26 or 0xFFE6)|(hard and 0x10 or 0)
  F.check("only new rate bits initialize on old formats",F.r16(F.sb2()+0x16)==expected,string.format("got=%04X expected=%04X",F.r16(F.sb2()+0x16),expected))
  F.check("wallet survives migration",(F.r32(F.sb1()+S.SaveBlock1.money)~F.r32(F.sb2()+S.SaveBlock2.encryptionKey))==3000)
  local same=true
  for i=0,79 do if F.r8(S.gParties+i)~=tonumber(expectedBox:sub(i*2+1,i*2+2),16) then same=false end end
  F.check("original Pokemon survives migration byte for byte",same)
  local x,y=F.pos()
  F.check("Continue preserves saved location",F.grp()==2 and F.mapn()==2 and x==7 and y==4)
  F.shot("v"..version..(hard and "_hard" or "_normal"))
  F.finish()
end)
