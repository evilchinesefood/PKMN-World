package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local S=require('symbols');local F=require('lib').new(S,'UIBoot')
F.run(function() F.idle(180);F.press('A',2);F.idle(150);F.press('Start',2);F.idle(150);F.shot('title');F.press('Start',2);F.idle(180);F.shot('main_menu');F.check('no crash',not F.reportCrash('boot'));F.finish() end)
