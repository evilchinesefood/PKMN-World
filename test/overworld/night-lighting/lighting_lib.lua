local M = {}
function M.new(name)
  local here = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or ""
  package.path = assert(os.getenv("PW_FEATURE_LIB")) .. "/?.lua;" .. here .. "?.lua;" .. package.path
  local S, X = require("symbols"), require("feature_symbols")
  local F = require("lib").new(S, name)
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
  local scenes = require("scenes")
  local function go(i)
    local scene = scenes[i]
    invoke(1,i-1,360)
    for _=1,30 do if F.ow() then break end; F.idle(60) end
    local x,y = F.pos()
    if not F.ow() or x~=scene[2] or y~=scene[3] then F.shot("failed_"..scene[1]);F.L(string.format("map %d/%d ow %s",F.grp(),F.mapn(),tostring(F.ow()))) end
    assert(F.ow() and x==scene[2] and y==scene[3], string.format("wrong capture location: %s (%d,%d)",scene[1],x,y))
    return scene[1]
  end
  local function dump(tag)
    local file = assert(io.open(F.out..tag..".pal.bin", "wb"))
    for i=0,255 do
      local v=F.r16(S.gPlttBufferFaded+i*2)
      file:write(string.char(v&255,v>>8))
    end
    file:close()
    F.shot(tag)
  end
  return {F=F,S=S,X=X,invoke=invoke,clock=clock,dump=dump,scenes=scenes,go=go}
end
return M
