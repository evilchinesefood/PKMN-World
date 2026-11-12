local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])') or ''
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..here..'?.lua;'..package.path
local S,X,U=require('symbols'),require('feature_symbols'),require('ui_symbols')
local F=require('lib').new(S,'SpecialPokemonUI')
local function tap(key,frames) F.press(key,2);F.idle(frames or 30) end
local function task(name)
  for i=0,15 do
    local address=S.gTasks+i*S.Task.stride
    if F.r8(address+S.Task.isActive)~=0 and (F.r32(address)&~1)==U[name] then return true end
  end
  return false
end
local function waitTask(name)
  for _=1,180 do if task(name) then F.idle(10);return true end F.idle(5) end
  error('missing task '..name)
end
local function invoke(command)
  assert(F.ow(),'fixture requires field control')
  F.w16(S.gSpecialVar_0x8004,command)
  F.w32(S.gMain+4,X.hook)
  F.idle(120)
end
local function dex() return F.r32(U.sPokedexView) end
local function form() return dex()+U.formView end
local function collection() return F.r32(U.sSpecialPokemonMenu) end
local function checkCollectionScroll(name)
  local x=F.r16(S.sGpuRegBuffer+0x10)
  local y=F.r16(S.sGpuRegBuffer+0x12)
  F.L(string.format('%s: BG0 scroll %d,%d',name,x,y))
  F.check(name..' text background stays aligned with icons',x==0 and y==0)
end
local function spriteCount()
  local count=0
  for i=0,63 do if (F.r8(S.gSprites+i*S.Sprite.stride+S.Sprite.inUse)&1)~=0 then count=count+1 end end
  return count
end
local function spriteActive(id)
  return id<S.Sprite.count and (F.r8(S.gSprites+id*S.Sprite.stride+S.Sprite.inUse)&1)~=0
end
local function checkFormsIcons(name,expectedCount)
  local handles={}
  local count=0
  local baseIcon=F.r8(form()+U.formBaseIcon)
  F.check(name..' active base icon',spriteActive(baseIcon))
  handles[baseIcon]=true
  for slot=0,11 do
    local id=F.r8(form()+U.formIcons+slot)
    if slot<expectedCount then
      F.check(name..' active icon '..slot,spriteActive(id))
      F.check(name..' unique icon '..slot,not handles[id])
      handles[id]=true
    else
      F.check(name..' unused icon slot '..slot,id==S.Sprite.count)
    end
    if id<S.Sprite.count then count=count+1 end
  end
  F.check(name..' visible icon count',count==expectedCount)
  local arrow=F.r8(form()+U.formArrow)
  F.check(name..' active cursor',spriteActive(arrow))
  F.check(name..' cursor has its own sprite',not handles[arrow])
end
local function openDex(position)
  F.w16(U.sLastSelectedPokemon,position)
  invoke(1)
  waitTask('Task_HandlePokedexInput')
end
local function openForms()
  tap('A',100)
  waitTask('Task_HandleInfoScreenInput')
  for _=1,6 do
    if task('Task_HandleEvolutionScreenInput') then break end
    tap('Right',150)
  end
  waitTask('Task_HandleEvolutionScreenInput')
  tap('Start',100)
  waitTask('Task_HandleFormsScreenInput')
end
local function expectedForms(address)
  local result={}
  local index=1
  while F.r16(address+index*2)~=65535 do
    result[#result+1]=F.r16(address+index*2)
    index=index+1
    assert(index<256,'invalid fixture form table')
  end
  return result
end
local function formsCase(name,tableAddress)
  local expected=expectedForms(tableAddress)
  local baseline=spriteCount()
  openForms()
  F.check(name..' complete form inventory',F.r16(form()+U.formCount)==#expected)
  tap('A')
  for index=0,#expected-1 do
    F.check(name..' selected form '..index,F.r16(form()+U.formSelection)==index)
    F.check(name..' bounded page '..index,F.r16(form()+U.formPage)==(index//12)*12)
    checkFormsIcons(name..' form '..index,math.min(12,#expected-(index//12)*12))
    if index%12==0 then F.shot(name..'_page_'..(index//12+1)) end
    if index<#expected-1 then tap('Right') end
  end
  tap('A',100)
  waitTask('Task_HandleInfoScreenInput')
  F.check(name..' last form opens its information',F.r16(dex()+U.formSpecies)==expected[#expected])
  F.shot(name..'_last_form_info')
  tap('B',100)
  waitTask('Task_HandlePokedexInput')
  F.check(name..' info return releases icons',spriteCount()==baseline)
  for round=1,2 do
    openForms()
    tap('A');tap('B');tap('Start',100)
    waitTask('Task_HandleEvolutionScreenInput')
    tap('Start',100);waitTask('Task_HandleFormsScreenInput')
    tap('B',100);waitTask('Task_HandlePokedexInput')
    F.check(name..' reopen cycle '..round..' releases icons',spriteCount()==baseline)
  end
end
F.run(function()
  assert(F.boot(100))
  invoke(0)
  openDex(24)
  local baseline=spriteCount()
  tap('Start',60)
  waitTask('Task_HandlePokedexStartMenuInput')
  tap('Down');tap('Down');tap('Down')
  F.shot('special_menu_entry')
  F.check('Dex start menu has scrolled BG0 before transition',F.r16(S.sGpuRegBuffer+0x12)==80)
  tap('A',120)
  waitTask('HandleCollectionInput')
  F.check('checklist opens without ownership',collection()~=0 and F.r8(collection()+U.collectionSelection)==0)
  F.check('first checklist page has five active icons',spriteCount()==5)
  checkCollectionScroll('checklist first page')
  F.shot('checklist_page_1')
  tap('A')
  for index=0,6 do
    F.check('detail accessible '..index,F.r8(collection()+U.collectionSelection)==index and F.r8(collection()+U.collectionDetail)~=0)
    F.check('detail has one active icon '..index,spriteCount()==1)
    checkCollectionScroll('checklist detail '..index)
    F.shot('detail_'..index)
    if index<6 then tap('Right') end
  end
  tap('B')
  F.check('second checklist page has two active icons',spriteCount()==2)
  checkCollectionScroll('checklist second page')
  F.shot('checklist_page_2');tap('B',120)
  waitTask('Task_HandlePokedexInput')
  F.check('checklist restores Dex selection',F.r16(dex()+U.dexSelection)==24)
  F.check('checklist releases all sprites',spriteCount()==baseline)
  formsCase('pikachu',U.sPikachuFormSpeciesIdTable)
  for _=1,20 do if F.ow() then break end tap('B',100) end
  assert(F.ow(),'Dex exit did not return to field')
  openDex(200)
  formsCase('unown',U.sUnownFormSpeciesIdTable)
  F.finish()
end)
