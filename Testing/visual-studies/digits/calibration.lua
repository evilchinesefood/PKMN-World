-- Diagnostic window uses the native production GBA text renderer; not a normal menu.
package.path=assert(os.getenv('PW_STUDY_LIB'))..'/?.lua;'..package.path
local X=require('study_symbols');local S=require('symbols');local F=require('lib').new(S,'DigitsCalibration')
F.run(function()
 F.check('boot',F.boot(100));if not F.ow() then F.finish();return end
 F.w16(S.gSpecialVar_0x8004,4);F.w32(S.gMain+4,X.hook);F.idle(120)
 F.shot('SHORT_SHORT_NARROW_SHORT_NARROWER_NORMALcontrol')
 F.finish()
end)
