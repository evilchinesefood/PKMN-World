local M = {}
function M.new(name)
  local here = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or ""
  package.path = assert(os.getenv("PW_FEATURE_LIB")) .. "/?.lua;" .. here .. "?.lua;" .. package.path
  local S, X = require("symbols"), require("feature_symbols")
  local F = require("lib").new(S, name)
  local after = os.getenv("PW_WINDOWS_AFTER") == "1"
  local function invoke(command, arg, frames)
    assert(F.ow(), "fixture entry requires the idle overworld")
    F.w16(S.gSpecialVar_0x8004, command)
    F.w16(X.gSpecialVar_0x8005, arg or 0)
    F.w32(S.gMain + 4, X.hook)
    F.idle(frames or 60)
  end
  local function clock(h, m, s)
    -- RTC minus save offset is local time. Keep seconds deterministic, too.
    local off = F.sb2() + S.SaveBlock2.localTimeOffset
    local function seconds(p)
      return F.rs8(p+S.Time.hours)*3600 + F.rs8(p+S.Time.minutes)*60 + F.rs8(p+S.Time.seconds)
    end
    local delta = (seconds(S.gLocalTime) - (h*3600 + (m or 0)*60 + (s or 0))) % 86400
    local value = (seconds(off) + delta) % 86400
    F.w8(off+S.Time.hours, value//3600)
    F.w8(off+S.Time.minutes, (value//60)%60)
    F.w8(off+S.Time.seconds, value%60)
    F.w8(S.sHoursOverride, 0)
    F.w16(S.gTimeUpdateCounter, 0)
    F.idle(120)
  end
  local day = {{19,25,30}, {12,19,29}, {7,15,27}}
  local night = {{31,29,20}, {31,25,13}, {27,19,8}}
  local function palette(tag)
    local weight = F.r16(S.gTimeBlend+10)
    local ok, immune, hardware = true, true, true
    for i = 1,3 do
      local rgb = {}
      for c = 1,3 do
        rgb[c] = after and (night[i][c] + ((day[i][c]-night[i][c])*weight//256)) or day[i][c]
      end
      local want = rgb[1] | (rgb[2]<<5) | (rgb[3]<<10)
      -- High-bit glass uses the engine's existing light-color blend, rather
      -- than the global outdoor tint. It is not a literal RGB passthrough.
      local light = {31,28,15}
      local function lit(blend)
        local word = F.r32(blend)
        local coeff = (word&(1<<24))~=0 and 16 or ((word>>25)&31)*2
        local result = {}
        for c=1,3 do result[c]=rgb[c]+(light[c]-rgb[c])*coeff//32 end
        return result
      end
      local a,b = lit(S.gTimeBlend),lit(S.gTimeBlend+4)
      local w = F.r16(S.gTimeBlend+8)
      local final = {}
      for c=1,3 do final[c]=b[c]+(a[c]-b[c])*w//256 end
      local wantFaded = final[1] | (final[2]<<5) | (final[3]<<10)
      local index = 8*16 + 7+i
      local unfaded = F.r16(S.gPlttBufferUnfaded+index*2)
      local faded = F.r16(S.gPlttBufferFaded+index*2)
      ok = ok and (unfaded&0x7FFF)==want and (faded&0x7FFF)==wantFaded
      immune = immune and (unfaded&0x8000)~=0
      hardware = hardware and (F.r16(0x05000000+index*2)&0x7FFF)==wantFaded
    end
    F.check(tag..": glass follows alternate weight "..weight, ok)
    F.check(tag..": glass keeps protected-light flag", immune)
    F.check(tag..": hardware palette matches", hardware)
    return weight
  end
  local function dump(tag)
    local out = assert(io.open(F.out..tag..".pal.bin", "wb"))
    for i = 0,255 do
      local v = F.r16(S.gPlttBufferFaded+i*2)
      out:write(string.char(v&255, v>>8))
    end
    out:close()
    F.shot(tag)
  end
  local scenes = {
    {"new_bark",75,0,12,10}, {"cherrygrove_west",75,1,34,16},
    {"cherrygrove_middle",75,1,42,17}, {"cherrygrove_east",75,1,50,20},
    {"route30_north",75,3,35,7}, {"route30_south",75,3,26,42},
    {"route29",75,2,35,16}, {"route27",98,4,80,20},
    {"route31",75,4,30,11}, {"route46",93,2,13,23},
  }
  local function go(i)
    local scene = scenes[i]
    invoke(1,i-1,300)
    local x,y = F.pos()
    assert(F.ow() and F.grp()==scene[2] and F.mapn()==scene[3]
      and x==scene[4] and y==scene[5], string.format("wrong capture location: %s got %d/%d (%d,%d)",scene[1],F.grp(),F.mapn(),x,y))
    return scene[1]
  end
  return {F=F,S=S,X=X,invoke=invoke,clock=clock,palette=palette,dump=dump,scenes=scenes,go=go}
end
return M
